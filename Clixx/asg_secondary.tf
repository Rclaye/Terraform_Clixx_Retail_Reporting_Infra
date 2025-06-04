# Secondary Auto Scaling Group configured to run in the second availability zone
# This provides high availability for the application layer

# Launch Template for secondary ASG instances 
resource "aws_launch_template" "clixx_app_secondary" {
  name        = "clixx-launch-template-secondary"
  description = "Launch template for Clixx retail application in secondary AZ"
  image_id      = var.ec2_ami
  instance_type = var.ec2_instance_type
  key_name      = var.private_key_name

  # Enable detailed monitoring
  monitoring {
    enabled = true
  }

  # Use the same IAM instance profile
  iam_instance_profile {
    name = aws_iam_instance_profile.clixx_instance_profile.name
  }
  
  # Root volume configuration
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
      encrypted             = false
    }
  }

  # Additional EBS volume - /dev/sdb
  block_device_mappings {
    device_name = "/dev/sdb"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true  # Changed to true for testing
      encrypted             = false
    }
  }

  # Additional EBS volume - /dev/sdc
  block_device_mappings {
    device_name = "/dev/sdc"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true  # Changed to true for testing
      encrypted             = false
    }
  }

  # Additional EBS volume - /dev/sdd
  block_device_mappings {
    device_name = "/dev/sdd"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true  # Changed to true for testing
      encrypted             = false
    }
  }

  # Additional EBS volume - /dev/sde
  block_device_mappings {
    device_name = "/dev/sde"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true  # Changed to true for testing
      encrypted             = false
    }
  }

  # Additional EBS volume - /dev/sdf
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true  # Changed to true for testing
      encrypted             = false
    }
  }

  # Secondary ASG instances use the same user data script
  user_data = base64encode(templatefile("${path.module}/user_data_fixed.sh.tpl", {
    AWS_REGION                         = var.aws_region
    MOUNT_POINT                        = "/var/www/html"  
    SSM_PARAM_DB_NAME                  = "/clixx/db_name"
    SSM_PARAM_DB_USER                  = "/clixx/db_user"
    SSM_PARAM_DB_PASSWORD              = "/clixx/db_password"
    SSM_PARAM_RDS_ENDPOINT             = "/clixx/RDS_ENDPOINT"
    SSM_PARAM_FILE_SYSTEM_ID           = "/clixx/efs_id"
    SSM_PARAM_LB_DNS_NAME              = "/clixx/lb_dns"
    SSM_PARAM_HOSTED_ZONE_NAME         = "/clixx/hosted_zone_name"
    SSM_PARAM_HOSTED_ZONE_RECORD_NAME  = "/clixx/hosted_zone_record"
    SSM_PARAM_HOSTED_ZONE_ID           = "/clixx/hosted_zone_id"
    SSM_PARAM_WP_ADMIN_USER            = "/clixx/wp_admin_user"
    SSM_PARAM_WP_ADMIN_PASSWORD        = "/clixx/wp_admin_password"
    SSM_PARAM_WP_ADMIN_EMAIL           = "/clixx/wp_admin_email"
  }))

  # Network configuration - don't force public IPs for private instances
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
    delete_on_termination       = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "clixx-secondary-launch-template"
      AZ   = var.availability_zones[1] # Tag with the secondary AZ
    },
    local.custom_tags
  )

  # Dependencies
  depends_on = [
    aws_db_instance.clixx_db,
    aws_iam_instance_profile.clixx_instance_profile,
    aws_lb.clixx_alb,
    aws_efs_file_system.clixx_efs,
    aws_efs_mount_target.clixx_mount_target,
    aws_security_group.ec2_sg
  ]
}

# Secondary Auto Scaling Group - pinned to the second availability zone
resource "aws_autoscaling_group" "clixx_asg_secondary" {
  name                      = "clixx-asg-secondary"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_grace_period = 300
  health_check_type         = "EC2"
  
  # Pin this ASG to ONLY use the private app subnet in the second AZ
  vpc_zone_identifier       = [aws_subnet.private_app[1].id]
  
  # Register with the same target group as the primary ASG
  target_group_arns         = [aws_lb_target_group.clixx_tg.arn]
  
  # Configure instance warmup
  default_instance_warmup   = 300
  
  # Use the secondary launch template
  launch_template {
    id      = aws_launch_template.clixx_app_secondary.id
    version = "$Latest"
  }
  
  # Dynamic tagging
  dynamic "tag" {
    for_each = merge(
      var.common_tags,
      {
        Name = "clixx-asg-secondary-instance"
        AZ   = var.availability_zones[1]
      },
      local.custom_tags
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Dependencies
  depends_on = [
    aws_launch_template.clixx_app_secondary,
    aws_lb_target_group.clixx_tg,
    aws_subnet.private_app,
    aws_route_table_association.private_app_rta
  ]
  
  # Lifecycle to ignore changes to desired capacity that might be made by AWS auto scaling
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Outputs related to the secondary ASG
output "secondary_asg_name" {
  description = "Name of the secondary Auto Scaling Group"
  value       = aws_autoscaling_group.clixx_asg_secondary.name
}

output "secondary_asg_arn" {
  description = "ARN of the secondary Auto Scaling Group"
  value       = aws_autoscaling_group.clixx_asg_secondary.arn
}

output "secondary_asg_az" {
  description = "Availability zone for the secondary ASG"
  value       = var.availability_zones[1]
}

output "asg_ha_status" {
  description = "High availability status for autoscaling groups"
  value = {
    primary_az = var.availability_zones[0]
    primary_asg_name = aws_autoscaling_group.clixx_asg.name
    primary_subnet = aws_subnet.private_app[0].id
    secondary_az = var.availability_zones[1]
    secondary_asg_name = aws_autoscaling_group.clixx_asg_secondary.name
    secondary_subnet = aws_subnet.private_app[1].id
    target_group = aws_lb_target_group.clixx_tg.name
  }
}
