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

output "public_sg_id" {
  description = "The ID of the public security group"
  value       = aws_security_group.public_sg.id
}

output "private_sg_id" {
  description = "The ID of the private security group"
  value       = aws_security_group.private_sg.id
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

