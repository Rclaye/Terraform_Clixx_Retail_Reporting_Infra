output "autoscaling_group_id" {
  description = "ID of the created Auto Scaling Group"
  value       = aws_autoscaling_group.clixx_asg.id
}

output "autoscaling_group_name" {
  description = "Name of the created Auto Scaling Group"
  value       = aws_autoscaling_group.clixx_asg.name
}

output "autoscaling_group_arn" {
  description = "ARN of the created Auto Scaling Group"
  value       = aws_autoscaling_group.clixx_asg.arn
}

output "referenced_launch_template_id" {
  description = "ID of the referenced launch template"
  value       = data.aws_launch_template.existing.id
}

output "referenced_target_group_arn" {
  description = "ARN of the referenced target group"
  value       = data.aws_lb_target_group.existing.arn
}

output "referenced_load_balancer_dns_name" {
  description = "DNS name of the referenced load balancer"
  value       = data.aws_lb.existing.dns_name
}
