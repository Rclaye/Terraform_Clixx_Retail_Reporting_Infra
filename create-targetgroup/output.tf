output "launch_template_id" {
  description = "ID of the created launch template"
  value       = aws_launch_template.clixx_app.id
}

output "launch_template_arn" {
  description = "ARN of the created launch template"
  value       = aws_launch_template.clixx_app.arn
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.clixx_app.latest_version
}

output "target_group_id" {
  description = "ID of the created target group"
  value       = aws_lb_target_group.clixx_app.id
}

output "target_group_arn" {
  description = "ARN of the created target group"
  value       = aws_lb_target_group.clixx_app.arn
}

output "target_group_name" {
  description = "Name of the created target group"
  value       = aws_lb_target_group.clixx_app.name
}