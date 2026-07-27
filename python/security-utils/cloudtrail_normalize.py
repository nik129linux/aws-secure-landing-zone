import gzip
import json
import glob
import argparse
import csv
import os

def extract_actor(user_identity):
    identity_type = user_identity.get("type", "")

    if identity_type == "IAMUser":
        return user_identity.get("arn", "unknown")

    if identity_type == "AssumedRole":
        # the arn we want is buried two levels down
        session_context = user_identity.get("sessionContext", {})
        issuer = session_context.get("sessionIssuer", {})
        return issuer.get("arn", "unknown")

    if identity_type == "Root":
        return "root"

    if identity_type == "AWSService":
        return user_identity.get("invokedBy", "aws-service")

    # never crash on a type we don't know — label it and move on
    return f"unknown:{identity_type}"


def extract_resource(request_parameters):
    if not isinstance(request_parameters, dict):
        return ""
    for key in (
        "bucketName",
        "roleArn",
        "keyId",
        "userName",
        "roleName",
        "functionName",
    ):
        if key in request_parameters:
            return str(request_parameters[key])
    return ""


# Takes one messy event, hands back the clean 6-field version.
def normalize_record(record):
    # An event with no timestamp or no identity is unusable
    if not isinstance(record, dict):
        return None
    if record.get("eventTime") is None or record.get("userIdentity") is None:
        return None
    return {
        "time": record.get("eventTime"),
        "actor": extract_actor(record.get("userIdentity", {})),
        "source_ip": record.get("sourceIPAddress", ""),
        "event_name": record.get("eventName", ""),
        "outcome": "failure" if record.get("errorCode") else "success",
        "resource": extract_resource(record.get("requestParameters", {})),
        "error_code": record.get("errorCode") or "",
    }


def read_records(path):
    with gzip.open(path, "rt") as f:
        data = json.load(f)
        return data.get("Records", [])


def run(pattern):
    rows = []
    total = 0
    skipped = 0

    for path in sorted(glob.glob(pattern)):
        try:
            records = read_records(path)
        except (OSError, json.JSONDecodeError) as e:
            # A broken file must not kill the run — report it and continue.
            print(f"unreadable file {path}: {e}")
            continue
        for record in records:
            total += 1
            row = normalize_record(record)
            if row is None:
                skipped += 1
            else:
                rows.append(row)
    print(
        f"total: {total} normalized: {len(rows)} skipped: {skipped} from {len(glob.glob(pattern))}"
    )
    return rows


def write_jsonl(rows, path):
    with open(path, "w") as f:
        for row in rows:
            f.write(json.dumps(row) + "\n")


def write_csv(rows, path):
    fields = [
        "time",
        "actor",
        "source_ip",
        "event_name",
        "resource",
        "outcome",
        "error_code",
    ]
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(
        description="Normalize CloudTrail logs into a flat schema."
    )
    parser.add_argument(
        "--input",
        default="../../_private/day19-logs/*.json.gz",
        help="glob pattern for CloudTrail .json.gz files",
    )
    parser.add_argument(
        "--output-dir",
        default="../../_private/day19-output",
        help="where to write normalized.jsonl / normalized.csv",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="parse and report counts, write nothing"
    )
    args = parser.parse_args()

    rows = run(args.input)

    if args.dry_run:
        print("dry-run: no files written")
        return

    os.makedirs(args.output_dir, exist_ok=True)
    write_jsonl(rows, f"{args.output_dir}/normalized.jsonl")
    write_csv(rows, f"{args.output_dir}/normalized.csv")
    print(f"wrote {len(rows)} rows to {args.output_dir}/")


if __name__ == "__main__":
    main()
