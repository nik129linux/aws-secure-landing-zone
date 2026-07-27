import csv
from botocore.exceptions import ClientError
import boto3

session = boto3.Session(profile_name="nic-lab", region_name="us-east-1")
s3 = session.client("s3")

paginator = s3.get_paginator("list_buckets")
results = []

for page in paginator.paginate():
    for bucket in page["Buckets"]:
        name = bucket["Name"]
        row = {"bucket": name}

        try:
            pab = s3.get_public_access_block(Bucket=name)
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
            enc = s3.get_bucket_encryption(Bucket=name)
            rules = enc["ServerSideEncryptionConfiguration"]["Rules"]
            row["encryption"] = rules[0]["ApplyServerSideEncryptionByDefault"]["SSEAlgorithm"]
        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code == "ServerSideEncryptionConfigurationNotFoundError":
                row["encryption"] = "NOT CONFIGURED"
            elif code == "AccessDenied":
                row["encryption"] = "unknown (AccessDenied)"
            else:
                raise

        results.append(row)

print(results)

with open("output/report.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["bucket", "public_access_block", "encryption"])
    writer.writeheader()
    writer.writerows(results)

with open("output/report.md", "w") as f:
    f.write("| Bucket | Public Access Block | Encryption |\n")
    f.write("|---|---|---|\n")
    for row in results:
        f.write(f"| {row['bucket']} | {row['public_access_block']} | {row['encryption']} |\n")
