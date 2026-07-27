provider "aws" {
  region = var.aws_region

}
terraform {
  backend "s3" {}
}

data "aws_caller_identity" "current" {}

resource "aws_s3_account_public_access_block" "account_baseline" {
  account_id              = data.aws_caller_identity.current.account_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



