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

  # Root volume configuration
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = false
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
      delete_on_termination = false
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
      delete_on_termination = false
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
      delete_on_termination = false
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
      delete_on_termination = false
      encrypted             = false
    }
  }

  # Use the corrected user_data.sh.tpl file
  user_data = base64encode(templatefile("${path.module}/user_data_fixed.sh.tpl", {}))

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
