# VPC 12 subnet infrastructure deployment of the Clixx Application.

locals {
  custom_tags = {
    owner       = "richard.claye@gmail.com"
    Stackteam   = "StackCloud13"
    CreatedBy   = "Terraform"
  }
  
  # Get all private subnet IDs for use in resources
  all_private_subnets = concat(
    aws_subnet.private_app[*].id,
    aws_subnet.private_db[*].id,
    aws_subnet.private_oracle[*].id,
    aws_subnet.private_java_app[*].id,
    aws_subnet.private_java_db[*].id
  )

  # Timestamp for snapshot naming to ensure uniqueness
  timestamp = formatdate("YYYYMMDDhhmmss", timestamp())
}

# Security Groups for VPCs, EC2, EFS, RDS, and Load Balancer
# ALB Security Group - allows inbound HTTP/HTTPS from anywhere
resource "aws_security_group" "alb_sg" {
  name        = "clixx-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "clixx-alb-sg"
  }, local.custom_tags)

  depends_on = [aws_vpc.main]
}

# EC2 Security Group - allows HTTP/HTTPS from ALB, SSH from Bastion
resource "aws_security_group" "ec2_sg" {
  name        = "clixx-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "HTTPS from ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Updated: SSH access from bastion only
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Remove direct reference to rds_sg in ec2_sg
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "clixx-ec2-sg"
  }, local.custom_tags)

  depends_on = [aws_vpc.main, aws_security_group.alb_sg, aws_security_group.bastion_sg]
}

# EFS Security Group - allows NFS from EC2 instances
resource "aws_security_group" "efs_sg" {
  name        = "clixx-efs-sg"
  description = "Security group for EFS Mount Targets"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from EC2 instances"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  ingress {
    description = "NFS from VPC CIDR"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Allow from the entire VPC
  }
  
  # Add rule to allow NFS traffic from bastion hosts for troubleshooting
  ingress {
    description     = "NFS from Bastion hosts"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name  = "clixx-efs-sg"
    Owner = "Richard.claye@gmail.com"
  }, local.custom_tags)

  depends_on = [aws_vpc.main, aws_security_group.ec2_sg]
}

# RDS Security Group - allows MySQL/PostgreSQL from EC2 instances and bastion
resource "aws_security_group" "rds_sg" {
  name        = "clixx-rds-sg"
  description = "Security group for RDS instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2 instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
  
  # Add MySQL access from bastion for management
  ingress {
    description     = "MySQL from Bastion Host"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "clixx-rds-sg"
  }, local.custom_tags)

  depends_on = [aws_vpc.main, aws_security_group.ec2_sg]
}

# Oracle DB Security Group
resource "aws_security_group" "oracle_sg" {
  name        = "clixx-oracle-sg"
  description = "Security group for Oracle database instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Oracle DB from EC2 instances"
    from_port       = 1521
    to_port         = 1521
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
  
  # Add Oracle access from bastion for management
  ingress {
    description     = "Oracle DB from Bastion Host"
    from_port       = 1521
    to_port         = 1521
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "clixx-oracle-sg"
  }, local.custom_tags)

  depends_on = [aws_vpc.main, aws_security_group.ec2_sg, aws_security_group.bastion_sg]
}

# Update Database Subnet Group to use all DB subnets
resource "aws_db_subnet_group" "clixx_db_subnet_group" {
  name        = "clixx-db-subnet-group"
  description = "Subnet group for Clixx RDS instance"
  # Use all available DB subnets
  subnet_ids  = aws_subnet.private_db[*].id

  tags = merge(
    var.common_tags,
    {
      Name = "clixx-db-subnet-group"
    },
    local.custom_tags
  )

  depends_on = [aws_subnet.private_db]
}

# Create Java DB subnet group
resource "aws_db_subnet_group" "java_db_subnet_group" {
  name        = "java-db-subnet-group"
  description = "Subnet group for Java DB instance"
  # Use all available Java DB subnets
  subnet_ids  = aws_subnet.private_java_db[*].id

  tags = merge(
    var.common_tags,
    {
      Name = "java-db-subnet-group"
    },
    local.custom_tags
  )

  depends_on = [aws_subnet.private_java_db]
}

# Create a MySQL parameter group to match the RDS snapshot engine version
resource "aws_db_parameter_group" "mysql80" {
  name        = "clixx-mysql80"
  family      = "mysql8.0"  # Ensure this matches your snapshot's MySQL version
  description = "Custom parameter group for MySQL 8.0"
  
  tags = merge(
    var.common_tags,
    {
      Name = "clixx-mysql80-parameter-group"
    },
    local.custom_tags
  )
}

