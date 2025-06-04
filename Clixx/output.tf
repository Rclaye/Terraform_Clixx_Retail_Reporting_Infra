# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of private application subnet IDs"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "List of private database subnet IDs"
  value       = aws_subnet.private_db[*].id
}

output "private_oracle_subnet_ids" {
  description = "List of private Oracle subnet IDs"
  value       = aws_subnet.private_oracle[*].id
}

output "private_java_app_subnet_ids" {
  description = "List of private Java application subnet IDs"
  value       = aws_subnet.private_java_app[*].id
}

output "private_java_db_subnet_ids" {
  description = "List of private Java database subnet IDs"
  value       = aws_subnet.private_java_db[*].id
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "ec2_security_group_id" {
  description = "The ID of the EC2 security group"
  value       = aws_security_group.ec2_sg.id
}

output "efs_security_group_id" {
  description = "The ID of the EFS security group"
  value       = aws_security_group.efs_sg.id
}

output "rds_security_group_id" {
  description = "The ID of the RDS security group"
  value       = aws_security_group.rds_sg.id
}

# DB Instance Outputs
output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.clixx_db.endpoint
}

output "rds_address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.clixx_db.address
}

output "rds_db_name" {
  description = "The database name of the RDS instance"
  value       = aws_db_instance.clixx_db.db_name
}

output "db_connection_string" {
  description = "Complete RDS connection string"
  value       = "${aws_db_instance.clixx_db.address}:${aws_db_instance.clixx_db.port}/${aws_db_instance.clixx_db.db_name}"
  sensitive   = true
}

# Update RDS outputs to match your main.tf configuration
output "rds_engine_version" {
  description = "The version of the RDS engine"
  value       = aws_db_instance.clixx_db.engine_version
}

output "rds_status" {
  description = "The current status of the RDS instance"
  value       = aws_db_instance.clixx_db.status
}

output "rds_multi_az" {
  description = "Whether RDS is configured for Multi-AZ deployment"
  value       = aws_db_instance.clixx_db.multi_az
}

output "rds_storage_type" {
  description = "The storage type of the RDS instance"
  value       = aws_db_instance.clixx_db.storage_type
}

output "rds_allocated_storage" {
  description = "The allocated storage size of the RDS instance in GiB"
  value       = aws_db_instance.clixx_db.allocated_storage
}

output "rds_subnet_group" {
  description = "The subnet group used by the RDS instance"
  value       = aws_db_instance.clixx_db.db_subnet_group_name
}

output "rds_parameter_group" {
  description = "The parameter group used by the RDS instance"
  value       = aws_db_instance.clixx_db.parameter_group_name
}

output "db_snapshot_copy_id" {
  description = "The ID of the DB snapshot copy used for restoration"
  value       = aws_db_snapshot_copy.clixx_snapshot_copy.id
}

# EFS Outputs
output "efs_id" {
  description = "The ID of the EFS file system"
  value       = aws_efs_file_system.clixx_efs.id
}

output "efs_dns_name" {
  description = "The DNS name of the EFS file system"
  value       = aws_efs_file_system.clixx_efs.dns_name
}

output "efs_mount_target_ids" {
  description = "List of IDs of the EFS mount targets"
  value       = [for mt in aws_efs_mount_target.clixx_mount_target : mt.id]
}

output "efs_access_point_id" {
  description = "ID of the EFS access point"
  value       = aws_efs_access_point.clixx_access_point.id
}

# IAM Outputs
output "instance_profile_name" {
  description = "Name of the instance profile for EC2 instances"
  value       = aws_iam_instance_profile.clixx_instance_profile.name
}

# Load Balancer Outputs
output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.clixx_alb.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.clixx_alb.arn
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.clixx_alb.dns_name
}

output "target_group_arn" {
  description = "The ARN of the Target Group"
  value       = aws_lb_target_group.clixx_tg.arn
}

# DNS Outputs - Simplified to only what's needed
output "route53_zone_id" {
  description = "The ID of the hosted zone"
  value       = data.aws_route53_zone.clixx_zone.zone_id
}

output "route53_record_name" {
  description = "The name of the Route 53 subdomain record"
  value       = var.create_dns_record ? aws_route53_record.clixx_record[0].name : "DNS record not created (create_dns_record is false)"
}

output "route53_record_fqdn" {
  description = "The FQDN of the Route 53 subdomain record"
  value       = var.create_dns_record ? aws_route53_record.clixx_record[0].fqdn : "DNS record not created (create_dns_record is false)"
}

output "site_url" {
  description = "The public URL for the website"
  value       = var.create_dns_record ? "https://${var.new_record}.${var.domain_name}" : "http://${aws_lb.clixx_alb.dns_name}"
}

# Add this output for availability zones
output "availability_zones_used" {
  description = "List of Availability Zones used for the subnets"
  value       = var.availability_zones
}

# Renamed the following output to avoid duplication
output "connect_private_via_bastion" {
  description = "Command template to connect to private instances through the bastion"
  value       = "ssh -i ec2-user@${aws_instance.bastion.public_dns} ec2-user@PRIVATE_INSTANCE_IP"
}

# Add networking specific outputs
output "nat_gateway_ips" {
  description = "Elastic IP addresses of NAT gateways"
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public_rt.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = aws_route_table.private_rt[*].id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# Add high availability specific outputs
output "high_availability_status" {
  description = "High availability configuration status"
  value = {
    multi_az_rds      = aws_db_instance.clixx_db.multi_az
    asg_subnets       = aws_autoscaling_group.clixx_asg.vpc_zone_identifier
    nat_gateways      = length(aws_nat_gateway.nat_gw)
    efs_mount_targets = length(aws_efs_mount_target.clixx_mount_target)
    azs_used          = var.availability_zones
  }
}

output "subnet_allocation" {
  description = "Subnet allocation and host capacity by type"
  value = {
    public_subnets = {
      cidrs = var.public_subnet_cidrs
      hosts_per_subnet = "512 IPs per subnet (450+ required)"
    }
    private_app_subnets = {
      cidrs = var.private_app_subnet_cidrs
      hosts_per_subnet = "256 IPs per subnet (250+ required)"
    }
    private_db_subnets = {
      cidrs = var.private_db_subnet_cidrs
      hosts_per_subnet = "1024 IPs per subnet (680+ required)"
    }
    private_oracle_subnets = {
      cidrs = var.private_oracle_subnet_cidrs
      hosts_per_subnet = "256 IPs per subnet (254 required)"
    }
    private_java_app_subnets = {
      cidrs = var.private_java_app_subnet_cidrs
      hosts_per_subnet = "64 IPs per subnet (50 required)"
    }
    private_java_db_subnets = {
      cidrs = var.private_java_db_subnet_cidrs
      hosts_per_subnet = "64 IPs per subnet (50 required)"
    }
  }
}

# Add an explicit output to check multi-AZ deployment of application
output "application_deployment_azs" {
  description = "AZs where application can be deployed"
  value = {
    availability_zones = var.availability_zones
    app_subnet_azs = [for subnet in aws_subnet.private_app : subnet.availability_zone]
    alb_subnet_azs = [for subnet in aws_subnet.public : subnet.availability_zone]
  }
}
