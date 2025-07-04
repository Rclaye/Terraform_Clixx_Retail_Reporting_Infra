variable "environment_tag" {
  description = "Environment tag"
  default     = "prod"
}

variable "region"{
  description = "The region Terraform deploys your instance"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.2.0/24", "10.0.4.0/24", "10.0.6.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.3.0/24", "10.0.5.0/24", "10.0.7.0/24"]
}

variable "admin_ips" {
  description = "List of IP addresses allowed to access admin resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "PATH_TO_PUBLIC_KEY" {
  default = "clixx_key.pub"
}

variable "ami_name" {
  default = "clixx-ami-51"
}

# Database variables
variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "db_user" {
  description = "Username for database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Password for database"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_snapshot_identifier" {
  description = "DB snapshot identifier"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS"
  type        = string
  default     = null
}

variable "domain_name" {
  description = "Domain name for Route53 records"
  type        = string
  default     = "stack-claye.com"
}

variable "create_dns_record" {
  description = "Whether to create DNS records"
  type        = bool
  default     = false
}

variable "target_account_id" {
  description = "AWS Account ID where resources will be deployed"
  type        = string
  default     = "123456789012"  # Replace with your actual account ID
}

variable "target_role_name" {
  description = "IAM role name to assume for deployment"
  type        = string
  default     = "TerraformDeploymentRole"
}