# Create a copy of the source RDS snapshot
resource "aws_db_snapshot_copy" "clixx_snapshot_copy" {
  source_db_snapshot_identifier = var.db_snapshot_identifier
  target_db_snapshot_identifier = "clixx-snapshot-copy-${local.timestamp}"
  
  tags = merge(
    var.common_tags,
    {
      Name = "clixx-snapshot-copy"
    },
    local.custom_tags
  )

  # No direct dependencies needed here, but good practice to ensure parameter group exists
  depends_on = [aws_db_parameter_group.mysql80]
}

# RDS Instance - restored from copied snapshot
resource "aws_db_instance" "clixx_db" {
  identifier             = "clixx-db-instance"
  instance_class         = var.db_instance_class
  snapshot_identifier    = aws_db_snapshot_copy.clixx_snapshot_copy.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.clixx_db_subnet_group.name
  multi_az               = true  # Use variable instead of hardcoded value
  publicly_accessible    = false
  skip_final_snapshot    = true  # Use variable instead of hardcoded value
  storage_encrypted      = true
  apply_immediately      = true  # Use variable instead of hardcoded value

  # Disable automatic minor version upgrades to prevent "Upgrading" status
  auto_minor_version_upgrade = false
  
  # Disable automatic backups
  backup_retention_period = 0
  backup_window           = null
  maintenance_window      = "Mon:00:00-Mon:03:00"
  
  # Use our MySQL 8.0 parameter group instead of MySQL 5.7
  parameter_group_name = aws_db_parameter_group.mysql80.name
  
  tags = merge(
    var.common_tags,
    {
      Name = "clixx-db-instance"
    },
    local.custom_tags
  )

  lifecycle {
    ignore_changes = [
      snapshot_identifier,
      engine_version,   # Ignore engine version changes during auto minor upgrades
      backup_retention_period,
      backup_window,
      maintenance_window
    ]
    
    # Set prevent_destroy based on environment
    # Comment this out when you need to destroy resources for testing
    # prevent_destroy = true
  }

  depends_on = [
    aws_db_subnet_group.clixx_db_subnet_group,
    aws_security_group.rds_sg,
    aws_db_snapshot_copy.clixx_snapshot_copy
  ]
}

# Fetch the existing hosted zone for DNS record creation
data "aws_route53_zone" "clixx_zone" {
  name = var.domain_name
}

# CREATE A RECORD IN THE ZONE FOR THE ALB (ROOT DOMAIN) - A RECORD ALIAS METHOD
resource "aws_route53_record" "clixx_existing_record" {
  count   = var.create_existing_record ? 1 : 0 // Create only if the variable is true
  zone_id = data.aws_route53_zone.clixx_zone.id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_lb.clixx_alb.dns_name
    zone_id                = aws_lb.clixx_alb.zone_id
    evaluate_target_health = true
  }
}

# CREATE A RECORD IN THE ZONE FOR THE ALB (SUBDOMAIN) - CNAME METHOD
resource "aws_route53_record" "clixx_record" {
  count   = var.create_dns_record ? 1 : 0
  zone_id = data.aws_route53_zone.clixx_zone.id
  name    = "${var.new_record}.${trimsuffix(data.aws_route53_zone.clixx_zone.name, ".")}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_lb.clixx_alb.dns_name}."]
  depends_on = [aws_lb.clixx_alb]
}

# Replace Secrets Manager with SSM Parameter Store for database credentials
resource "aws_ssm_parameter" "db_name" {
  name  = "/clixx/db_name"
  type  = "String"
  value = aws_db_instance.clixx_db.db_name
}

resource "aws_ssm_parameter" "db_user" {
  name  = "/clixx/db_user"
  type  = "String"
  value = var.db_user
}

resource "aws_ssm_parameter" "db_password" {
  name      = "/clixx/db_password"
  type      = "SecureString"
  value     = var.db_password
  overwrite = true
}

resource "aws_ssm_parameter" "rds_endpoint" {
  name      = "/clixx/RDS_ENDPOINT"
  type      = "String"
  value     = aws_db_instance.clixx_db.address
  overwrite = true

  depends_on = [aws_db_instance.clixx_db]
}

resource "aws_ssm_parameter" "efs_id" {
  name  = "/clixx/efs_id"
  type  = "String"
  value = aws_efs_file_system.clixx_efs.id
}

resource "aws_ssm_parameter" "lb_dns" {
  name  = "/clixx/lb_dns"
  type  = "String"
  value = aws_lb.clixx_alb.dns_name
}

resource "aws_ssm_parameter" "hosted_zone_name" {
  name  = "/clixx/hosted_zone_name"
  type  = "String"
  value = var.hosted_zone_name
}

resource "aws_ssm_parameter" "hosted_zone_record" {
  name  = "/clixx/hosted_zone_record"
  type  = "String"
  value = var.create_dns_record ? var.hosted_zone_record_name : ""
}

