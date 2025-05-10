variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# Launch Template Variables
variable "launch_template_name" {
  description = "Name of the launch template"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to use for the instances"
  type        = string
}

variable "instance_type" {
  description = "Instance type to use"
  type        = string
}

variable "key_name" {
  description = "SSH key name to use for the instances"
  type        = string
}

variable "instance_profile_arn" {
  description = "IAM instance profile ARN for the instances"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for the instances"
  type        = string
}

# Target Group Variables
variable "target_group_name" {
  description = "Name of the target group"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the target group will be created"
  type        = string
}

variable "target_group_port" {
  description = "Port on which the targets receive traffic"
  type        = number
  default     = 80
}

variable "target_group_protocol" {
  description = "Protocol to use for routing traffic to the targets"
  type        = string
  default     = "HTTP"
}

variable "health_check_path" {
  description = "Path for health check requests"
  type        = string
  default     = "/"
}

variable "health_check_port" {
  description = "Port to use for health checks"
  type        = string
  default     = "traffic-port"
}

# User data template variables
variable "file_system_id" {
  description = "EFS File System ID for mounting in instances"
  type        = string
  default     = "fs-placeholder"
}

variable "db_name" {
  description = "Database name for the application"
  type        = string
  default     = "clixx_db"
}

variable "db_user" {
  description = "Database username for the application"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password for the application"
  type        = string
  default     = "placeholder-password"
  sensitive   = true
}

variable "db_host" {
  description = "Database host endpoint for the application"
  type        = string
  default     = "placeholder-endpoint.rds.amazonaws.com"
}

variable "lb_dns_name" {
  description = "Load balancer DNS name for the application"
  type        = string
  default     = "placeholder-lb.us-east-1.elb.amazonaws.com"
}

variable "mount_point" {
  description = "EFS mount point on instances"
  type        = string
  default     = "/var/www/html"
}

variable "backup_dir" {
  description = "Directory to use for backups"
  type        = string
  default     = "/tmp/clixx_backup"
}

# Hosted Zone Variables
variable "hosted_zone_name" {
  description = "The hosted zone name"
  type        = string
  default     = "stack-claye.com"
}

variable "hosted_zone_record_name" {
  description = "The record name to use in the hosted zone"
  type        = string
  default     = "clixx.stack-claye.com"
}

variable "hosted_zone_id" {
  description = "The Route53 hosted zone ID"
  type        = string
  default     = "Z10122851S4603DWSA3ZK"
}