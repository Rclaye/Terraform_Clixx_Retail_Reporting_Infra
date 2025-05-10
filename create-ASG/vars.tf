variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "clixx"
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string
  default     = "dev"
}

# VPC and Network Variables
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Auto Scaling Group"
  type        = list(string)
  default     = []
}

# Security and Access Variables
variable "security_group_id" {
  description = "Security group ID for the instances"
  type        = string
}

variable "key_name" {
  description = "SSH key name to use for the instances"
  type        = string
}

# Existing Resources to Reference
variable "launch_template_name" {
  description = "Name of the existing launch template to use"
  type        = string
}

variable "target_group_name" {
  description = "Name of the existing target group to attach to the ASG"
  type        = string
}

variable "load_balancer_name" {
  description = "Name of the existing load balancer"
  type        = string
}

# Auto Scaling Group Variables
variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 2
}