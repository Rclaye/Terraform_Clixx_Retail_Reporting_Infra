# Create a Launch Template for Clixx retail application
resource "aws_launch_template" "clixx_app" {
  name        = var.launch_template_name
  description = "Launch template for Clixx retail application"

  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    arn = var.instance_profile_arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.security_group_id]
    delete_on_termination       = true
  }

  # Use the new fixed bootstrap script from external template file
  user_data = base64encode(templatefile("${path.module}/user_data_fixed.sh.tpl", {
    FILE_SYSTEM_ID = var.file_system_id,
    REGION = var.aws_region,
    DB_NAME = var.db_name,
    DB_USER = var.db_user,
    DB_PASSWORD = var.db_password,
    DB_HOST = var.db_host,
    LB_DNS_NAME = var.lb_dns_name,
    MOUNT_POINT = var.mount_point,
    BACKUP_DIR = var.backup_dir,
    HOSTED_ZONE_NAME = var.hosted_zone_name,
    HOSTED_ZONE_RECORD_NAME = var.hosted_zone_record_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "Clixx-App-Instance"
      Environment = "Production"
      Application = "ClixxRetailApp"
      ManagedBy   = "Terraform"
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = var.launch_template_name
    Environment = "Production"
    Application = "ClixxRetailApp"
    ManagedBy   = "Terraform"
  }
}

# Create a Target Group for Clixx application
resource "aws_lb_target_group" "clixx_app" {
  name     = var.target_group_name
  port     = var.target_group_port
  protocol = var.target_group_protocol
  vpc_id   = var.vpc_id
  
  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = var.health_check_port
    protocol            = var.target_group_protocol
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  target_type = "instance"

  tags = {
    Name        = var.target_group_name
    Environment = "Production"
    Application = "ClixxRetailApp"
    ManagedBy   = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}