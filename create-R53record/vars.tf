# Variables for Route 53 DNS configuration

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "hosted_zone_name" {
  description = "The name of the hosted zone"
  type        = string
}

variable "is_private_zone" {
  description = "Whether the hosted zone is private"
  type        = bool
  default     = false
}

variable "create_record" {
  description = "Whether to create a record in the hosted zone"
  type        = bool
  default     = true
}

variable "record_name" {
  description = "The name of the record to create"
  type        = string
}

variable "record_type" {
  description = "The type of the record to create (A, CNAME, etc.)"
  type        = string
  default     = "A"
}

variable "ttl" {
  description = "TTL for the record (not used for alias records)"
  type        = number
  default     = 300
}

variable "record_values" {
  description = "The values for the record (not used for alias records)"
  type        = list(string)
  default     = []
}

variable "is_alias" {
  description = "Whether the record is an alias record"
  type        = bool
  default     = true
}

variable "alias_target_dns_name" {
  description = "The DNS name of the alias target (e.g., ALB DNS name)"
  type        = string
  default     = ""
}

variable "alias_target_zone_id" {
  description = "The zone ID of the alias target (e.g., ALB zone ID)"
  type        = string
  default     = ""
}

variable "evaluate_target_health" {
  description = "Whether to evaluate the health of the alias target"
  type        = bool
  default     = true
}

variable "weighted_routing_enabled" {
  description = "Whether to use weighted routing policy"
  type        = bool
  default     = false
}

variable "routing_weight" {
  description = "Routing weight for weighted routing policy"
  type        = number
  default     = 100
}

variable "set_identifier" {
  description = "Unique identifier for the record when using weighted routing"
  type        = string
  default     = null
}

variable "create_health_check" {
  description = "Whether to create a health check for the record"
  type        = bool
  default     = false
}

variable "health_check_fqdn" {
  description = "The FQDN to use for the health check (defaults to record_name)"
  type        = string
  default     = ""
}

variable "health_check_port" {
  description = "The port to use for the health check"
  type        = number
  default     = 80
}

variable "health_check_type" {
  description = "The type of health check (HTTP, HTTPS, TCP)"
  type        = string
  default     = "HTTP"
}

variable "health_check_path" {
  description = "The path to use for HTTP/HTTPS health checks"
  type        = string
  default     = "/"
}

variable "health_check_failure_threshold" {
  description = "The number of consecutive failed checks before considering the endpoint unhealthy"
  type        = number
  default     = 3
}

variable "health_check_request_interval" {
  description = "The number of seconds between health checks"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
