# Modules don't auto-expose their resources' attributes to whoever calls them — every value the
# parent (root main.tf) or a sibling module needs back has to be declared here explicitly.
output "vpc_id" {
  value = module.network.vpc_id
}

output "private_route_table_ids" {
  value = module.network.private_route_table_ids
}

output "public_route_table_ids" {
  value = module.network.public_route_table_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}
output "ssm_access_sg_id" {
  value = module.security.ssm_access_sg_id
}

output "web_sg_id" {
  value = module.security.web_sg_id
}
output "ami_id" {
  value = data.aws_ami.default.id
}
