# Modules don't auto-expose their resources' attributes to whoever calls them — every value the
# parent (root main.tf) or a sibling module needs back has to be declared here explicitly.
output "vpc_id" {
  value = aws_vpc.network.id
}

# count = 2 makes these resources lists — [*] (splat) collects every instance's id.
output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

output "public_route_table_ids" {
  value = aws_route_table.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
