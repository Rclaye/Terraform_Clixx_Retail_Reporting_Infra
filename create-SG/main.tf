# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}VPC"
    }
  )
}

# --- Security Groups ---
# Public Security Group
resource "aws_security_group" "public_sg" {
  name        = "${var.project_name}RC-SG" 
  description = "Allow standard web and SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  # Inbound Rules 
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"] # Added IPv6 
  }
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"] # 
  }

  # Outbound Rules (Allow all outbound)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # Allow all protocols
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}SG" 
    }
  )
}

# Private Security Group
resource "aws_security_group" "private_sg" {
  name        = "${var.project_name}-RCPRIV" 
  description = "Allow inbound from public subnet/SG, All outbound"
  vpc_id      = aws_vpc.main.id

  # Inbound Rules (Allowing SSH and ICMP from Public Subnet CIDR for simplicity)
  ingress {
    description = "SSH from Public Subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidr] # Allow from public subnet
    # Alternatively, use security_groups = [aws_security_group.public_sg.id]
  }
  ingress {
    description = "ICMP from Public Subnet"
    from_port   = -1 # -1 for all ICMP types
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.public_subnet_cidr] # Allow from public subnet
    # Alternatively, use security_groups = [aws_security_group.public_sg.id]
  }

  # Outbound Rules (Allow all outbound - needed for NAT Gateway access)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-PRIV"
    }
  )
}