resource "aws_ssm_parameter" "hosted_zone_id" {
  name  = "/clixx/hosted_zone_id"
  type  = "String"
  value = var.create_dns_record ? data.aws_route53_zone.clixx_zone.zone_id : ""
}

resource "aws_ssm_parameter" "wp_admin_user" {
  name  = "/clixx/wp_admin_user"
  type  = "String"
  value = var.wp_admin_user
}

resource "aws_ssm_parameter" "wp_admin_password" {
  name      = "/clixx/wp_admin_password"
  type      = "SecureString"
  value     = var.wp_admin_password
  overwrite = true
}

resource "aws_ssm_parameter" "wp_admin_email" {
  name  = "/clixx/wp_admin_email"
  type  = "String"
  value = var.wp_admin_email
}

# IAM Policy for EC2 instance to access Secrets Manager and other AWS resources
resource "aws_iam_policy" "clixx_deploy_policy" {
  name        = "terraformclixx_Policy"  
  description = "Policy for Clixx application deployment"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "efs:DescribeFileSystems",
          "efs:ClientMount",
          "efs:ClientWrite",
          # Add these additional EFS permissions
          "efs:DescribeMountTargets",
          "efs:DescribeMountTargetSecurityGroups",
          "efs:DescribeAccessPoints",
          "efs:CreateAccessPoint",
          "efs:DeleteAccessPoint",
          "efs:PutBackupPolicy",
          "ec2:DescribeInstances",
          "ec2:DescribeAddresses",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVolumes",
          "ec2:DescribeSecurityGroups", # Add permission to describe security groups
          "ec2:DescribeSubnets",        # Add permission to describe subnets
          "ec2:DescribeVpcAttribute",   # Add permission to describe VPC attributes
          "ec2:DescribeRouteTables"     # Add permission to describe route tables
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "elasticloadbalancing:DescribeLoadBalancers"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "*"  # or lock down to your /clixx/* ARN
      }
    ]
  })
}

# IAM Role for EC2 instances
resource "aws_iam_role" "clixx_deploy_role" {
  name = "terraform-DeployRole-clixx"  # Changed name to avoid conflict
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = merge(
    var.common_tags,
    {
      Name = "terraform-deploy-role"
    },
    local.custom_tags
  )
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "clixx_role_policy_attach" {
  role       = aws_iam_role.clixx_deploy_role.name
  policy_arn = aws_iam_policy.clixx_deploy_policy.arn
}

# Create instance profile
resource "aws_iam_instance_profile" "clixx_instance_profile" {
  name = "terr-DeployProfile-rc"  # Also update this to be consistent
  role = aws_iam_role.clixx_deploy_role.name
}

# Load Balancer Configuration
# Create target group for the load balancer
resource "aws_lb_target_group" "clixx_tg" {
  name     = "clixx-target-group"
  port     = 80                  # keep listening on port 80
  protocol = "HTTP"              # protocol remains HTTP
  vpc_id   = aws_vpc.main.id

  # Improved health check settings for WordPress
  health_check {
    enabled             = true
    interval            = 30
    path                = "/health.php"  # Changed from /health.php to root path
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 10    # Increased to be more lenient
    timeout             = 10   # Increased timeout
    matcher             = "200-499"  # Accept more status codes
  }

  # Increased deregistration delay to give connections time to drain
  deregistration_delay = 300 # 5 minutes to ensure proper connection draining

  tags = merge(
    var.common_tags,
    {
      Name = "clixx-target-group"
    },
    local.custom_tags
  )

  depends_on = [aws_vpc.main]
}

# Create the Application Load Balancer - Update to use all available public subnets
resource "aws_lb" "clixx_alb" {
  name               = "clixx-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
  enable_deletion_protection = false

  tags = merge(
    var.common_tags,
    {
      Name = "clixx-alb"
    },
    local.custom_tags
  )

  depends_on = [
    aws_vpc.main,
    aws_subnet.public,
    aws_security_group.alb_sg
  ]
}


# HTTP Listener - forwards to target group instead of redirecting to HTTPS
resource "aws_lb_listener" "clixx_http" {
  load_balancer_arn = aws_lb.clixx_alb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_tg.arn
  }

  depends_on = [aws_lb.clixx_alb, aws_lb_target_group.clixx_tg]
}

# HTTPS Listener - using the imported certificate ARN from acm_verification.tf
resource "aws_lb_listener" "clixx_https" {
  load_balancer_arn = aws_lb.clixx_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"  # Updated to TLS 1.3 and 1.2 policy
  certificate_arn   = local.certificate_arn  # Use the local value from acm_verification.tf
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_tg.arn
  }

  depends_on = [aws_lb.clixx_alb, aws_lb_target_group.clixx_tg]
}

