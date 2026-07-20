provider "aws" {
  region = var.aws_region

}
data "aws_caller_identity" "current" {}
terraform {
  backend "s3" {}
}

data "terraform_remote_state" "cloudwatch" {
  backend = "s3"
  config = {
    bucket       = "nico-day-roadmap-day4-terraform-state"
    key          = "cloudtrail-logs/terraform.tfstate"
    region       = var.aws_region
    use_lockfile = true
  }
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_ownership_controls" "state_oc" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs_versioning" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs_ss" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs_pab" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "cloudtrail_logs_logging" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  target_bucket = "nico-day-roadmap-day4-terraform-state"
  target_prefix = "cloudtrail-logs/"
}
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_logs.json
}

data "aws_iam_policy_document" "cloudtrail_logs" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"]
    }
  }
}
resource "aws_cloudtrail" "main" {
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  cloud_watch_logs_group_arn    = "${data.terraform_remote_state.cloudwatch.outputs.trail_logs_group_arn}:*"
  cloud_watch_logs_role_arn     = data.terraform_remote_state.cloudwatch.outputs.cloudtrail_to_cw_role_arn

}
