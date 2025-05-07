output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.clixx_app.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.clixx_app.latest_version
}

output "launch_template_arn" {
  description = "ARN of the launch template"
  value       = aws_launch_template.clixx_app.arn
}

output "launch_template_name" {
  description = "Name of the launch template"
  value       = aws_launch_template.clixx_app.name
}
