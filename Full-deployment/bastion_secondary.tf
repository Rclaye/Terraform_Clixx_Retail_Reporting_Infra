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

  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    yum update -y
    
    # Install required software
    yum install -y httpd amazon-ssm-agent mysql php nmap-ncat jq git unzip
    
    # Start and enable services
    systemctl start httpd
    systemctl enable httpd
    systemctl start amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    
    # Create a simple welcome page
    echo "<h1>Clixx Retail - Secondary Bastion Host</h1>" > /var/www/html/index.html
    echo "<p>This is the secondary bastion host in AZ ${var.availability_zones[1]} for Clixx Retail infrastructure.</p>" >> /var/www/html/index.html
    
    # Install PHP MySQL tools for database management
    yum install -y php-mysqlnd
    
    # Set up SSH configuration for easier private instance access
    mkdir -p /home/ec2-user/.ssh
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
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.common_tags, {
    Name = "clixx-bastion-secondary"
  })

  # Wait for SSH to be ready and test connection before proceeding
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for secondary bastion instance to be available..."
      
      # Wait for instance to be running
      aws ec2 wait instance-running --instance-ids ${self.id} --region ${var.aws_region}
      echo "Instance is running, now testing SSH connectivity..."
      
      # Test SSH connectivity with retry logic
      SSH_READY=false
      for i in {1..30}; do
        echo "Testing SSH connection attempt $i/30..."
        if ssh -i "${var.bastion_ssh_key_path}" \
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
    EOT
  }

  # Copy private key only after SSH is confirmed working
  provisioner "local-exec" {
    command = <<EOT
      # Now that SSH is confirmed working, copy the private key to the secondary bastion
      echo "SSH connectivity confirmed, transferring private key..."
      if scp -i "${var.bastion_ssh_key_path}" \
             -o StrictHostKeyChecking=no \
             -o UserKnownHostsFile=/dev/null \
             "${var.private_instance_ssh_key_path}" \
             "ec2-user@${self.public_dns}:/home/ec2-user/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion}"; then
        
        # Set proper permissions on the private key
        ssh -i "${var.bastion_ssh_key_path}" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "ec2-user@${self.public_dns}" \
            "chmod 600 /home/ec2-user/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion} && echo 'Private key permissions set'"
        
        echo "Private key transfer to secondary bastion completed successfully"
      else
        echo "ERROR: Failed to transfer private key to secondary bastion"
        exit 1
      fi
    EOT
  }

  depends_on = [
    aws_instance.bastion,
    aws_security_group.bastion_sg,
    aws_ssm_parameter.rds_endpoint,  # Added to ensure SSM parameters exist before instance boots
    aws_iam_instance_profile.bastion_profile
  ]
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
