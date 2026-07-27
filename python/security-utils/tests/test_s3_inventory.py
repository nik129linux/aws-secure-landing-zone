from unittest.mock import MagicMock

from botocore.exceptions import ClientError

from s3_inventory import check_bucket, collect_bucket_names


def test_happy_path():
    s3 = MagicMock()
    s3.get_public_access_block.return_value = {
        "PublicAccessBlockConfiguration": {"BlockPublicAcls": True}
    }
    s3.get_bucket_encryption.return_value = {
        "ServerSideEncryptionConfiguration": {
            "Rules": [
                {"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}
            ]
        }
    }

    row = check_bucket(s3, "my-bucket")

    assert row["bucket"] == "my-bucket"
    assert row["encryption"] == "AES256"


def test_pagination_two_pages():
    s3 = MagicMock()
    paginator = MagicMock()
    paginator.paginate.return_value = [
        {"Buckets": [{"Name": "bucket-a"}]},
        {"Buckets": [{"Name": "bucket-b"}]},
    ]
    s3.get_paginator.return_value = paginator

    names = list(collect_bucket_names(s3))

    assert names == ["bucket-a", "bucket-b"]


def test_access_denied():
    s3 = MagicMock()
    s3.get_public_access_block.side_effect = ClientError(
        {"Error": {"Code": "AccessDenied"}}, "GetPublicAccessBlock"
    )
    s3.get_bucket_encryption.return_value = {
        "ServerSideEncryptionConfiguration": {
            "Rules": [
                {"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}
            ]
        }
    }

    row = check_bucket(s3, "locked-bucket")

    assert row["public_access_block"] == "unknown (AccessDenied)"
