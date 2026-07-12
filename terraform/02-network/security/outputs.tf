output "ssm_access_sg_id" {
  value = aws_security_group.ssm_access.id
}

output "web_sg_id" {
  value = aws_security_group.web.id
}
