# Bastion Host Configuration
# This implements the bastion host with key transfer functionality from the entire-vpc-spc module

# IAM Role and Policy for Bastion Host with SSM Access
resource "aws_iam_role" "bastion_role" {
  name = "clixx-bastion-role"

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
    Name = "clixx-bastion-role"
  })
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "bastion_ssm_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Add custom policy for additional permissions if needed
resource "aws_iam_role_policy" "bastion_custom_policy" {
  name = "clixx-bastion-custom-policy"
  role = aws_iam_role.bastion_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeAddresses"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Instance profile for the bastion host
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "clixx-bastion-profile"
  role = aws_iam_role.bastion_role.name

  tags = merge(var.common_tags, {
    Name = "clixx-bastion-profile"
  })
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "clixx-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  # SSH access from anywhere (consider restricting to specific IPs for production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
    description = "SSH access to bastion host"
  }

  # Allow HTTP for basic web access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access to bastion host"
  }
  
  # Allow HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access to bastion host"
  }

  # Outbound: Allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "clixx-bastion-sg"
  })
}

# Allow bastion hosts to communicate with each other
resource "aws_security_group_rule" "bastion_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
  description              = "Allow all TCP traffic between instances in this security group"
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = var.bastion_ami_id != "" ? var.bastion_ami_id : var.ec2_ami
  instance_type          = var.bastion_instance_type
  # Use the first public subnet (can be modified to use a different one if needed)
  subnet_id              = aws_subnet.public[0].id
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
    Name = "clixx-bastion-host"
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
    echo "<h1>Clixx Retail - Bastion Host</h1>" > /var/www/html/index.html
    echo "<p>This is the bastion host for Clixx Retail infrastructure.</p>" >> /var/www/html/index.html
    
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
    
    # Create directory for SQL scripts
    mkdir -p /home/ec2-user/sql_scripts
    
    # Create a test script to verify MySQL RDS connectivity
    cat > /home/ec2-user/sql_scripts/verify_mysql.sql << 'SQLSCRIPT'
    -- MySQL RDS Connection Test Script
    -- Run with: mysql -h [RDS_ENDPOINT] -u [USER] -p < verify_mysql.sql
    SHOW DATABASES;
    SELECT User, Host FROM mysql.user;
    SQLSCRIPT
    
    # Create a test script to verify Oracle connectivity
    cat > /home/ec2-user/sql_scripts/verify_oracle.sql << 'SQLSCRIPT'
    -- Oracle DB Connection Test Script
    -- Run with: sqlplus [USER]/[PASSWORD]@[ORACLE_ENDPOINT] @verify_oracle.sql
    SELECT username FROM dba_users;
    SELECT owner, table_name FROM all_tables WHERE rownum < 10;
    exit;
    SQLSCRIPT
    
    # Create a PHP script to connect to MySQL RDS
    cat > /var/www/html/verify_mysql.php << 'PHPSCRIPT'
    <?php
    // Get RDS endpoint from SSM
    $command = "aws ssm get-parameter --name '/clixx/RDS_ENDPOINT' --region " . shell_exec('curl -s http://169.254.169.254/latest/meta-data/placement/region') . " --query 'Parameter.Value' --output text";
    $endpoint = trim(shell_exec($command));
    
    // Get DB credentials from SSM
    $db_name_cmd = "aws ssm get-parameter --name '/clixx/db_name' --region " . shell_exec('curl -s http://169.254.169.254/latest/meta-data/placement/region') . " --query 'Parameter.Value' --output text";
    $db_name = trim(shell_exec($db_name_cmd));
    
    $db_user_cmd = "aws ssm get-parameter --name '/clixx/db_user' --region " . shell_exec('curl -s http://169.254.169.254/latest/meta-data/placement/region') . " --query 'Parameter.Value' --output text";
    $db_user = trim(shell_exec($db_user_cmd));
    
    echo "<h1>MySQL RDS Connection Test</h1>";
    echo "<p>Attempting to connect to MySQL RDS at: " . htmlspecialchars($endpoint) . "</p>";
    
    try {
        // Note: In production, you would get password from SSM parameter store securely
        // For this test, a manual password entry is required
        $conn = new mysqli($endpoint, $db_user, '[Enter password when prompted]', $db_name);
        
        if ($conn->connect_error) {
            die("<p>Connection failed: " . htmlspecialchars($conn->connect_error) . "</p>");
        }
        
        echo "<p>Connected successfully to MySQL RDS</p>";
        
        // List databases
        $result = $conn->query("SHOW DATABASES");
        if ($result) {
            echo "<h2>Databases:</h2><ul>";
            while($row = $result->fetch_array()) {
                echo "<li>" . htmlspecialchars($row[0]) . "</li>";
            }
            echo "</ul>";
        }
        
        // List users
        $result = $conn->query("SELECT User, Host FROM mysql.user");
        if ($result) {
            echo "<h2>MySQL Users:</h2><table border='1'><tr><th>User</th><th>Host</th></tr>";
            while($row = $result->fetch_assoc()) {
                echo "<tr><td>" . htmlspecialchars($row['User']) . "</td><td>" . htmlspecialchars($row['Host']) . "</td></tr>";
            }
            echo "</table>";
        }
        
        $conn->close();
    } catch (Exception $e) {
        echo "<p>Error: " . htmlspecialchars($e->getMessage()) . "</p>";
    }
    ?>
    PHPSCRIPT
    
    # Install PHP MySQL tools for database management
    yum install -y php-mysqlnd mysql
    
    # Set permissions for the files
    chown -R ec2-user:ec2-user /home/ec2-user/sql_scripts
    chmod 644 /home/ec2-user/sql_scripts/*.sql
    chmod 644 /var/www/html/*.php
    
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
    
    # Create a helpful README file with connection instructions
    cat > /home/ec2-user/README_SSH_KEYS.txt << 'README'
    CLIXX RETAIL SSH KEY TRANSFER INSTRUCTIONS
    ==========================================
    
    To complete the setup of your bastion host, you need to transfer your private SSH key file 
    for accessing private instances. Here are several methods to achieve this:
    
    Option 1: Use AWS Systems Manager Session Manager
    -------------------------------------------------
    1. Connect to this bastion host using AWS SSM Session Manager
    2. Use the AWS CLI to transfer your key:
       aws ssm start-session \
         --target ${aws_instance.bastion.id} \
         --document-name AWS-StartPortForwardingSession \
         --parameters "localPortNumber=8022,portNumber=22"
       
    3. In another terminal:
       scp -P 8022 -i ${var.bastion_ssh_key_path} ${var.private_instance_ssh_key_path} ec2-user@localhost:~/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion}
    
    Option 2: Transfer via SSM Document
    ----------------------------------
    1. Create an SSM parameter with your private key
       aws ssm put-parameter --name "/clixx/private-key-content" --type "SecureString" --value "$(cat ${var.private_instance_ssh_key_path})" --overwrite
    
    2. Then, on the bastion host, run:
       aws ssm get-parameter --name "/clixx/private-key-content" --with-decryption --query "Parameter.Value" --output text > ~/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion}
       chmod 600 ~/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion}
    
    Option 3: Use AWS EC2-Instance-Connect
    -------------------------------------
    AWS EC2-Instance-Connect can be used to push your SSH key to the instance temporarily.
    
    After transferring the key using any of these methods, verify permissions with:
    chmod 600 ~/.ssh/${var.private_instance_ssh_key_destination_filename_on_bastion}
    
    README
    
    # Create a script to retrieve parameters from SSM
    cat > /home/ec2-user/get_db_params.sh << 'PARAMSCRIPT'
    #!/bin/bash
    # Script to fetch database connection parameters from SSM
    
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    
    echo "Retrieving database connection parameters..."
    echo "--------------------------------------------"
    
    # Get RDS endpoint
    RDS_ENDPOINT=$(aws ssm get-parameter --name /clixx/RDS_ENDPOINT --region $REGION --query "Parameter.Value" --output text)
    echo "RDS Endpoint: $RDS_ENDPOINT"
    
    # Get database name
    DB_NAME=$(aws ssm get-parameter --name /clixx/db_name --region $REGION --query "Parameter.Value" --output text)
    echo "Database Name: $DB_NAME"
    
    # Get database user
    DB_USER=$(aws ssm get-parameter --name /clixx/db_user --region $REGION --query "Parameter.Value" --output text)
    echo "Database User: $DB_USER"
    
    echo
    echo "To connect to MySQL RDS:"
    echo "mysql -h $RDS_ENDPOINT -u $DB_USER -p $DB_NAME"
    echo
    echo "You'll be prompted to enter the database password."
    PARAMSCRIPT
    
    # Make the script executable
    chmod +x /home/ec2-user/get_db_params.sh
    chown ec2-user:ec2-user /home/ec2-user/get_db_params.sh
    chown ec2-user:ec2-user /home/ec2-user/README_SSH_KEYS.txt
    
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
    
    echo "Bastion host setup complete!"
  EOF

  depends_on = [aws_security_group.bastion_sg]
}

# Output the connection details
output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_public_dns" {
  description = "Public DNS of the bastion host"
  value       = aws_instance.bastion.public_dns
}

output "bastion_ssh_command" {
  description = "Command to SSH into the bastion host"
  value       = "ssh -i ${var.bastion_ssh_key_path} ec2-user@${aws_instance.bastion.public_dns}"
}

output "private_instance_ssh_via_bastion_command_instructions" {
  description = "Instructions for SSH to private instances via the bastion"
  value       = "1. First transfer your private key using instructions in the README_SSH_KEYS.txt file on the bastion host\n2. Then use: ssh -J ec2-user@${aws_instance.bastion.public_dns} ec2-user@PRIVATE_INSTANCE_IP"
}

output "ssh_key_transfer_command" {
  description = "Command to transfer the private key to the bastion via SSM Parameter Store"
  value       = "aws ssm put-parameter --name \"/clixx/private-key-content\" --type \"SecureString\" --value \"$(cat ${var.private_instance_ssh_key_path})\" --overwrite"
}
