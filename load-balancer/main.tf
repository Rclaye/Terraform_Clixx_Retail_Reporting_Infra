# Get default VPC if vpc_id is not provided
data "aws_vpc" "default" {
  default = true
}

# Get default subnets if subnet_ids are not provided
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id != null ? var.vpc_id : data.aws_vpc.default.id]
  }
}

# Reference existing target group from create-TargetGroup deployment
data "aws_lb_target_group" "existing_tg" {
  name = var.target_group_name
}

# Get security group if not specified
data "aws_security_group" "selected" {
  count = var.security_group_id == "" ? 1 : 0
  
  filter {
    name   = "group-name"
    values = ["stack-web-dmz"]
  }
}

# Create application load balancer
resource "aws_lb" "app_lb" {
  name               = "${var.app_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id != "" ? var.security_group_id : data.aws_security_group.selected[0].id]
  
  # Use provided subnet IDs or default ones
  subnets = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.aws_subnets.private.ids
  
  ip_address_type = "ipv4"
  
  enable_deletion_protection = false

  tags = {
    Name        = "${var.app_name}-${var.environment}-alb"
    Environment = var.environment
  }
}

# Create listener for the load balancer
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.existing_tg.arn
  }
}