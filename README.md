# aws-secure-landing-zone

A secure AWS account baseline, built from scratch with Terraform and audited with Python tools I
wrote. Every control was deployed to a real AWS account, verified live against the API, and
documented with the bugs I hit on the way.

**Scope, stated honestly:** this is a **single-account** secure baseline. A full "landing zone" in
the AWS sense implies Organizations, multiple accounts, centralized logging and SCPs — that
expansion is planned, not built. What is here is deployed and verified.

Part of a 142-day Cloud Security Engineering roadmap. Currently at Day 24.

---

## What's actually here

| Path | What it is |
|---|---|
| `terraform/01-backend` | Remote state on S3 with native state locking (`use_lockfile`), no DynamoDB |
| `terraform/02-network` | VPC across 2 AZs, public/private subnets, IGW, explicit route tables, minimal security groups. **Deliberate NO-NAT decision**, documented |
| `terraform/03-endpoints` | S3 Gateway Endpoint + explicit private route tables — private subnets reach S3 without egress |
| `terraform/04-ec2-ssm` | EC2 with **no SSH and no key pair**. SSM Session Manager only, IMDSv2 enforced |
| `terraform/05-s3-baseline` | Block Public Access (all four), `BucketOwnerEnforced`, SSE-S3, versioning, a bucket policy denying non-TLS requests, access logging to a separate bucket |
| `terraform/06-kms` | Customer-managed key + alias with an **explicit** key policy (not the implicit default), lockout risk checked before apply |
| `terraform/07-cloudtrail` | Multi-region trail with log file validation; log bucket policy carries an `aws:SourceArn` condition against confused-deputy |
| `terraform/08-cloudwatch-logs` | CloudWatch Logs sink + service role whose **trust policy** carries the confused-deputy condition |
| `terraform/09-cloudwatch-alarms` | Metric filters for root usage and console login without MFA, wired to SNS with a confirmed email subscription |
| `terraform/10-boto3` | First boto3 script — paginated S3 inventory, the seed of `python/security-utils` |
| `iam/basics` | Least-privilege role + policy, permission boundary, IAM Access Analyzer findings |
| `python/security-utils` | Two security tools, see below |
| `docs/` | ADRs, architecture diagrams, Zero Trust checklist, and an AI-security review |

Directories that do **not** exist yet (`setup/`, `detections/`, `playbooks/`, `ir/`) are not listed
here. They arrive with the roadmap days that build them.

---

## Python security tools

Both stdlib-plus-boto3, tested, and run against real data from this account.

**`s3_inventory.py`** — enumerates every bucket via paginator and reports Block Public Access and
encryption posture. Tolerates `AccessDenied` per bucket instead of dying on the first one.

**`cloudtrail_normalize.py`** — reads gzipped CloudTrail logs and flattens each event to a 7-field
OCSF-style schema (`time · actor · source_ip · event_name · resource · outcome · error_code`),
exporting JSONL and CSV. Has `--dry-run`, skips and counts unusable records, and catches read
errors by name so one bad file doesn't kill the run.

Run against **308 real log files, 1203 events, 0 skipped**.

```bash
cd python/security-utils
python -m venv .venv && ./.venv/bin/pip install -r requirements.txt
./.venv/bin/python s3_inventory.py
./.venv/bin/python cloudtrail_normalize.py --dry-run --input <path>
./.venv/bin/python -m pytest -q     # 10 tests
./.venv/bin/ruff check . && ./.venv/bin/ruff format --check .
```

Note: the tests import `botocore`, so run them from the venv, not system Python.

---

## Findings from my own account

These came out of the tools above, run against this account's real state and audit trail — not
from a tutorial:

1. **Account-level S3 Public Access Block was not configured.** `GetAccountPublicAccessBlock`
   returned `NoSuchPublicAccessBlockConfiguration` repeatedly in the trail. Bucket-level BPA *was*
   on for all four buckets — a different control: bucket-level protects buckets you configured,
   account-level is the backstop covering buckets that do not exist yet. One tool read live API
   state, the other read log history; neither found this alone.
2. **The audit-log bucket had no Object Lock and no lifecycle rule** — the evidence store itself
   was deletable, and logs accumulated with no expiry.
3. **65% of log volume was CloudTrail reading its own bucket** (789 of 1203 events) versus 53
   human events. A real signal-to-noise input for SIEM work, surfaced from my own data.

---

## Deploy

Each stack is independent and holds **its own state key**. That isolation is the point: a mistake
in one stack cannot destroy another.

```bash
cd terraform/02-network
terraform init -backend-config=backend.hcl
terraform fmt && terraform validate
terraform plan          # read it before applying, every time
terraform apply
```

`terraform/01-backend` is the exception — it creates the state bucket, so it bootstraps with local
state before migrating.

Some stacks read another's outputs through `terraform_remote_state`, so order matters:
`01` → `02` → `03`/`04`/`05` → `06` → `07`/`08` → `09`.

## Destroy

```bash
terraform destroy       # from each stack directory, reverse order
```

Destroy `09` → `08` → `07` first: later stacks depend on earlier ones, and CloudTrail's log bucket
has versioning enabled, so object versions must be cleared before the bucket will delete.

---

## Cost tripwires

Verified total: **~$1.80/month.**

| Item | Cost | Note |
|---|---|---|
| KMS customer-managed key | ~$1/month | The only guaranteed recurring charge. Delete the CMK to zero it. |
| NAT Gateway | **$0** | Deliberately not built — S3 Gateway Endpoint instead. This is the single biggest cost trap in an AWS lab (~$32/month). |
| EC2 | $0 while stopped | Stop it after use; free tier otherwise |
| S3, CloudTrail, CloudWatch, SNS | pennies | Management events on one trail are free; log volume is small |

Before walking away from a session: EC2 stopped, no NAT gateways, no unassociated Elastic IPs.

---

## Evidence and honesty

Per-day evidence files (what was built, what was verified live, every bug found and fixed) live in
`_private/` and are **deliberately gitignored** — they contain real account IDs, ARNs, bucket
contents and log excerpts. Publishing them would undo the controls this repo demonstrates. They
are available on request in redacted form.

Two things this repo does not hide:

- **The bugs.** 40+ real ones across the builds, including a `backend.hcl` copy-paste that would
  have destroyed an entire CloudTrail stack had it been applied, caught before `init` ran.
- **What is not verified.** Where a control was deployed but not proven with a live test, the
  evidence says so instead of claiming success from `terraform apply` exiting zero.

`gitleaks` runs before commits; fixtures use the reserved account ID `123456789012`.

---

## AI security

`docs/ai-security/owasp-llm-top10.md` reviews a WhatsApp AI agent I built (n8n, 26 nodes, LLM plus
Google Sheets) against the OWASP LLM Top 10 — with findings traced to specific workflow nodes,
including a prompt-injection vector through an attacker-controlled WhatsApp profile name. Written
before the agent handled any live traffic.

---

## Stack

AWS · Terraform · Python (boto3, pytest, ruff) · CloudTrail · CloudWatch · KMS · IAM Access Analyzer · SSM

## Target roles

IAM Analyst · SOC Analyst L1 (Cloud SOC) · Junior Cloud Security Engineer
