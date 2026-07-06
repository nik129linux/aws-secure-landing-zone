provider "aws" {
  region = var.aws_region
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket       = "nico-day-roadmap-day4-terraform-state"
    key          = "networking/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

terraform {
  backend "s3" {}
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.terraform_remote_state.network.outputs.private_route_table_ids

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccessToTerraformStateOnly"
        Action    = "s3:*"
        Effect    = "Allow"
        Principal = "*"
        # S3 bucket ARNs are derivable from the name — the bucket resource lives in 01-backend,
        # unreachable from this stack, so the ARN is built as a literal instead.
        Resource = [
          "arn:aws:s3:::nico-day-roadmap-day4-terraform-state",
          "arn:aws:s3:::nico-day-roadmap-day4-terraform-state/*"
        ]
      }
    ]
  })
  tags = {
    Name = "nico-day-roadmap-day7-vpc-endpoint-s3-private"
  }
}
