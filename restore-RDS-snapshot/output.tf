output "rds_endpoint" {
  description = "The endpoint of the restored RDS instance"
  value       = aws_db_instance.restored.endpoint
}

output "rds_address" {
  description = "The hostname of the restored RDS instance"
  value       = aws_db_instance.restored.address
}

output "rds_db_name" {
  description = "The database name of the restored RDS instance"
  value       = aws_db_instance.restored.db_name
}

output "connection_string" {
  description = "Complete RDS connection string"
  value       = "${aws_db_instance.restored.address}:${aws_db_instance.restored.port}/${aws_db_instance.restored.db_name}"
}
