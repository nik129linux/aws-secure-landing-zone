# Zero Trust Architecture — Principles, Access Model, and Perimeter Comparison

_Day 8/142 — Network Architecture. Doc day, no `terraform apply`. Deliverable: ZTA checklist +
perimeter-vs-ZTA blast radius comparison._

## 1. ZTA principles mapped to this lab's controls

| ZTA principle | AWS-native control | Where it lives |
|---|---|---|
| Never trust, always verify | Every request re-evaluated by IAM at request time — no session-based trust; explicit deny, SCP, resource policy, permission boundary, and identity policy all stack on each evaluation | Day 5, four-planes diagram |
| No implicit trust by network location | No SSH from anywhere; SSM Session Manager is the only way to reach an instance, and its SG (`sg-ssm-manager`) only allows 443 egress | Day 6 |
| Least privilege by default | SGs deny-by-default inbound, explicit allow only for 80/443 | Day 6-7, `_private/evidence/day07-private-access.md` |
| Assume breach, minimize blast radius | Private subnets have no internet route; S3 reached only via a Gateway endpoint scoped to one bucket | Day 7 |

## 2. Access model — SSO + SSM + endpoints + no-SSH

Design (SSO is not yet built in Terraform — this states the intended model and flags what's real vs. designed):

- A human authenticates via **IAM Identity Center (SSO)** with short-lived temporary credentials — no long-lived IAM user credentials for people, ever. The org is divided into three account types: buckets, development, billing.
- For this lab's scenario, the human accesses the **development** account.
- From there, access to compute goes through **SSM Session Manager** to an EC2 instance whose SG has zero inbound rules — only 80/443 egress. No SSH port, anywhere, ever.
- If that instance needs a protected S3 bucket in another account: the request has to clear that account's **SCP**, then a resource policy, permission boundary, and identity policy — four checks, not one.
- If the bucket is unprotected (this lab's actual state today): access goes straight through the **Gateway endpoint** in the private subnet — no internet gateway on that route table at all, which is also how NO-NAT keeps costs at $0. The endpoint policy: `Principal = "*"`, `Action = "s3:*"`, scoped to that one bucket's ARN — identity control stays at the resource/identity-policy layer, not the network layer.

**What's real today vs. designed:** SSM, no-SSH, and the S3 Gateway endpoint are built and verified (Days 6-7). IAM Identity Center / SSO is designed here, not yet provisioned — no Terraform for it exists in this repo.

## 3. Microsegmentation

A Security Group attached per-resource IS microsegmentation — it acts on a service, not a subnet (that's what NACLs are for, and this lab leaves NACLs at default per the Day 7 decision — SGs carry the control).

## 4. Perimeter model vs. Zero Trust — blast radius comparison

Same "capability, not inventory" lens as Day 5's account-level blast radius
(`docs/architecture/cloud-foundations/day05-blast-radius.png`), one layer down at the network:

- **Perimeter model:** a compromised EC2 instance inside the network has implicit reach to every other resource the network itself doesn't block — no per-resource firewall stops it. One breach becomes a pivot toward PII and every other service behind the same wall. Lateral movement is the default outcome, not a special achievement by the attacker.
- **Zero Trust (this lab's actual setup):** the same compromised instance sits behind an SG that only permits specific traffic — `sg-ssm-manager` restricts egress to port 443 scoped to the VPC CIDR (`10.0.0.0/16`) only, reachable exclusively via SSM Session Manager rather than SSH, so there's no inbound path for brute-force at all and no free lateral path to whatever a different SG protects.

**Known gap (named, not hidden):** `sg-web` doesn't yet hold to the same standard — its inbound is correctly scoped (80/443 only) but its egress is `0.0.0.0/0`, all ports, all protocols. A segment is only as zero-trust as its most permissive direction; right now `sg-web` is half-microsegmented. **Trigger to close it:** before citing this SG set as a clean, uniform ZTA example in an interview — either scope `sg-web`'s egress to what a real workload needs, or keep documenting it as a deliberate, revisit-when-a-workload-lands decision (same convention as the Day 6/7 defers).

---
Evidence: `_private/evidence/day08-zero-trust.md` · Obsidian: `Day 8 — Zero Trust Architecture` MOC.
