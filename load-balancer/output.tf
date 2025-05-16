output "load_balancer_id" {
  description = "ID of the created load balancer"
  value       = aws_lb.app_lb.id
}

output "load_balancer_arn" {
  description = "ARN of the created load balancer"
  value       = aws_lb.app_lb.arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app_lb.dns_name
}

output "target_group_arn" {
  description = "ARN of the referenced target group"
  value       = data.aws_lb_target_group.existing_tg.arn
}
