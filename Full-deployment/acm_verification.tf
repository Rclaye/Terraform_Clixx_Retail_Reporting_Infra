# This file verifies the SSL certificate exists before applying it to the load balancer

# Use a data source to verify the certificate exists
data "aws_acm_certificate" "clixx_cert" {
  domain      = "*.stack-claye.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

# Use local variable to determine which certificate ARN to use
locals {
  # Use the data source certificate if found, otherwise fall back to the variable
  certificate_arn = data.aws_acm_certificate.clixx_cert.arn != "" ? data.aws_acm_certificate.clixx_cert.arn : var.certificate_arn
}

# Output the ARN that will be used
output "certificate_arn_used" {
  description = "ARN of the certificate that will be used"
  value       = local.certificate_arn
}

output "certificate_domain" {
  description = "Domain name associated with the certificate"
  value       = data.aws_acm_certificate.clixx_cert.domain
}

output "certificate_status" {
  description = "Status of the certificate"
  value       = data.aws_acm_certificate.clixx_cert.status
}
