# Route 53 DNS configuration module

# Data source to fetch the existing hosted zone
data "aws_route53_zone" "zone" {
  name = var.hosted_zone_name
  private_zone = var.is_private_zone
}

# Create Route 53 A record pointing to a specified target (like ALB)
resource "aws_route53_record" "record" {
  count   = var.create_record ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.record_name
  type    = var.record_type

  dynamic "alias" {
    for_each = var.is_alias ? [1] : []
    content {
      name                   = var.alias_target_dns_name
      zone_id                = var.alias_target_zone_id
      evaluate_target_health = var.evaluate_target_health
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = var.weighted_routing_enabled ? [1] : []
    content {
      weight = var.routing_weight
    }
  }

  # Include TTL and records only for non-alias records
  ttl     = var.is_alias ? null : var.ttl
  records = var.is_alias ? null : var.record_values

  set_identifier = var.set_identifier
}

# Health Check (optional)
resource "aws_route53_health_check" "health_check" {
  count             = var.create_health_check ? 1 : 0
  fqdn              = var.health_check_fqdn != "" ? var.health_check_fqdn : var.record_name
  port              = var.health_check_port
  type              = var.health_check_type
  resource_path     = var.health_check_path
  failure_threshold = var.health_check_failure_threshold
  request_interval  = var.health_check_request_interval

  tags = merge(
    var.common_tags,
    {
      Name = "${var.record_name}-health-check"
    }
  )
}
