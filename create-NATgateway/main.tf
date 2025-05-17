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
  name        = "${var.project_name}SG" 
  description = "Allow standard web and SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  # Inbound Rules (Simplified from screenshots for common use)
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
    ipv6_cidr_blocks = ["::/0"] # Added IPv6 
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
  name        = "${var.project_name}-PRIV" 
  description = "Allow inbound from public subnet/SG, All outbound"
  vpc_id      = aws_vpc.main.id

  # Inbound Rules (Allowing SSH and ICMP from Public Subnet CIDR for simplicity)
  ingress {
    description = "SSH from Public Subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidr] # Allow from public subnet
  }
  ingress {
    description = "ICMP from Public Subnet"
    from_port   = -1 # -1 for all ICMP types
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.public_subnet_cidr] # Allow from public subnet
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

# --- Subnets ---
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.public_az
  map_public_ip_on_launch = true # Public subnet instances get public IPs

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}SUB1" 
    }
  )
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.private_az
  map_public_ip_on_launch = false # Private subnet instances do not

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}SUB2" 
    }
  )
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}GW" 
    }
  )
}

# --- Route Table for Public Subnet ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}RT1"
    }
  )
}

# --- Route Table Association ---
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"  

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-nat-eip"
    }
  )

  depends_on = [aws_internet_gateway.gw]
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id 

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-nat-gateway"
    }
  )

  depends_on = [aws_internet_gateway.gw]
}

# Private Route Table (for routing through NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}RT2"
    }
  )
}

# Private Route Table Association
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}