variable "region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "cloud-security-roadmap"
    Day       = "11"
    Hardening = "KMS-CMK"
  }
}
