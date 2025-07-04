terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn     = "arn:aws:iam::${var.target_account_id}:role/${var.target_role_name}"
    session_name = "TerraformSession"
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "clixx-vpc"
    Environment = var.environment_tag
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "clixx-igw"
    Environment = var.environment_tag
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name        = "clixx-public-subnet-${element(var.availability_zones, count.index)}"
    Environment = var.environment_tag
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "clixx-private-subnet-${element(var.availability_zones, count.index)}"
    Environment = var.environment_tag
  }
}

# Add Route Tables for proper networking
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "clixx-public-route-table"
    Environment = var.environment_tag
  }
}

# NAT Gateway for private subnets
resource "aws_eip" "nat" {
  tags = {
    Name        = "clixx-nat-eip"
    Environment = var.environment_tag
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "clixx-nat-gateway"
    Environment = var.environment_tag
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name        = "clixx-private-route-table"
    Environment = var.environment_tag
  }
}

# Route table associations
resource "aws_route_table_association" "public_rta" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private_rt.id
}

# Security Groups
resource "aws_security_group" "clixx_sg" {
  name   = "clixx_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ips
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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

  tags = {
    Name = "clixx-security-group"
    Env  = "prod"
  }
}

# Add ALB Security Group
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

  tags = {
    Name = "clixx-alb-sg"
    Env  = "prod"
  }
}

# Update EC2 Security Group to allow ALB access
resource "aws_security_group" "clixx_sg" {
  name   = "clixx_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ips
  }

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "clixx-security-group"
    Env  = "prod"
  }
}

# Add RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "clixx-rds-sg"
  description = "Security group for RDS instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2 instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.clixx_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "clixx-rds-sg"
    Env  = "prod"
  }
}

# Add EFS Security Group
resource "aws_security_group" "efs_sg" {
  name        = "clixx-efs-sg"
  description = "Security group for EFS Mount Targets"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from EC2 instances"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.clixx_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "clixx-efs-sg"
    Env  = "prod"
  }
}

# Add Database Subnet Group
resource "aws_db_subnet_group" "clixx_db_subnet_group" {
  name       = "clixx-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "clixx-db-subnet-group"
    Env  = "prod"
  }
}

# Add RDS Instance
resource "aws_db_instance" "clixx_db" {
  identifier             = "clixx-db-instance"
  instance_class         = var.db_instance_class
  snapshot_identifier    = var.db_snapshot_identifier
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.clixx_db_subnet_group.name
  
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true
  storage_encrypted      = true

  tags = {
    Name = "clixx-db-instance"
    Env  = "prod"
  }
}

# Add EFS File System
resource "aws_efs_file_system" "clixx_efs" {
  creation_token   = "clixx-efs-deploy"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name = "clixx-efs"
    Env  = "prod"
  }
}

# Add EFS Mount Targets
resource "aws_efs_mount_target" "clixx_mount_target" {
  count           = length(aws_subnet.public)
  file_system_id  = aws_efs_file_system.clixx_efs.id
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

# Add Application Load Balancer
resource "aws_lb" "clixx_alb" {
  name               = "clixx-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "clixx-alb"
    Env  = "prod"
  }
}

# Add Target Group
resource "aws_lb_target_group" "clixx_tg" {
  name     = "clixx-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 10
    matcher             = "200-499"
  }

  tags = {
    Name = "clixx-target-group"
    Env  = "prod"
  }
}

# Add Listeners
resource "aws_lb_listener" "clixx_https" {
  load_balancer_arn = aws_lb.clixx_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_tg.arn
  }
}

# Add SSM Parameters
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
  name  = "/clixx/RDS_ENDPOINT"
  type  = "String"
  value = aws_db_instance.clixx_db.address
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

# Add IAM Role for EC2
resource "aws_iam_role" "clixx_deploy_role" {
  name = "clixx-deploy-role"
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
}

resource "aws_iam_role_policy" "clixx_deploy_policy" {
  name = "clixx-deploy-policy"
  role = aws_iam_role.clixx_deploy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "inspector:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "clixx_instance_profile" {
  name = "clixx-instance-profile"
  role = aws_iam_role.clixx_deploy_role.name
}

# Update Launch Template with proper user data
resource "aws_launch_template" "clixx_template" {
  name_prefix   = "clixx-template"
  image_id      = data.aws_ami.clixx_ami.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.clixx_kp.key_name

  vpc_security_group_ids = [aws_security_group.clixx_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.clixx_instance_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    AWS_REGION                         = var.region
    MOUNT_POINT                        = "/var/www/html"
    SSM_PARAM_DB_NAME                  = "/clixx/db_name"
    SSM_PARAM_DB_USER                  = "/clixx/db_user"
    SSM_PARAM_DB_PASSWORD              = "/clixx/db_password"
    SSM_PARAM_RDS_ENDPOINT             = "/clixx/RDS_ENDPOINT"
    SSM_PARAM_FILE_SYSTEM_ID           = "/clixx/efs_id"
    SSM_PARAM_LB_DNS_NAME              = "/clixx/lb_dns"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "clixx-instance"
      Env  = "prod"
    }
  }
}

# Update Auto Scaling Group to use Target Group
resource "aws_autoscaling_group" "clixx_asg" {
  name                = "clixx-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  target_group_arns   = [aws_lb_target_group.clixx_tg.arn]

  launch_template {
    id      = aws_launch_template.clixx_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "clixx-asg-instance"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Env"
    value               = "prod"
    propagate_at_launch = true
  }
}

# Route 53 DNS Record
data "aws_route53_zone" "clixx_zone" {
  name = var.domain_name
}

resource "aws_route53_record" "clixx_record" {
  count   = var.create_dns_record ? 1 : 0
  zone_id = data.aws_route53_zone.clixx_zone.id
  name    = "clixx.${trimsuffix(data.aws_route53_zone.clixx_zone.name, ".")}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_lb.clixx_alb.dns_name}."]
}

output "ami_id" {
  value = data.aws_ami.clixx_ami.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "alb_dns_name" {
  value = aws_lb.clixx_alb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.clixx_db.address
}
