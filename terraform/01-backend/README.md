# terraform/01-backend: Remote State Bucket (S3 + Native Locking)

Creates the S3 bucket that every other config in this repo (`iam/basics/` and whatever comes next)
uses as its Terraform backend. This config is the one deliberate exception to "always use remote
state". See **Why this config stays local** below.

## What this demonstrates

Moving `terraform.tfstate` off a single laptop and into a governed, shared backend:

```
LOCAL (Day 3)                          S3 BACKEND (Day 4)
terraform.tfstate on disk        →     versioned + encrypted + locked, in S3
no locking, no history                 concurrent apply blocked, prior versions recoverable
```

## Files

| File | Purpose |
|---|---|
| `main.tf` | The state bucket + its security controls (ownership, versioning, SSE, BPA, logging) |
| `variables.tf` | `aws_region`, `bucket_name` inputs |
| `outputs.tf` | Bucket name/ARN/ID, for wiring other configs' backend blocks |

## Why this config stays local (no `backend "s3" {}` here)

This is the config that *creates* the backend bucket. A `terraform init` needs to reach its backend
before touching any resources, but the bucket this config's backend would point to doesn't exist
yet on a first run. Pointing this config at its own not-yet-created bucket is a bootstrapping loop
that can't resolve. The fix isn't clever config, it's a rule: **the bucket-creation config keeps
local state, permanently.** Every config downstream of the bucket (created after it exists) gets the
real `backend "s3" {}` treatment.

## Run

```bash
cd terraform/01-backend
terraform init
terraform fmt && terraform validate
terraform plan        # read the diff before applying
terraform apply
```

## Wiring a downstream config to this backend

In the target config's `.tf` file, add an **empty** stub: the block itself has to exist for
`-backend-config` to have anything to fill in:

```hcl
terraform {
  backend "s3" {}
}
```

Then supply the real values via a separate, gitignored `backend.hcl` (flat key/value pairs, **no**
`backend "s3" { ... }` wrapper; that block syntax belongs in the `.tf` file, not the config file):

```hcl
bucket       = "<this bucket's name, from outputs.bucket_name>"
key          = "<config-path>/terraform.tfstate"
region       = "us-east-1"
use_lockfile = true
```

```bash
terraform init -backend-config=backend.hcl -migrate-state
terraform state pull      # confirm the migrated resources are actually there
```

## Locking: what it looks like when it works

`use_lockfile = true` is Terraform's native S3 locking: it does a conditional write to create a
`<key>.tflock` object before an operation, and a normal write can't overwrite an existing lock. Two
terminals running `apply`/`plan`/`migrate-state` against the same state key at the same time will
produce this on the second one:

```
Error: Error acquiring the state lock
Error message: ... api error PreconditionFailed: At least one of the pre-conditions you specified did not hold
Lock Info:
  ID:        <uuid>
  Path:      <bucket>/<key>
  Operation: OperationTypePlan
  Who:       <user>@<host>
  Created:   <timestamp>
```

That `PreconditionFailed` is the S3 conditional-write rejection: the mechanism working as designed,
not a bug. If the operation holding the lock finishes normally, the `.tflock` object is deleted and
the error clears on its own (confirmed by re-running `plan` after the other terminal's operation
completed; no `force-unlock` needed).

## Stuck locks: the safety check before `force-unlock`

A lock only stays stuck if the process that created it never got to clean up (crash, killed terminal,
lost connection), not just because you saw a lock error once.

**Before running `terraform force-unlock <LOCK_ID>`:**

1. `ps aux | grep terraform`: confirm no `plan`/`apply`/`init` is actually still running, locally or
   on any machine/CI runner that could hold this lock.
2. Check whether the lock object still exists at all:
   `aws s3api head-object --bucket <bucket> --key <key>.tflock` (a `404` means it already cleared and
   you don't need to force anything; re-run your command).
3. Only if a process is confirmed dead *and* the lock object is confirmed still present, run
   `terraform force-unlock <LOCK_ID>` with the exact ID from the error.

**The danger:** if you force-unlock while a genuinely live process is still writing, you get two
writers touching state at once. That's exactly the corruption locking exists to prevent, and it's
avoidable by just checking first.

## Cleanup (cost discipline)

Don't `terraform destroy` this one casually. It holds every other config's state. Only tear it down
if you're retiring the whole lab.

## State & secrets

`*.tfstate` for this config stays **local and gitignored** (see "Why this config stays local" above).
`.terraform/` and `.terraform.lock.hcl` follow the same rules as the rest of the repo.

---
_Part of a 142-day Cloud Security Engineering roadmap, Day 4: Terraform Remote Backend._
