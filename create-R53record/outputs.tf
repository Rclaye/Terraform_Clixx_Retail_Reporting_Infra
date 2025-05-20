# Outputs for Route 53 DNS resources

output "hosted_zone_id" {
  description = "The ID of the hosted zone"
  value       = data.aws_route53_zone.zone.zone_id
}

output "hosted_zone_name" {
  description = "The name of the hosted zone"
  value       = data.aws_route53_zone.zone.name
}

output "record_name" {
  description = "The name of the Route 53 record"
  value       = var.create_record ? aws_route53_record.record[0].name : "DNS record not created (create_record is false)"
}

output "record_fqdn" {
  description = "The FQDN of the Route 53 record"
  value       = var.create_record ? aws_route53_record.record[0].fqdn : "DNS record not created (create_record is false)"
}

output "health_check_id" {
  description = "ID of the Route 53 health check"
  value       = var.create_health_check ? aws_route53_health_check.health_check[0].id : "Health check not created (create_health_check is false)"
}

output "dns_url" {
  description = "The public URL for the website"
  value       = var.create_record ? "https://${var.record_name}" : null
}
