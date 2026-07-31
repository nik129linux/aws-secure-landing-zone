provider "aws" {
  region = var.aws_region

}
terraform {
  backend "s3" {}
}


resource "aws_guardduty_detector" "main" {
  enable = true
}
