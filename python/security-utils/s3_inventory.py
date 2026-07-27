import csv
import os

import boto3
from botocore.exceptions import ClientError


def collect_bucket_names(s3_client):
    paginator = s3_client.get_paginator("list_buckets")
    for page in paginator.paginate():
        for bucket in page["Buckets"]:
            yield bucket["Name"]


def check_bucket(s3_client, name):
    row = {"bucket": name}

    try:
        pab = s3_client.get_public_access_block(Bucket=name)
        row["public_access_block"] = pab["PublicAccessBlockConfiguration"]
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code == "NoSuchPublicAccessBlockConfiguration":
            row["public_access_block"] = "NOT CONFIGURED"
        elif code == "AccessDenied":
            row["public_access_block"] = "unknown (AccessDenied)"
        else:
            raise

    try:
        enc = s3_client.get_bucket_encryption(Bucket=name)
        rules = enc["ServerSideEncryptionConfiguration"]["Rules"]
        row["encryption"] = rules[0]["ApplyServerSideEncryptionByDefault"][
            "SSEAlgorithm"
        ]
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code == "ServerSideEncryptionConfigurationNotFoundError":
            row["encryption"] = "NOT CONFIGURED"
        elif code == "AccessDenied":
            row["encryption"] = "unknown (AccessDenied)"
        else:
            raise

    return row


def write_reports(results, output_dir="output"):
    os.makedirs(output_dir, exist_ok=True)

    with open(f"{output_dir}/report.csv", "w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["bucket", "public_access_block", "encryption"]
        )
        writer.writeheader()
        writer.writerows(results)

    with open(f"{output_dir}/report.md", "w") as f:
        f.write("| Bucket | Public Access Block | Encryption |\n")
        f.write("|---|---|---|\n")
        for row in results:
            f.write(
                f"| {row['bucket']} | {row['public_access_block']} | {row['encryption']} |\n"
            )


def main():
    session = boto3.Session(profile_name="nic-lab", region_name="us-east-1")
    s3 = session.client("s3")

    results = [check_bucket(s3, name) for name in collect_bucket_names(s3)]
    write_reports(results)
    print(results)


if __name__ == "__main__":
    main()
