output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "The ID of the private subnet"
  value       = aws_subnet.private.id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.gw.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = aws_nat_gateway.nat_gw.id
}

output "elastic_ip_id" {
  description = "The ID of the Elastic IP for the NAT Gateway"
  value       = aws_eip.nat.id
}

output "elastic_ip_public_ip" {
  description = "The public IP address of the Elastic IP for the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.public_rt.id
}

output "private_route_table_id" {
  description = "The ID of the private route table"
  value       = aws_route_table.private_rt.id
}

output "public_subnet_cidr" {
  description = "The CIDR block of the public subnet"
  value       = aws_subnet.public.cidr_block
}

output "private_subnet_cidr" {
  description = "The CIDR block of the private subnet"
  value       = aws_subnet.private.cidr_block
}

output "public_subnet_az" {
  description = "The availability zone of the public subnet"
  value       = aws_subnet.public.availability_zone
}

output "private_subnet_az" {
  description = "The availability zone of the private subnet"
  value       = aws_subnet.private.availability_zone
}
