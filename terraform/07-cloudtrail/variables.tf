variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "bucket_name" {
  type    = string
  default = "nico-day-roadmap-day12-audit-logs"
}

variable "trail_name" {
  type    = string
  default = "secure-landing-zone-trail"
}
