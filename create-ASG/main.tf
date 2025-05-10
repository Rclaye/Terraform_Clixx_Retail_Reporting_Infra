# Data source to get availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Get details about the security group to find its associated VPC
data "aws_security_group" "selected" {
  id = var.security_group_id
}

# Using the VPC ID from the security group
data "aws_vpc" "selected" {
  id = data.aws_security_group.selected.vpc_id
}

# Data source to get subnets within the VPC
data "aws_subnets" "available" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

# Local variables for resource naming and tags
locals {
  name_prefix = "${var.app_name}-${var.environment}"
  subnet_ids  = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.available.ids
  
  common_tags = {
    Application = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# --- Load Balancer ---
resource "aws_lb" "clixx_alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = local.subnet_ids
  
  enable_deletion_protection = false

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

# --- Target Group ---
resource "aws_lb_target_group" "clixx_app" {
  name     = "${local.name_prefix}-tg"
  port     = var.target_group_port
  protocol = var.target_group_protocol
  vpc_id   = data.aws_vpc.selected.id
  
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
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-target-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# --- Load Balancer Listener ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.clixx_alb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_app.arn
  }
}

# --- Launch Template ---
resource "aws_launch_template" "clixx_app" {
  name        = "${local.name_prefix}-launch-template"
  description = "Launch template for ${var.app_name} application in ${var.environment} environment"
  
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  
  iam_instance_profile {
    name = "eng-ClixxRetailEC2RoleProfile"
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.security_group_id]
    delete_on_termination       = true
  }

  # User data for instance bootstrap
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    FILE_SYSTEM_ID = var.file_system_id,
    REGION         = var.aws_region,
    DB_NAME        = var.db_name,
    DB_USER        = var.db_user,
    DB_PASSWORD    = var.db_password,
    DB_HOST        = var.db_host,
    LB_DNS_NAME    = aws_lb.clixx_alb.dns_name,
    MOUNT_POINT    = var.mount_point,
    BACKUP_DIR     = var.backup_dir
  }))

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-instance"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-launch-template"
    }
  )
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "clixx_asg" {
  name                      = "${local.name_prefix}-asg"
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = local.subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 300
  
  launch_template {
    id      = aws_launch_template.clixx_app.id
    version = "$Latest"
  }
  
  target_group_arns = [aws_lb_target_group.clixx_app.arn]
  
  # Ensure new instances are launched before old ones are terminated
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
 
  # Auto-scaling metrics
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  # Propagate tags to instances
  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-instance"
      }
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# --- Auto Scaling Policies ---
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${local.name_prefix}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.clixx_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${local.name_prefix}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.clixx_asg.name
}

# --- CloudWatch Alarms for Scaling ---
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.clixx_asg.name
  }
  
  alarm_description = "Scale up if CPU usage is above 80% for 4 minutes"
  alarm_actions     = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${local.name_prefix}-low-cpu"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.clixx_asg.name
  }
  
  alarm_description = "Scale down if CPU usage is below 20% for 4 minutes"
  alarm_actions     = [aws_autoscaling_policy.scale_down.arn]
}