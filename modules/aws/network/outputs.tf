output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = local.public_subnet_ids
}

output "private_subnet_ids" {
  value = local.private_subnet_ids
}

output "public_route_table_id" {
  value = var.create_internet_gateway ? aws_route_table.public[0].id : null
}

output "nat_gateway_ids" {
  value = [for nat in aws_nat_gateway.this : nat.id]
}
