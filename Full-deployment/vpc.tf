# VPC for Clixx Retail Application
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "clixx-vpc"
    Environment = var.environment
    Terraform   = "true"
    Architecture = "Enhanced 12-subnet design"  # Add this tag to highlight the design
  }
}

# SUBNETS CONFIGURATION

# Public Subnets - For Load Balancers and Bastion hosts
resource "aws_subnet" "public" {
  count                   = min(length(var.availability_zones), length(var.public_subnet_cidrs))
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name        = "clixx-public-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
    Tier        = "public"
    Purpose     = "LoadBalancer-Bastion"
  })
}

# Private App Subnets - For Web Application Servers
resource "aws_subnet" "private_app" {
  count             = min(length(var.availability_zones), length(var.private_app_subnet_cidrs))
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_app_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = merge(var.common_tags, {
    Name        = "clixx-private-app-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
    Tier        = "private"
    Purpose     = "ApplicationServers"
  })
}

# Private DB Subnets - For RDS Database
resource "aws_subnet" "private_db" {
  count             = min(length(var.availability_zones), length(var.private_db_subnet_cidrs))
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_db_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = merge(var.common_tags, {
    Name        = "clixx-private-db-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
    Tier        = "private"
    Purpose     = "RDSDatabase"
  })
}

# Private Oracle Subnets - For Oracle Database
resource "aws_subnet" "private_oracle" {
  count             = min(length(var.availability_zones), length(var.private_oracle_subnet_cidrs))
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_oracle_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = merge(var.common_tags, {
    Name        = "clixx-private-oracle-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
    Tier        = "private"
    Purpose     = "OracleDatabase"
  })
}

# Private Java App Subnets - For Java Application Servers
resource "aws_subnet" "private_java_app" {
  count             = min(length(var.availability_zones), length(var.private_java_app_subnet_cidrs))
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_java_app_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = merge(var.common_tags, {
    Name        = "clixx-private-java-app-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
    Tier        = "private"
    Purpose     = "JavaApplicationServers"
  })
}

# Private Java DB Subnets - For Java Application Database
resource "aws_subnet" "private_java_db" {
  count             = min(length(var.availability_zones), length(var.private_java_db_subnet_cidrs))
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_java_db_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = merge(var.common_tags, {
    Name        = "clixx-private-java-db-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
    Tier        = "private"
    Purpose     = "JavaDatabase"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name        = "clixx-igw"
    Environment = var.environment
  })
}

# Elastic IPs for NAT Gateways - one per AZ for high availability
resource "aws_eip" "nat" {
  count = length(var.availability_zones)
  
  tags = merge(var.common_tags, {
    Name        = "clixx-nat-eip-${count.index + 1}"
    Environment = var.environment
  })

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateways - one per AZ for high availability
resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = element(aws_subnet.public[*].id, count.index % length(aws_subnet.public))

  tags = merge(var.common_tags, {
    Name        = "clixx-nat-gateway-${count.index + 1}"
    Environment = var.environment
  })

  # Make dependency explicit for clarity
  depends_on = [
    aws_internet_gateway.igw,
    aws_subnet.public,
    aws_eip.nat
  ]
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.common_tags, {
    Name        = "clixx-public-route-table"
    Environment = var.environment
  })
}

# Route Tables for Private Subnets - one per AZ for fault tolerance
resource "aws_route_table" "private_rt" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[count.index].id
  }

  tags = merge(var.common_tags, {
    Name        = "clixx-private-route-table-${count.index + 1}"
    Environment = var.environment
  })
}

# Public Route Table Associations
resource "aws_route_table_association" "public_rta" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Private App Route Table Associations
resource "aws_route_table_association" "private_app_rta" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_rt[count.index % length(aws_route_table.private_rt)].id

  depends_on = [
    aws_subnet.private_app,
    aws_route_table.private_rt
  ]
}

# Private DB Route Table Associations
resource "aws_route_table_association" "private_db_rta" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_rt[count.index % length(aws_route_table.private_rt)].id

  depends_on = [
    aws_subnet.private_db,
    aws_route_table.private_rt
  ]
}

# Private Oracle Route Table Associations
resource "aws_route_table_association" "private_oracle_rta" {
  count          = length(aws_subnet.private_oracle)
  subnet_id      = aws_subnet.private_oracle[count.index].id
  route_table_id = aws_route_table.private_rt[count.index % length(aws_route_table.private_rt)].id

  depends_on = [
    aws_subnet.private_oracle,
    aws_route_table.private_rt
  ]
}

# Private Java App Route Table Associations
resource "aws_route_table_association" "private_java_app_rta" {
  count          = length(aws_subnet.private_java_app)
  subnet_id      = aws_subnet.private_java_app[count.index].id
  route_table_id = aws_route_table.private_rt[count.index % length(aws_route_table.private_rt)].id

  depends_on = [
    aws_subnet.private_java_app,
    aws_route_table.private_rt
  ]
}

# Private Java DB Route Table Associations
resource "aws_route_table_association" "private_java_db_rta" {
  count          = length(aws_subnet.private_java_db)
  subnet_id      = aws_subnet.private_java_db[count.index].id
  route_table_id = aws_route_table.private_rt[count.index % length(aws_route_table.private_rt)].id

  depends_on = [
    aws_subnet.private_java_db,
    aws_route_table.private_rt
  ]
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
#   # Use all the available private subnet IDs
#   subnet_ids = concat(
#     aws_subnet.private_app[*].id,
#     aws_subnet.private_db[*].id,
#     aws_subnet.private_oracle[*].id,
#     aws_subnet.private_java_app[*].id,
#     aws_subnet.private_java_db[*].id
#   )

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

#   # Add explicit dependency on all private subnets
#   depends_on = [
#     aws_subnet.private_app,
#     aws_subnet.private_db,
#     aws_subnet.private_oracle,
#     aws_subnet.private_java_app,
#     aws_subnet.private_java_db
#   ]

#   tags = {
#     Name        = "clixx-private-nacl"
#     Environment = var.environment
#     Terraform   = "true"
#   }
# }
