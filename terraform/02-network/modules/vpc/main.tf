resource "aws_vpc" "network" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "network" }
}

resource "aws_internet_gateway" "network" {
  vpc_id = aws_vpc.network.id

  tags = { Name = "network" }
}

# cidrsubnet(base, newbits, netnum) carves `base` into 2^newbits equal chunks and returns chunk #netnum.
# vpc_cidr is a /16 (10.0.0.0/16). newbits=8 means "add 8 bits to the prefix" -> /16 + 8 = /24 chunks.
# netnum = count.index, so each loop iteration (0, 1, 2...) grabs a DIFFERENT /24 automatically —
# no more manually typing "10.0.1.0/24", "10.0.2.0/24" and accidentally reusing the same one twice.
#
# element([list], index) picks list[index] but wraps around (index 2 on a 2-item list loops back to
# item 0) instead of erroring out of bounds — safe way to alternate between avz/avz2 per count.index.
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.network.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)  # count.index 0,1 -> 10.0.0.0/24, 10.0.1.0/24
  availability_zone       = element([var.avz, var.avz2], count.index) # index 0 -> avz, index 1 -> avz2
  map_public_ip_on_launch = true

  tags = { Name = "network-public-${element([var.avz, var.avz2], count.index)}" }
}

resource "aws_route_table" "public" {
  count  = 2
  vpc_id = aws_vpc.network.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.network.id
  }

  tags = { Name = "network-public-${element([var.avz, var.avz2], count.index)}" }
}

resource "aws_route_table_association" "public_association" {
  count          = 2
  route_table_id = aws_route_table.public[count.index].id
  subnet_id      = aws_subnet.public[count.index].id
}

# Same pattern as "public" above, but offset netnum by +2 (count.index 0,1 -> netnum 2,3) so the
# private /24s land in a DIFFERENT chunk than the public ones (10.0.2.0/24, 10.0.3.0/24) instead of
# overlapping with them. Every subnet type gets its own offset band — that's the trick to avoid
# cross-resource collisions, not just within-resource ones.
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.network.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 2) # -> 10.0.2.0/24, 10.0.3.0/24
  availability_zone       = element([var.avz, var.avz2], count.index)
  map_public_ip_on_launch = false

  tags = { Name = "network-private-${element([var.avz, var.avz2], count.index)}" }
}

# DECISION (2026-07-03): no NAT Gateway. Private subnets have no default route out and rely on the
# VPC's implicit main route table (local traffic only, no 0.0.0.0/0). Reasons: NAT Gateway is not
# free-tier eligible (~$0.045/hr + per-GB, runs 24/7 regardless of use); nothing behind the private
# subnets needs outbound internet yet (no EC2, no workload); and it matches the roadmap's cost-aware
# ask for THIS day (a written NO-NAT decision, not a deployed NAT). Revisit with VPC endpoints
# (Day 7) if/when something in a private subnet genuinely needs to reach an AWS service.
