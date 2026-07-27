# security-utils

Python security automation for the AWS secure landing zone. Two tools, both stdlib-or-boto3 only,
both pytest-covered and ruff-clean.

| Tool | What it does |
|---|---|
| `s3_inventory.py` | Audits every S3 bucket for Public Access Block + default encryption, exports Markdown/CSV |
| `cloudtrail_normalize.py` | Parses raw CloudTrail logs into a flat, SIEM-ready schema, exports JSONL/CSV |

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Requires an AWS profile with read access — never root. This repo uses the `nic-lab` IAM user.

## `s3_inventory.py` — S3 posture scanner

Lists all buckets and reports, per bucket, the Public Access Block configuration and the default
server-side encryption algorithm.

```bash
python s3_inventory.py
```

Writes `output/report.md` and `output/report.csv` (gitignored — contains real bucket names).

Design notes:

- Uses the **paginator** pattern for `list_buckets`. A security tool that silently audits only the
  first page reports a false all-clear; the test suite feeds two synthetic pages to prove it.
- **`AccessDenied` is recorded, not fatal** — in any multi-account org a scanner role will lack access
  somewhere, and a tool that dies on the first 403 is a toy. The row reads `unknown (AccessDenied)`.
- **`NoSuchPublicAccessBlockConfiguration` is a finding, not an error** — it means no bucket-level BPA
  exists. Recorded as `NOT CONFIGURED`.
- Unexpected error codes are **re-raised**. Never `except Exception: pass`; a security tool that
  swallows errors produces confident, wrong reports.

## `cloudtrail_normalize.py` — CloudTrail log normalizer

Reads gzipped CloudTrail log files and maps each event to a flat schema, so detection queries can be
written once instead of once per log shape. A deliberately minimal OCSF-style normalizer.

**Schema:** `time · actor · source_ip · event_name · resource · outcome · error_code`

```bash
# parse and report counts, write nothing
python cloudtrail_normalize.py --dry-run

# normalize and export
python cloudtrail_normalize.py --input "logs/*.json.gz" --output-dir out/

python cloudtrail_normalize.py --help
```

Outputs `normalized.jsonl` and `normalized.csv`.

**JSONL is the primary artifact** — one JSON object per line is what Splunk and Sentinel ingest
natively, it streams at any file size, and one corrupt line costs one event instead of the whole
file. CSV is for humans.

Design notes:

- **`normalize_record()` is a pure function** — raw dict in, flat dict or `None` out, no I/O. That is
  why the tests need no mocks at all.
- **Actor resolution branches on `userIdentity.type`**: `IAMUser` → `arn`; `AssumedRole` →
  `sessionContext.sessionIssuer.arn` (the **role**, not the session — roles are what you triage on);
  `Root` → `root`; `AWSService` → `invokedBy`; anything unrecognized → `unknown:<type>`, never a
  crash.
- **Skip-and-count, never die.** An event missing `eventTime` or `userIdentity` is unusable: it is
  dropped and counted, and the run continues. Unreadable files raise `OSError` /
  `json.JSONDecodeError`, which are caught by name and reported. A pipeline that dies on one bad
  record loses the other 10,000 — pipeline availability is a security property.
- **`outcome` is derived, `error_code` is kept.** CloudTrail only attaches `errorCode` on failure, so
  its presence sets `outcome`. The code itself is retained because `AccessDenied` and `NoSuchEntity`
  are entirely different stories when hunting.
- Every run prints `total / normalized / skipped`. A non-zero skip count is itself a finding.

### Known limits (v1)

- `resource` extraction is a best-effort heuristic over `requestParameters`, matching the first of
  `bucketName`, `roleArn`, `keyId`, `userName`, `roleName`, `functionName`. Full coverage means
  per-API mapping work. Real example: `GetAccountPublicAccessBlock` carries only `Host`, so those rows
  have an empty `resource`.
- `AssumedRole` resolves to the role ARN; session identity is intentionally dropped.
- No time-range filtering, no dedup, no service-noise filter. On a real trail roughly two-thirds of
  events are AWS services reading their own buckets — filtering that belongs upstream of SIEM ingest.

## Tests

```bash
python -m pytest -q
ruff format . && ruff check .
```

Covers happy paths, pagination across multiple pages, `AccessDenied` tolerance, every `userIdentity`
branch, and — required — malformed input: a record missing `userIdentity`, a non-dict record, and an
end-to-end run over a real `.json.gz` containing one good and one broken event, asserting the good row
survives and the run completes.

## Redaction

Fixtures and any committed sample output use the AWS documentation account ID `123456789012`. Real
tool output is written to gitignored paths (`output/`, `_private/`) and never committed.
