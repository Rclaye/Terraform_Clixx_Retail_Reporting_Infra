# Terraform variables for creating a VPC
variable "aws_region" {
  description = "AWS region to launch servers"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "VPC-Demo"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {
    Project     = "ClixxRetail"
    Environment = "Dev"
    Terraform   = "true"
  }
}

