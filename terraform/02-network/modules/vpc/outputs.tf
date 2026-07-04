# Modules don't auto-expose their resources' attributes to whoever calls them — every value the
# parent (root main.tf) or a sibling module needs back has to be declared here explicitly.
output "vpc_id" {
  value = aws_vpc.network.id
}
