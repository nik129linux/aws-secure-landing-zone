provider "aws" {
  region = var.aws_region

}
terraform {
  backend "s3" {}
}

resource "aws_s3_bucket" "baseline" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_ownership_controls" "state_oc" {
  bucket = aws_s3_bucket.baseline.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.baseline.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state_ss" {
  bucket = aws_s3_bucket.baseline.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state_pab" {
  bucket = aws_s3_bucket.baseline.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "state_logging" {
  bucket = aws_s3_bucket.baseline.id

  target_bucket = "nico-day-roadmap-day4-terraform-state"
  target_prefix = "s3-baseline-logs/"
}

resource "aws_s3_bucket_policy" "baseline_security" {
  bucket = aws_s3_bucket.baseline.id
  policy = data.aws_iam_policy_document.baseline_security.json
}

data "aws_iam_policy_document" "baseline_security" {
  statement {
    sid    = "AllowSSLRequestsOnly"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.baseline.arn}", "${aws_s3_bucket.baseline.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]

    }
  }
}
