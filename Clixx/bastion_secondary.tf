# Secondary Bastion Host for high availability across availability zones

# Create a secondary bastion host in the other availability zone
resource "aws_instance" "bastion_secondary" {
  ami                    = var.bastion_ami_id != "" ? var.bastion_ami_id : var.ec2_ami
  instance_type          = var.bastion_instance_type
  # Use the second public subnet in the other availability zone
  subnet_id              = aws_subnet.public[1].id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.bastion_key_name
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.common_tags, {
    Name = "clixx-bastion-secondary"
  })

  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    yum update -y
    
    # Install required software
    yum install -y httpd amazon-ssm-agent mysql php nmap-ncat jq git unzip libnsl gcc-c++ libaio libaio-devel
    
    # Start and enable services
    systemctl start httpd
    systemctl enable httpd
    systemctl start amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    
    # Create a simple welcome page
    echo "<h1>Clixx Retail - Secondary Bastion Host</h1>" > /var/www/html/index.html
    echo "<p>This is the secondary bastion host in AZ ${var.availability_zones[1]} for Clixx Retail infrastructure.</p>" >> /var/www/html/index.html
    
    # Install Java for Oracle SQL Developer
    amazon-linux-extras install -y java-openjdk11
    
    # Install Oracle Instant Client and SQL*Plus
    mkdir -p /opt/oracle
    cd /opt/oracle
    
    # Download Oracle Instant Client
    curl -O https://download.oracle.com/otn_software/linux/instantclient/1919000/instantclient-basic-linux.x64-19.19.0.0.0dbru.zip
    curl -O https://download.oracle.com/otn_software/linux/instantclient/1919000/instantclient-sqlplus-linux.x64-19.19.0.0.0dbru.zip
    
    # Extract Oracle Instant Client
    unzip -q instantclient-basic-linux.x64-19.19.0.0.0dbru.zip -d /opt/oracle
    unzip -q instantclient-sqlplus-linux.x64-19.19.0.0.0dbru.zip -d /opt/oracle
    
    # Set up environment for Oracle client
    echo "export LD_LIBRARY_PATH=/opt/oracle/instantclient_19_19" >> /etc/bashrc
    echo "export PATH=\$PATH:/opt/oracle/instantclient_19_19" >> /etc/bashrc
    
    # Install PHP MySQL tools for database management
    yum install -y php-mysqlnd mysql
    
    # Set up SSH configuration for easier private instance access
    mkdir -p /home/ec2-user/.ssh
    
    # Create an empty file to be filled by the user manually through SSM or other methods
    touch /home/ec2-user/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion}
    chmod 600 /home/ec2-user/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion}
    
    # Set up SSH config for private instances
    cat > /home/ec2-user/.ssh/config << 'SSHCONFIG'
    Host private-*
      User ec2-user
      IdentityFile ~/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion}
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
    SSHCONFIG
    
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh
    chmod 600 /home/ec2-user/.ssh/config
    
    # Create a key installation script
    cat > /home/ec2-user/setup_keys.sh << 'SETUP'
    #!/bin/bash
    # Script to configure private key from SSM parameter if available
    
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    KEY_PATH="/home/ec2-user/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion}"
    
    # Check if key parameter exists
    if aws ssm get-parameters --names "/clixx/private-key-content" --with-decryption --region $REGION --query "Parameters[0].Name" --output text 2>/dev/null; then
      echo "Found private key in SSM parameters. Installing..."
      aws ssm get-parameter --name "/clixx/private-key-content" --with-decryption --region $REGION --query "Parameter.Value" --output text > "$KEY_PATH"
      chmod 600 "$KEY_PATH"
      echo "Private key installed successfully."
    else
      echo "No private key found in SSM parameters. Please transfer it manually."
      echo "See README_SSH_KEYS.txt for instructions."
    fi
    SETUP
    
    chmod +x /home/ec2-user/setup_keys.sh
    chown ec2-user:ec2-user /home/ec2-user/setup_keys.sh
    
    # Run the setup script on first boot
    echo "/home/ec2-user/setup_keys.sh > /home/ec2-user/setup_keys.log 2>&1" >> /etc/rc.local
    chmod +x /etc/rc.local
    
    echo "Secondary bastion host setup complete!"
  EOF

  depends_on = [aws_instance.bastion, aws_security_group.bastion_sg]
}

# Add outputs for the secondary bastion
output "secondary_bastion_public_ip" {
  description = "Public IP of the secondary bastion host"
  value       = aws_instance.bastion_secondary.public_ip
}

output "secondary_bastion_public_dns" {
  description = "Public DNS of the secondary bastion host"
  value       = aws_instance.bastion_secondary.public_dns
}

output "secondary_bastion_ssh_command" {
  description = "Command to SSH into the secondary bastion host"
  value       = "ssh -i ${var.bastion_ssh_key_path} ec2-user@${aws_instance.bastion_secondary.public_dns}"
}

# Output showing both bastions for high availability
output "bastion_ha_status" {
  description = "High availability status for bastion hosts"
  value = {
    primary_az   = aws_instance.bastion.availability_zone
    secondary_az = aws_instance.bastion_secondary.availability_zone
    primary_ip   = aws_instance.bastion.public_ip
    secondary_ip = aws_instance.bastion_secondary.public_ip
  }
}
