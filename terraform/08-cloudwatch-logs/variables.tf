variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "trail_name" {
  type    = string
  default = "secure-landing-zone-trail"
  # must match 07's trail_name exactly
}
