terraform {
  backend "s3" {

  }
}

provider "aws" {
  region = var.aws_region
}
data "aws_caller_identity" "current" {}
locals {
  trail_arn = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"
}


resource "aws_cloudwatch_log_group" "trail_logs" {
  name              = "/aws/cloudtrail/nico-hardened-trail"
  retention_in_days = 7

}
resource "aws_iam_role" "cloudtrail_to_cw" {
  name = "CloudTrailToCWLRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        "Condition" : {
          "StringEquals" : {
            "aws:SourceArn" = local.trail_arn
          }
        }
      }
    ]
  })
}
resource "aws_iam_policy" "cloudtrail_cw_policy" {
  name = "CloudTrailToCWLPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "${aws_cloudwatch_log_group.trail_logs.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudtrail_to_cw" {
  role       = aws_iam_role.cloudtrail_to_cw.name
  policy_arn = aws_iam_policy.cloudtrail_cw_policy.arn
}
