# main module for restoring an RDS snapshot
resource "aws_db_instance" "restored" {
  identifier             = var.db_instance_identifier
  instance_class         = var.db_instance_class
  snapshot_identifier    = var.snapshot_identifier
  vpc_security_group_ids = var.vpc_security_group_ids
  db_subnet_group_name   = var.db_subnet_group_name
  publicly_accessible    = var.publicly_accessible
  skip_final_snapshot    = true

  
  lifecycle {
    ignore_changes = [
      snapshot_identifier, 
    ]
  }
}
