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
