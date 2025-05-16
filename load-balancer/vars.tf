variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "clixx"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = null # Will use default VPC if not specified
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
  default     = []
}

variable "security_group_id" {
  description = "Security group ID for the load balancer"
  type        = string
  default     = ""
}

variable "target_group_name" {
  description = "Name of the existing target group to attach to the load balancer"
  type        = string
  default     = "clixx-app-target-group"
}
