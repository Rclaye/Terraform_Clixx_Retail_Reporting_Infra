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
  default     = "wordpressdb"
}

variable "db_user" {
  description = "Username for database access"
  type        = string
  default     = "wordpressuser"
  sensitive   = true
}

variable "db_password" {
  description = "Password for database access"
  type        = string
  default     = "W3lcome123"
  sensitive   = true
}

variable "db_instance_class" {
  description = "Instance class for the RDS instance"
  type        = string
  default     = "db.t3.micro"
}

variable "db_snapshot_identifier" {
  description = "Snapshot identifier for RDS instance restoration"
  type        = string
  default     = "arn:aws:rds:us-east-1:577701061234:snapshot:wordpressdbclixx-ecs-snapshot"
}

variable "target_account_id" {
  description = "The AWS Account ID to assume the role into"
  type        = string
  default     = "924305315126"
}

variable "target_role_name" {
  description = "Name of the IAM role to assume in the target account"
  type        = string
  default     = "Engineer"
}

# Domain and SSL variables
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "stack-claye.com"
}

variable "certificate_arn" {
  description = "ARN of SSL certificate in ACM"
  type        = string
  default     = "arn:aws:acm:us-east-1:924305315126:certificate/359f0a6c-455b-4b1d-9b95-462ffd90a2b9"
}

variable "create_dns_record" {
  description = "Whether to create a DNS record"
  type        = bool
  default     = true
}

# WordPress Admin variables
variable "wp_admin_user" {
  description = "WordPress admin username"
  type        = string
  default     = "clixxadmin"
  sensitive   = true
}

variable "wp_admin_password" {
  description = "WordPress admin password"
  type        = string
  default     = "Stack#25!"
  sensitive   = true
}

variable "wp_admin_email" {
  description = "WordPress admin email"
  type        = string
  default     = "richard.claye@gmail.com"
  sensitive   = true
}
