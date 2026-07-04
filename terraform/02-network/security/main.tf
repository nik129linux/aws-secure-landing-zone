
# Web-facing SG: only HTTPS/HTTP inbound, no SSH — matches the day 9 no-SSH pattern (SSM only for admin access).
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web"
  description = "Security group for web-facing resources (80/443 inbound only)"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-web" }
}

resource "aws_security_group" "ssm_access" {
  name        = "${var.project_name}-ssm-access"
  description = "Security group for SSM access"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  tags = { Name = "sg-ssm-manager" }
}
