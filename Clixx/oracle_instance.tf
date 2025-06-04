# Oracle Database EC2 Instance deployed in the private Oracle subnet

resource "aws_security_group" "oracle_instance_sg" {
  name        = "clixx-oracle-instance-sg"
  description = "Security group for Oracle database EC2 instance"
  vpc_id      = aws_vpc.main.id

  # Oracle listener port
  ingress {
    description     = "Oracle DB listener"
    from_port       = 1521
    to_port         = 1521
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # SSH from bastion
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "clixx-oracle-instance-sg"
  })
}

# IAM role for Oracle instance
resource "aws_iam_role" "oracle_instance_role" {
  name = "clixx-oracle-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name = "clixx-oracle-instance-role"
  })
}

# Attach SSM policy to the role for management
resource "aws_iam_role_policy_attachment" "oracle_ssm_policy" {
  role       = aws_iam_role.oracle_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for the Oracle instance
resource "aws_iam_instance_profile" "oracle_instance_profile" {
  name = "clixx-oracle-instance-profile"
  role = aws_iam_role.oracle_instance_role.name
}

# Oracle EC2 instance
resource "aws_instance" "oracle_db_instance" {
  count                  = 0  # Set to 0 since you don't need the actual instance yet
  ami                    = "ami-0554aa6767e249943"  # Amazon Linux 2 AMI, replace with Oracle Linux if preferred
  instance_type          = "t2.large"              # Increase based on Oracle requirements
  subnet_id              = length(aws_subnet.private_oracle) > 0 ? aws_subnet.private_oracle[0].id : null
  vpc_security_group_ids = [aws_security_group.oracle_instance_sg.id]
  key_name               = var.private_key_name
  iam_instance_profile   = aws_iam_instance_profile.oracle_instance_profile.name

  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    iops                  = 6000
    throughput            = 250
    delete_on_termination = true
    encrypted             = true
  }

  # Additional EBS volume for Oracle data files
  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 200
    volume_type           = "gp3"
    iops                  = 9000
    throughput            = 500
    delete_on_termination = false
    encrypted             = true
    
    tags = merge(var.common_tags, {
      Name = "oracle-data-volume"
    })
  }

  # User data to set up Oracle prerequisites
  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    yum update -y
    yum install -y oracle-database-preinstall-19c amazon-ssm-agent
    
    # Start SSM agent
    systemctl start amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    
    # Set up Oracle directories
    mkdir -p /u01/app/oracle/product/19c/dbhome_1
    mkdir -p /u02/oradata
    chown -R oracle:oinstall /u01 /u02
    
    # Mount the EBS volume for Oracle data - more reliable device detection
    DATA_VOLUME=$(lsblk -o NAME,SERIAL | grep -v nvme0n1 | grep nvme | head -1 | awk '{print $1}')
    if [ -n "$DATA_VOLUME" ]; then
      mkfs -t xfs /dev/$DATA_VOLUME
      mkdir -p /u02/oradata
      echo "/dev/$DATA_VOLUME  /u02/oradata  xfs  defaults,noatime  0  2" >> /etc/fstab
      mount -a
      chown -R oracle:oinstall /u02/oradata
      echo "Oracle data volume mounted successfully at /u02/oradata" >> /tmp/oracle_setup.log
    else
      echo "ERROR: Could not find the Oracle data volume" >> /tmp/oracle_setup.log
    fi
    
    # Get RDS endpoint for testing connectivity
    # Use the AWS region from instance metadata instead of referencing the resource directly
    AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    RDS_ENDPOINT=$(aws ssm get-parameter --name "/clixx/RDS_ENDPOINT" --region $AWS_REGION --query "Parameter.Value" --output text)
    
    if [ -n "$RDS_ENDPOINT" ]; then
      echo "RDS endpoint found: $RDS_ENDPOINT" >> /tmp/oracle_setup.log
    else
      echo "WARNING: Could not find RDS endpoint" >> /tmp/oracle_setup.log
    fi
    
    # Prepare for Oracle installation
    echo "oracle soft nofile 65536" >> /etc/security/limits.conf
    echo "oracle hard nofile 65536" >> /etc/security/limits.conf
    echo "oracle soft nproc 16384" >> /etc/security/limits.conf
    echo "oracle hard nproc 16384" >> /etc/security/limits.conf
    
    # Set hostname
    hostnamectl set-hostname oracle-db
    
    # Complete message
    echo "Oracle EC2 instance preparation complete" > /tmp/oracle_setup_complete.txt
  EOF

  tags = merge(var.common_tags, {
    Name = "clixx-oracle-db-instance"
  })

  depends_on = [
    aws_subnet.private_oracle,
    aws_security_group.oracle_instance_sg,
    aws_route_table_association.private_oracle_rta
  ]
}

output "oracle_instance_private_ip" {
  description = "Private IP of the Oracle database instance"
  value       = length(aws_instance.oracle_db_instance) > 0 ? aws_instance.oracle_db_instance[0].private_ip : "Oracle instance not deployed"
}

output "oracle_access_command" {
  description = "Command to access Oracle instance via bastion"
  value       = length(aws_instance.oracle_db_instance) > 0 ? "ssh -i ${var.bastion_ssh_key_path} -J ec2-user@${aws_instance.bastion.public_dns} ec2-user@${aws_instance.oracle_db_instance[0].private_ip}" : "Oracle instance not deployed"
}
