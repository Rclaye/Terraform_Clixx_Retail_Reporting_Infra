# VPC for Clixx Retail Application
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "clixx-vpc"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Public Subnets - one in each availability zone
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true  # This ensures instances launched in this subnet get public IPs

  tags = {
    Name        = "clixx-public-subnet-${element(var.availability_zones, count.index)}"
    Environment = var.environment
    Terraform   = "true"
    Tier        = "public"
  }
}

# Private Subnets - one in each availability zone
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "clixx-private-subnet-${element(var.availability_zones, count.index)}"
    Environment = var.environment
    Terraform   = "true"
    Tier        = "private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "clixx-igw"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  tags = {
    Name        = "clixx-nat-eip"
    Environment = var.environment
    Terraform   = "true"
  }

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # Place NAT Gateway in first public subnet

  tags = {
    Name        = "clixx-nat-gateway"
    Environment = var.environment
    Terraform   = "true"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "clixx-public-route-table"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name        = "clixx-private-route-table"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public_rta" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table Associations
resource "aws_route_table_association" "private_rta" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private_rt.id
}

# # Network ACL for public subnets
# resource "aws_network_acl" "public" {
#   vpc_id     = aws_vpc.main.id
#   subnet_ids = aws_subnet.public[*].id

#   # Allow HTTP from anywhere
#   ingress {
#     protocol   = "tcp"
#     rule_no    = 100
#     action     = "allow"
#     cidr_block = "0.0.0.0/0"
#     from_port  = 80
#     to_port    = 80
#   }

#   # Allow HTTPS from anywhere
#   ingress {
#     protocol   = "tcp"
#     rule_no    = 110
#     action     = "allow"
#     cidr_block = "0.0.0.0/0"
#     from_port  = 443
#     to_port    = 443
#   }

#   # Allow SSH from anywhere (you may want to restrict this)
#   ingress {
#     protocol   = "tcp"
#     rule_no    = 120
#     action     = "allow"
#     cidr_block = "0.0.0.0/0"
#     from_port  = 22
#     to_port    = 22
#   }

#   # Allow ephemeral ports for return traffic
#   ingress {
#     protocol   = "tcp"
#     rule_no    = 130
#     action     = "allow"
#     cidr_block = "0.0.0.0/0"
#     from_port  = 1024
#     to_port    = 65535
#   }

#   # Allow all outbound traffic
#   egress {
#     protocol   = -1
#     rule_no    = 100
#     action     = "allow"
#     cidr_block = "0.0.0.0/0"
#     from_port  = 0
#     to_port    = 0
#   }

#   tags = {
#     Name        = "clixx-public-nacl"
#     Environment = var.environment
#     Terraform   = "true"
#   }
# }

# # Network ACL for private subnets
# resource "aws_network_acl" "private" {
#   vpc_id     = aws_vpc.main.id
#   subnet_ids = aws_subnet.private[*].id

#   # Allow all inbound traffic from VPC CIDR
#   ingress {
#     protocol   = -1
#     rule_no    = 100
#     action     = "allow"
#     cidr_block = var.vpc_cidr
#     from_port  = 0
#     to_port    = 0
#   }

#   # Allow all outbound traffic
#   egress {
#     protocol   = -1
#     rule_no    = 100
#     action     = "allow"
#     cidr_block = "0.0.0.0/0"
#     from_port  = 0
#     to_port    = 0
#   }

#   tags = {
#     Name        = "clixx-private-nacl"
#     Environment = var.environment
#     Terraform   = "true"
#   }
# }

# Bastion Host Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "clixx-bastion-sg"
  description = "Security group for bastion hosts"
  vpc_id      = aws_vpc.main.id

  # Allow SSH from admin IPs
  ingress {
    description = "SSH from Admin IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ips
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "clixx-bastion-sg"
    Environment = var.environment
    Terraform   = "true"
  }
}

