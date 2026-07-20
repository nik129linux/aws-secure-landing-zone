terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "s3_baseline" {
  backend = "s3"
  config = {
    bucket = "nico-day-roadmap-day4-terraform-state"
    key    = "s3-baseline/terraform.tfstate"
    region = var.region
  }
}

# 3. Create the Customer Managed Key (CMK)
resource "aws_kms_key" "main" {
  description             = "KMS key for S3 baseline"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"

  # CRITICAL: The root-full-access statement to prevent lockout
  # and enable IAM policies to work on this key [4-6].
  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-policy-for-s3-baseline",
    Statement = [
      {
        Sid    = "EnableRootFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          ]
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowNicLabOpsActions"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::123456789012:user/nic-lab"
          ]
        },
        # GenerateDataKey + Decrypt: the caller uploading/reading the S3 object needs these
        # directly on the key (Day 11 primer Q3) — the root statement above only re-enables
        # nic-lab's own IAM policy, it doesn't grant these actions by itself.
        # DescribeKey: read-only, needed for plan/apply and CLI verification commands.
        Action   = ["kms:CreateAlias", "kms:ListKeyRotations", "kms:GenerateDataKey", "kms:Decrypt", "kms:DescribeKey"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/s3-baseline"
  target_key_id = aws_kms_key.main.key_id
}

# NOT touching the bucket's default encryption config here on purpose: 05-s3-baseline's own
# state already owns aws_s3_bucket_server_side_encryption_configuration (SSE-S3) on this bucket.
# A bucket has exactly one default config — a second state managing the same setting would fight
# the first one on every plan/apply. SSE-KMS is proven per-object instead, via the two arguments
# below, which override the bucket default for just this object without touching bucket state.
resource "aws_s3_object" "hardened" {
  bucket                 = data.terraform_remote_state.s3_baseline.outputs.bucket_id
  key                    = "day11-verification.txt"
  content                = "SSE-KMS Hardening Check"
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.main.arn
}
