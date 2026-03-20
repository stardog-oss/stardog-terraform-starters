locals {
  azs = data.aws_availability_zones.available.names
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  count  = var.create_internet_gateway ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = local.azs[tonumber(each.key) % length(local.azs)]

  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = local.azs[tonumber(each.key) % length(local.azs)]

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_route_table" "public" {
  count = var.create_internet_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  for_each = var.create_internet_gateway ? aws_subnet.public : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  count      = var.create_nat_gateway && length(aws_subnet.public) > 0 && length(aws_subnet.private) > 0 ? (var.single_nat_gateway ? 1 : length(aws_subnet.public)) : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]

  tags = merge(var.tags, { Name = "${var.name}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count = length(aws_eip.nat)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = values(aws_subnet.public)[var.single_nat_gateway ? 0 : count.index].id
  depends_on    = [aws_eip.nat]

  tags = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })
}

resource "aws_route_table" "private" {
  count = var.create_nat_gateway && length(aws_nat_gateway.this) > 0 ? (var.single_nat_gateway ? 1 : length(aws_subnet.private)) : 0

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = merge(var.tags, { Name = "${var.name}-private-rt-${count.index}" })
}

resource "aws_route_table_association" "private" {
  for_each = var.create_nat_gateway && length(aws_nat_gateway.this) > 0 ? {
    for idx, subnet in aws_subnet.private : idx => subnet
  } : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : tonumber(each.key)].id
}

locals {
  public_subnet_ids  = [for subnet in aws_subnet.public : subnet.id]
  private_subnet_ids = [for subnet in aws_subnet.private : subnet.id]
}
