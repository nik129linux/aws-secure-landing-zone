variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "nico-day-roadmap-day-6"
}

variable "avz" {
  type    = string
  default = "us-east-1a"
}

variable "avz2" {
  type    = string
  default = "us-east-1b"
}

# No default on purpose: this HAS to come from the root module, wired to module.network.vpc_id.
# A default here would let this module silently apply against the wrong/no VPC if the wiring breaks.
variable "vpc_id" {
  type = string
}
