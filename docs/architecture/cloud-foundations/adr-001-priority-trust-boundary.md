# ADR-001 — The Account Is the Priority Trust Boundary

**Status:** Accepted · 2026-07-03
**Context of record:** Day 5 of the 142-day cloud security roadmap (single-account AWS lab, Terraform-managed).

## Context

The lab currently runs in a **single AWS account**: IAM identities, the Terraform remote-state
backend (S3 + native locking), and all workload resources share one trust domain. Inside that
domain, isolation depends entirely on IAM policies — and IAM inside one account is a **soft
boundary**: a single overly permissive policy (`Resource: "*"`) or misconfiguration can pierce it
and expose the state file, which contains resource details and potentially secrets.

If the account's admin credentials leak, the blast radius is **100% of the account** — measured in
capability, not inventory: resource creation for crypto mining, exfiltration of `terraform.tfstate`,
persistence via backdoor IAM users/keys that survive a password reset, deletion of all resources,
and abuse of the account as attack infrastructure. Neither a nearly-empty bucket nor an expired
payment card shrinks this radius: AWS bills **postpaid**, so billing is decoupled from API
authorization. Today the only real limits on an attacker are default service quotas on a new
account and the IAM hygiene from Days 1–3 (no root access keys, MFA, least privilege) — discipline,
not containment.

## Decision

**We treat the AWS account — not IAM policy — as the primary security boundary of this
architecture.**

IAM inside a single account is a soft boundary: one overly permissive policy pierces it, because
everything shares the same trust domain. The account is a hard, **default-deny** boundary: nothing
crosses it unless someone explicitly builds a cross-account trust — a two-sided handshake where the
caller's identity policy allows the action on the target ARN **and** the target's resource/trust
policy explicitly names the caller as trusted. Silence on either side means denied. Compromise is
therefore contained by design instead of by discipline.

### Alternatives considered

- **Rely on fine-grained IAM inside one account** — rejected: every control shares the blast
  radius with the thing it protects; one misconfiguration defeats the whole scheme.
- **Permission boundaries as the primary control** — rejected as *primary*: a real ceiling, but
  only on the identities it's attached to; an unattached identity has no boundary. Kept as a
  supporting control.

## Consequences

1. **The lab must grow into a multi-account landing zone** (AWS Organizations): at minimum a
   management account, a log-archive account, and workload accounts — so that a compromise in a
   workload account cannot reach the state files or erase the audit trail, regardless of IAM
   misconfigurations inside it.
2. **SCPs become the org-level guardrail**: e.g. an SCP on the workload account denying
   `s3:DeleteBucket` on the state bucket's ARN holds even against a compromised admin, because it
   is enforced from outside the blast radius.
3. **Cross-account access will use `sts:AssumeRole`** through explicit trust policies (one central
   identity that "jumps" into member accounts), not duplicated IAM users per account.
4. **Cost of the decision:** until the multi-account structure exists, the single account remains
   the thing to protect — quotas, no root keys, MFA, least privilege — while acknowledging that
   this interim posture is discipline, not containment.
