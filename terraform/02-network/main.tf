# Values (bucket/key/region/lock) come from backend.hcl via `terraform init -backend-config=backend.hcl`,
# same pattern as iam/basics/ and 01-backend/ — the actual bucket is the Day 4 remote-state bucket.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project_name = var.project_name
    }
  }
}

terraform {
  backend "s3" {}
}

module "network" {
  source       = "./modules/vpc"
  vpc_cidr     = var.vpc_cidr
  avz          = var.avz
  avz2         = var.avz2
  aws_region   = var.aws_region
  project_name = var.project_name
}

module "security" {
  source = "./security"

  avz          = var.avz
  avz2         = var.avz2
  aws_region   = var.aws_region
  project_name = var.project_name
  # This is the actual cross-module link: module.network is the instance name declared above
  # (source = "./modules/vpc", but the INSTANCE is called "network"), .vpc_id is the output
  # we just added in modules/vpc/outputs.tf. This is the only place in the whole config where
  # one module's value can reach another module — never directly between two child modules.
  vpc_id = module.network.vpc_id
}
