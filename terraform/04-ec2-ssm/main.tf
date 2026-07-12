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

resource "aws_iam_role" "ssm_role" {
  name = "day09-ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "day09-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name

}

resource "aws_instance" "ssm_instance" {
  ami                  = data.terraform_remote_state.network.outputs.ami_id
  instance_type        = "t3.micro"
  subnet_id            = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  tags = {
    Name = "day09-ssm-instance"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.ssm_access_sg_id]

}