# IAM Role for Bastion Host with SSM Access
resource "aws_iam_role" "bastion_role" {
  name = "clixx-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "clixx-bastion-role"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Attach SSM policy to bastion role
resource "aws_iam_role_policy_attachment" "bastion_ssm_attachment" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create instance profile for bastion
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "clixx-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

# Bastion Host in Public Subnet
resource "aws_instance" "bastion" {
  ami                    = var.ec2_ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.ec2_key_name  # Using public key for bastion
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  user_data = <<-EOF
    #!/bin/bash
    echo "Setting up bastion host..."
    # Update and install basic tools
    yum update -y
    yum install -y amazon-ssm-agent
    systemctl start amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    
    # Set up private key directory with proper permissions
    mkdir -p /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh
    chown ec2-user:ec2-user /home/ec2-user/.ssh
    
    # Create a script to help transfer keys
    cat > /home/ec2-user/setup_keys.sh << 'SETUP'
    #!/bin/bash
    # This script is used to set proper permissions on transferred SSH keys
    if [ -f /home/ec2-user/.ssh/private_key.pem ]; then
        chmod 400 /home/ec2-user/.ssh/private_key.pem
        echo "Private key permissions set to 400"
        echo "You can now SSH to private instances using:"
        echo "ssh -i ~/.ssh/private_key.pem ec2-user@PRIVATE_IP"
    else
        echo "Private key not found. Please transfer it first."
    fi
    SETUP
    
    chmod +x /home/ec2-user/setup_keys.sh
    chown ec2-user:ec2-user /home/ec2-user/setup_keys.sh
    
    echo "Bastion host setup complete!"
  EOF

  # Wait for SSH to be ready and test connection before proceeding
  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for bastion instance to be available..."
      
      # Wait for instance to be running
      aws ec2 wait instance-running --instance-ids ${self.id} --region ${var.aws_region}
      echo "Instance is running, now testing SSH connectivity..."
      
      # Test SSH connectivity with retry logic
      SSH_READY=false
      for i in {1..30}; do
        echo "Testing SSH connection attempt $i/30..."
        if ssh -i "${var.bastion_ssh_identity_file_local_path}" \
               -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -o ConnectTimeout=10 \
               -o BatchMode=yes \
               "ec2-user@${self.public_dns}" \
               "echo 'SSH connection successful'" 2>/dev/null; then
          echo "SSH is ready after $i attempts"
          SSH_READY=true
          break
        fi
        echo "SSH not ready yet, waiting 15 seconds..."
        sleep 15
      done
      
      if [ "$SSH_READY" = "false" ]; then
        echo "ERROR: SSH never became available after 30 attempts"
        exit 1
      fi
      
      echo "SSH connectivity confirmed, proceeding with key transfer..."
    EOT
  }

  # Copy private key only after SSH is confirmed working
  provisioner "local-exec" {
    command = <<EOT
      echo "Starting private key transfer to bastion..."
      
      # Attempt SCP with retry logic
      SCP_SUCCESS=false
      for i in {1..5}; do
        echo "SCP attempt $i/5..."
        if scp -i "${var.bastion_ssh_identity_file_local_path}" \
               -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -o ConnectTimeout=30 \
               -o BatchMode=yes \
               "${var.private_instance_ssh_key_local_path}" \
               "ec2-user@${self.public_dns}:/home/ec2-user/.ssh/${var.private_instance_ssh_key_destination_filename}"; then
          echo "Private key copied successfully on attempt $i"
          SCP_SUCCESS=true
          break
        fi
        echo "SCP attempt $i failed, waiting 10 seconds before retry..."
        sleep 10
      done
      
      if [ "$SCP_SUCCESS" = "false" ]; then
        echo "ERROR: SCP failed after 5 attempts"
        exit 1
      fi
      
      # Set proper permissions on the key file
      ssh -i "${var.bastion_ssh_identity_file_local_path}" \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          "ec2-user@${self.public_dns}" \
          "chmod 400 /home/ec2-user/.ssh/${var.private_instance_ssh_key_destination_filename}"
      
      echo "Private key transfer completed successfully"
      echo "Private key permissions set to 400"
    EOT
  }

  tags = {
    Name        = "clixx-bastion-host"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Update EC2 security group to allow SSH from bastion
resource "aws_security_group_rule" "ec2_ssh_from_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
  description              = "Allow SSH from bastion host"
}

# Network ACL for private subnets - update to allow SSH from public subnets
# Commenting out this rule since the related Network ACL resource is commented out
# resource "aws_network_acl_rule" "private_ssh_from_public" {
#   network_acl_id = aws_network_acl.private.id
#   rule_number    = 110
#   egress         = false
#   protocol       = "tcp"
#   rule_action    = "allow"
#   cidr_block     = var.public_subnet_cidrs[0]
#   from_port      = 22
#   to_port        = 22
# }

# Add to output for easy access to bastion info
