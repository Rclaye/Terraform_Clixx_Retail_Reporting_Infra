variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "snapshot_identifier" {
  description = "The ARN of the RDS snapshot to restore"
  type        = string
}

variable "db_instance_identifier" {
  description = "Identifier for the restored DB instance"
  type        = string
}

variable "db_instance_class" {
  description = "The compute and memory capacity of the DB instance"
  type        = string
  default     = "db.t3.small"
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs to associate with the DB instance"
  type        = list(string)
  default     = []
}

variable "db_subnet_group_name" {
  description = "DB subnet group name to use for the DB instance"
  type        = string
  default     = null
}

variable "publicly_accessible" {
  description = "Specifies if the DB instance is publicly accessible"
  type        = bool
  default     = false
}
