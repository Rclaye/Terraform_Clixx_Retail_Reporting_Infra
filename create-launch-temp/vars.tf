# Outputs for the launch template
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for resources"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "instance_profile_arn" {
  description = "IAM instance profile ARN"
  type        = string
}

variable "launch_template_name" {
  description = "Name for the launch template"
  type        = string
  default     = "clixx-app-launch-template"
}
