# aws-secure-landing-zone

Secure AWS landing zone built from scratch — IAM, Terraform, logging, detection, IR, and Python security automation.

**Scope note:** this is a *single-account* secure baseline today. A full landing zone implies AWS
Organizations, multiple accounts, centralized logging, and SCPs — that multi-account expansion is
planned, not yet built.

Built as part of a 142-day Cloud Security Engineering roadmap.

## What's in here

| Module | Controls |
|---|---|
| `terraform/` | IaC modules per roadmap day |
| `setup/` | Account foundations (MFA, SSO, budgets) |
| `python/` | Security automation scripts (inventory, CloudTrail normalization, reporting) |
| `detections/` | CloudTrail queries, CloudWatch alarms, EventBridge rules |
| `playbooks/` | IR runbooks (IAM key leak, EC2 compromise, public exposure) |
| `iam/` | Policy examples, Access Analyzer findings, ABAC demos |
| `ir/` | Simulation timelines, postmortems |
| `docs/` | Architecture diagrams, ADRs, threat models |

## Stack

AWS · Terraform · Python (boto3) · CloudTrail · GuardDuty · Security Hub · IAM Access Analyzer

## Cost discipline

Every module includes cost tripwires and cleanup steps. Target: under $5/month for the full lab.

## Target roles

IAM Analyst · SOC Analyst L1 (Cloud SOC) · Junior Cloud Security Engineer
