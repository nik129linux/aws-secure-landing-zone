# iam/basics — IAM Least Privilege in Terraform

Codifies an S3 read-only IAM policy and a **permission boundary** as Infrastructure as Code,
re-creating a manually-built IAM setup in versioned, reproducible Terraform.

## What this demonstrates

A permission boundary that actually *caps* a broad policy — the anti-privilege-escalation control:

```
admin_policy (Action *, Resource *)  ──attach──►  IAM user  ◄──boundary──  permissions_boundary (S3 read-only)

effective permissions = admin ∩ read-only = S3 read-only
```

Even with an `AdministratorAccess`-equivalent policy attached, the user can do nothing but read one
S3 bucket. That intersection is the whole point: a boundary **limits, it never grants**.

## Files

| File | Purpose |
|---|---|
| `main.tf` | Provider, policy documents, IAM policies, user, attachment |
| `variables.tf` | `region`, `bucket_name` inputs |
| `outputs.tf` | User ARN/name, region, referenced bucket |

## Key design choices

- **`aws_iam_policy_document` data source** over inline JSON — renders valid policy JSON from HCL,
  avoiding hand-formatting errors in the documents that govern access.
- **Least-privilege ARN scoping** — `s3:ListBucket` targets the **bucket** ARN; `s3:GetObject`
  targets the **object** ARN (`/*`). Two actions, two resource levels.
- **`data` source for the existing bucket**, not a `resource` — the bucket is referenced, not owned
  by this config, so Terraform reads its ARN instead of trying to re-create it.

## Run

```bash
terraform init
terraform fmt && terraform validate
terraform plan        # read the diff before applying
terraform apply
```

## Verify against reality

```bash
aws iam get-user --user-name <user>
# Confirm PermissionsBoundary.PermissionsBoundaryArn matches the permissions_boundary policy.
```

## Cleanup (cost discipline)

```bash
terraform destroy
```

## State & secrets

`*.tfstate` is gitignored — it holds resource detail in plaintext and is never committed.
Only `.tf` source and the provider lock (`.terraform.lock.hcl`) are tracked.

---
_Part of a 142-day Cloud Security Engineering roadmap — Day 3: Infrastructure as Code for IAM._