# EC2 Launch Template Configuration
resource "aws_launch_template" "clixx_app" {
  name        = "clixx-launch-template"
  description = "Launch template for Clixx retail application"
  image_id      = var.ec2_ami
  instance_type = var.ec2_instance_type
  key_name      = var.private_key_name  # Using private_key_name from vars.tf

  # Enable detailed monitoring for faster metric collection
  monitoring {
    enabled = true
  }

  # Use an IAM instance profile
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
  # User data template - ensure it's correctly implementing the health check endpoint
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
  # Fix network interface configuration - don't force public IPs for private instances
  network_interfaces {
    associate_public_ip_address = false  # Changed to false for private subnet deployment
    security_groups             = [aws_security_group.ec2_sg.id]
    delete_on_termination       = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "clixx-launch-template"
    },
    local.custom_tags
  )

  # Comprehensive dependencies
  depends_on = [
    aws_db_instance.clixx_db,
    aws_iam_instance_profile.clixx_instance_profile,
    aws_lb.clixx_alb,
    aws_efs_file_system.clixx_efs,
    aws_efs_mount_target.clixx_mount_target,
    aws_security_group.ec2_sg,
    aws_ssm_parameter.db_name,
    aws_ssm_parameter.db_user,
    aws_ssm_parameter.db_password,
    aws_ssm_parameter.rds_endpoint,
    aws_ssm_parameter.efs_id,
    aws_ssm_parameter.lb_dns,
    aws_ssm_parameter.hosted_zone_name,
    aws_ssm_parameter.hosted_zone_record,
    aws_ssm_parameter.hosted_zone_id,
    aws_ssm_parameter.wp_admin_user,
    aws_ssm_parameter.wp_admin_password,
    aws_ssm_parameter.wp_admin_email
  ]
}

# Auto Scaling Group Configuration - update name and add zone tag
resource "aws_autoscaling_group" "clixx_asg" {
  name                      = "clixx-asg-primary"  # Updated name to clarify it's the primary ASG
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_grace_period = 300
  health_check_type         = "EC2"
  
  # Pin this ASG to ONLY use the private app subnet in the first AZ
  vpc_zone_identifier       = [aws_subnet.private_app[0].id]  # Use only the first AZ's subnet
  
  target_group_arns         = [aws_lb_target_group.clixx_tg.arn]
  
  # Configure instance warmup
  default_instance_warmup   = 300
  
  launch_template {
    id      = aws_launch_template.clixx_app.id
    version = "$Latest"
  }
  dynamic "tag" {
    for_each = merge(
      var.common_tags,
      {
        Name = "clixx-asg-primary-instance"  # Updated instance name
        AZ   = var.availability_zones[0]     # Tag with the primary AZ
      },
      local.custom_tags
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Improve dependencies
  depends_on = [
    aws_launch_template.clixx_app,
    aws_lb_target_group.clixx_tg,
    aws_subnet.private_app,
    aws_route_table_association.private_app_rta
  ]
  
  # Lifecycle to ignore changes to desired capacity that might be made by AWS auto scaling
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# EFS Configuration - Create a new EFS file system
resource "aws_efs_file_system" "clixx_efs" {
  creation_token = "clixx-efs-deploy2" 
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
  encrypted       = true
  
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }
  
  tags = merge({
    Name = "clixx-efs"
  }, local.custom_tags, var.common_tags)
  
  depends_on = [aws_security_group.efs_sg]
}

# Create EFS access point for WordPress
resource "aws_efs_access_point" "clixx_access_point" {
  file_system_id = aws_efs_file_system.clixx_efs.id
  
  posix_user {
    gid = 48 # Apache default group ID
    uid = 48 # Apache default user ID
  }
  
  root_directory {
    path = "/var/www/html" # Path for WordPress files
    creation_info {
      owner_gid   = 48
      owner_uid   = 48
      permissions = "755"
    }
  }
  
  tags = merge({
    Name = "clixx-efs-access-point"
  }, local.custom_tags, var.common_tags)
}

# Create/Manage EFS mount targets - ONE PER AZ, using PRIVATE subnets only
resource "aws_efs_mount_target" "clixx_mount_target" {
  # Use application subnets for mount targets - one per AZ
  for_each = {
    for i, subnet in aws_subnet.private_app : i => subnet
    if i < length(var.availability_zones)  # Limit to available AZs
  }
  
  file_system_id  = aws_efs_file_system.clixx_efs.id
  subnet_id       = each.value.id
  security_groups = [aws_security_group.efs_sg.id]

  # Ensure mount targets are created after network configuration is complete
  depends_on = [
    aws_subnet.private_app,
    aws_security_group.efs_sg,
    aws_efs_file_system.clixx_efs,
    aws_route_table_association.private_app_rta,
    aws_vpc.main,
    aws_internet_gateway.igw,
    aws_nat_gateway.nat_gw
  ]
}
