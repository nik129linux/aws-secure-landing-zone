provider "aws" {
  region = var.region
}

data "aws_s3_bucket" "nico-day-2-bucket" {
  bucket = var.bucket_name
}

data "aws_iam_policy_document" "s3_read_only" {
  statement {
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "${data.aws_s3_bucket.nico-day-2-bucket.arn}/*",
      data.aws_s3_bucket.nico-day-2-bucket.arn
    ]
  }
}

data "aws_iam_policy_document" "admin" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "permissions_boundary" {
  name   = "permissions_boundary"
  policy = data.aws_iam_policy_document.s3_read_only.json
}

resource "aws_iam_policy" "admin_policy" {
  name   = "admin_policy"
  policy = data.aws_iam_policy_document.admin.json
}

resource "aws_iam_user" "nico-day-3" {
  name                 = "nico-day-3"
  permissions_boundary = aws_iam_policy.permissions_boundary.arn
}


resource "aws_iam_user_policy_attachment" "admin" {
  user       = aws_iam_user.nico-day-3.name
  policy_arn = aws_iam_policy.admin_policy.arn
}

