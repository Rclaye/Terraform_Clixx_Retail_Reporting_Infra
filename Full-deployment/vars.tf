# General variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {
    Project     = "Clixx Retail"
    ManagedBy   = "Terraform"
  }
}

# Network variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# Security variables
variable "admin_ips" {
  description = "List of IP addresses allowed to access admin resources"
  type        = list(string)
}

# Database variables
variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "db_user" {
  description = "Username for database access"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password for database access"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Instance class for the RDS instance"
  type        = string
}

variable "db_availability_zone" {
  description = "The availability zone where the RDS instance will be created"
  type        = string
  default     = "us-east-1a"
}

variable "db_snapshot_identifier" {
  description = "Snapshot identifier for RDS instance restoration"
  type        = string
  default     = "arn:aws:rds:us-east-1:577701061234:snapshot:wordpressdbclixx-ecs-snapshot"
}

# EC2 variables
variable "ec2_instance_type" {
  description = "Instance type for EC2 instances"
  type        = string
}

variable "ec2_key_name" {
  description = "Name of SSH key pair for bastion host"
  type        = string
  default     = "stack_devops_dev_kp"
}

variable "ec2_private_key_name" {
  description = "Name of SSH key pair for private EC2 instances"
  type        = string
  default     = "myec2kp_priv"
}

variable "ec2_key_path" {
  description = "Path to the SSH key file for EC2 instances"
  type        = string
  default     = "~/.ssh/stack_devops_dev_kp.pem" # Update with your actual key path
}

variable "ec2_ami" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0e58b56aa4d64231b" # Amazon Linux 2 AMI ID - latest version
}

# Auto Scaling variables
variable "min_size" {
  description = "Minimum size for Auto Scaling Group"
  type        = number
  default     = 1  # Updated default to 1 for cost savings
}

variable "max_size" {
  description = "Maximum size for Auto Scaling Group"
  type        = number
  default     = 2  # Updated default to 2 for cost savings
}

variable "desired_capacity" {
  description = "Desired capacity for Auto Scaling Group"
  type        = number
  default     = 1  # Updated default to 1 for cost savings
}

# Domain and DNS variables
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of SSL certificate in ACM for HTTPS support (will be verified before use)"
  type        = string
  default     = "arn:aws:acm:us-east-1:924305315126:certificate/359f0a6c-455b-4b1d-9b95-462ffd90a2b9"
}

variable "hosted_zone_name" {
  description = "Name of the Route 53 hosted zone"
  type        = string
  default     = "stack-claye.com" # Updated to match the domain name
}

variable "hosted_zone_record_name" {
  description = "Name of the record to create in the hosted zone"
  type        = string
  default     = "clixx" # Updated to match the record name
}

variable "new_record" {
  type        = string
  description = "New record to be created in Route 53"
  default     = "clixx"
}

variable "create_dns_record" {
  description = "Whether to create a DNS record"
  type        = bool
  default     = true  # Updated default to true
}

variable "create_existing_record" {
  description = "Whether to create a record for the root domain"
  type        = bool
  default     = false
}

# WordPress Admin variables
variable "wp_admin_user" {
  description = "WordPress admin username"
  type        = string
  sensitive   = true
}

variable "wp_admin_password" {
  description = "WordPress admin password"
  type        = string
  sensitive   = true
}

variable "wp_admin_email" {
  description = "WordPress admin email"
  type        = string
  sensitive   = true
}

# Bastion SSH key variables
variable "bastion_ssh_identity_file_local_path" {
  description = "Local path to the .pem file for SSHing into the bastion host"
  type        = string
  default     = "/Users/richardclaye/Downloads/CREDS/stack_devops_dev_kp.pem"
}

variable "private_instance_ssh_key_local_path" {
  description = "Local path to the private instance's .pem file (to be copied to bastion)"
  type        = string
  default     = "/Users/richardclaye/Downloads/CREDS/myec2kp_priv.pem"
}

variable "private_instance_ssh_key_destination_filename" {
  description = "Filename for the private instance's key once copied to the bastion"
  type        = string
  default     = "myec2kp_priv.pem"
}

# Debugging options
variable "create_debug_instance" {
  description = "Whether to create a debug instance in the private subnet"
  type        = bool
  default     = true
}

# EFS variable
#variable "efs_id" {
  #description = "ID of the EFS file system"
 # type        = string
#}
