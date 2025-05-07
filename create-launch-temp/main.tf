resource "aws_launch_template" "clixx_app" {
  name        = var.launch_template_name
  description = "Launch template for Clixx retail application"

  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    arn = var.instance_profile_arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.security_group_id]
    delete_on_termination       = true
  }

  # Use the bootstrap script as user data (base64 encoded)
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Bootstrap script from do-not-modify.sh
    # This script sets up the Clixx retail application
    
    set -e # Exit immediately if any command fails

    #####################################################################
    # CliXX Retail Application AWS Secrets Manager Deployment
    #####################################################################

    echo "Starting CliXX Retail Application EFS mount and bootstrap script using AWS Secrets Manager..."

    # Run as root check
    if [ $$(id -u) -ne 0 ]; then
        echo "This script must be run as root. Switching to sudo..."
        exec sudo bash "$$0" "$$@"
    fi

    # Define AWS Region early for Secrets Manager calls
    AWS_REGION="us-east-1"
    # Secret name as defined in sm-pol-role-setup.sh
    SECRET_NAME="clixx-app/sm-credentials"

    # 1. Update and install necessary packages
    echo "Updating packages and installing necessary dependencies..."
    yum update -y
    amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2

    # Install required packages
    echo "Installing Apache, MariaDB, PHP MySQL extension, Git and NFS utilities..."
    yum install -y httpd mariadb-server php-mysqlnd git nfs-utils

    # 2. Start and enable Apache
    echo "Starting and enabling Apache (httpd) service..."
    systemctl start httpd
    systemctl enable httpd
    systemctl is-enabled httpd

    # 3. EFS configuration - Fetch from Secrets Manager
    echo "Fetching EFS File System ID from AWS Secrets Manager..."
    yum install -y jq

    # Fetch credentials from Secrets Manager
    echo "Retrieving credentials from AWS Secrets Manager..."
    SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$$SECRET_NAME" --region "$$AWS_REGION" --query 'SecretString' --output text)

    # Check if secret retrieval was successful
    if [ -z "$$SECRET_VALUE" ]; then
        echo "ERROR: Failed to retrieve credentials from Secrets Manager secret $$SECRET_NAME"
        exit 1
    fi

    # Extract values from JSON
    FILE_SYSTEM_ID=$$(echo $$SECRET_VALUE | jq -r '.file_system_id')
    DB_NAME=$$(echo $$SECRET_VALUE | jq -r '.rds_dbname')
    DB_USER=$$(echo $$SECRET_VALUE | jq -r '.rds_username')
    DB_PASSWORD=$$(echo $$SECRET_VALUE | jq -r '.rds_password')
    DB_HOST=$$(echo $$SECRET_VALUE | jq -r '.rds_endpoint')
    LB_DNS_NAME=$$(echo $$SECRET_VALUE | jq -r '.load_balancer_dns')

    # Verify values
    if [ -z "$$FILE_SYSTEM_ID" ] || [ -z "$$DB_NAME" ] || [ -z "$$DB_USER" ] || [ -z "$$DB_PASSWORD" ] || [ -z "$$DB_HOST" ] || [ -z "$$LB_DNS_NAME" ]; then
        echo "ERROR: Failed to extract required credentials from AWS Secrets Manager"
        exit 1
    fi

    REGION="$$AWS_REGION"
    MOUNT_POINT=/var/www/html

    echo "Setting up EFS mount for Clixx app ($${FILE_SYSTEM_ID}) in $${REGION} at $${MOUNT_POINT}"
    echo "Using database: $$DB_NAME on host: $$DB_HOST with user: $$DB_USER"

    # 4. Create mount directory
    mkdir -p $${MOUNT_POINT}

    # 5. Set up user permissions
    echo "Configuring user permissions for /var/www..."
    usermod -a -G apache ec2-user
    chown -R ec2-user:apache /var/www
    chmod 2775 /var/www
    find /var/www -type d -exec chmod 2775 {} \;
    find /var/www -type f -exec chmod 0664 {} \;

    # 6. Backup current content
    if [ -d "$${MOUNT_POINT}" ] && [ "$$(ls -A $${MOUNT_POINT})" ]; then
        echo "Backing up existing content in $${MOUNT_POINT}..."
        BACKUP_DIR="/tmp/clixx_backup_$$(date +%Y%m%d%H%M%S)"
        mkdir -p $${BACKUP_DIR}
        cp -r $${MOUNT_POINT}/* $${BACKUP_DIR}/ 2>/dev/null || true
    fi

    # 7. Unmount if already mounted
    umount $${MOUNT_POINT} 2>/dev/null || true

    # 8. Mount the EFS filesystem
    echo "Mounting EFS filesystem for Clixx app..."
    mount -t nfs4 $${FILE_SYSTEM_ID}.efs.$${REGION}.amazonaws.com:/ $${MOUNT_POINT}

    # 9. Make mount persistent
    echo "Configuring persistent mount across reboots..."
    grep -v "$${FILE_SYSTEM_ID}" /etc/fstab > /etc/fstab.tmp 2>/dev/null || true
    mv /etc/fstab.tmp /etc/fstab 2>/dev/null || true
    echo "$${FILE_SYSTEM_ID}.efs.$${REGION}.amazonaws.com:/ $${MOUNT_POINT} nfs4 defaults 0 0" >> /etc/fstab

    # 10. Verify mount was successful
    echo "Verifying EFS mount status:"
    if ! df -h | grep -q "$${FILE_SYSTEM_ID}"; then
        echo "ERROR: EFS mount failed. Please check your configuration."
        exit 1
    fi
    df -h | grep -E "Filesystem|$${MOUNT_POINT}"

    # Wait for NFS mount to stabilize
    sleep 5

    # Clean existing contents
    rm -rf $${MOUNT_POINT}/*

    # 11. Clone Clixx repository
    echo "Cloning Clixx repository into $${MOUNT_POINT}..."
    git clone https://github.com/stackitgit/CliXX_Retail_Repository.git /tmp/clixx_repo
    cp -r /tmp/clixx_repo/* $${MOUNT_POINT}/
    cp -r /tmp/clixx_repo/.* $${MOUNT_POINT}/ 2>/dev/null || true
    rm -rf /tmp/clixx_repo

    # 12. Set permissions for application files
    echo "Setting permissions for application files..."
    if id apache &>/dev/null; then
        chown -R apache:apache $${MOUNT_POINT}
        find $${MOUNT_POINT} -type d -exec chmod 2775 {} \;
        find $${MOUNT_POINT} -type f -exec chmod 0664 {} \;
    else
        chown -R ec2-user:ec2-user $${MOUNT_POINT}
        find $${MOUNT_POINT} -type d -exec chmod 2775 {} \;
        find $${MOUNT_POINT} -type f -exec chmod 0664 {} \;
    fi

    # 13. Configure Apache
    echo "Configuring Apache..."
    sed -i 's/AllowOverride None/AllowOverride All/g' /etc/httpd/conf/httpd.conf
    rm -f /etc/httpd/conf.d/welcome.conf

    # 14. Configure TCP Keepalive
    echo "Applying TCP Keepalive settings..."
    /sbin/sysctl -w net.ipv4.tcp_keepalive_time=200 net.ipv4.tcp_keepalive_intvl=200 net.ipv4.tcp_keepalive_probes=5

    # 15. Update wp-config.php
    echo "Updating wp-config.php with database credentials..."
    WP_CONFIG_PATH="$${MOUNT_POINT}/wp-config.php"
    if [ -f "$$WP_CONFIG_PATH" ]; then
        sed -i "s/define( *'DB_NAME', *'[^']*' *);/define('DB_NAME', '$$DB_NAME');/" "$$WP_CONFIG_PATH"
        sed -i "s/define( *'DB_USER', *'[^']*' *);/define('DB_USER', '$$DB_USER');/" "$$WP_CONFIG_PATH"
        sed -i "s/define( *'DB_PASSWORD', *'[^']*' *);/define('DB_PASSWORD', '$$DB_PASSWORD');/" "$$WP_CONFIG_PATH"
        sed -i "s/define( *'DB_HOST', *'[^']*' *);/define('DB_HOST', '$$DB_HOST');/" "$$WP_CONFIG_PATH"
    else
        echo "Warning: $$WP_CONFIG_PATH not found. Database settings not updated."
    fi

    # 16. Get Public IP
    echo "Fetching public IP address..."
    PUBLIC_IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    if [[ -z "$$PUBLIC_IP" ]]; then
        PUBLIC_IP=$$(curl -s http://checkip.amazonaws.com)
    fi

    # 17. Update WordPress site URLs
    echo "Updating WordPress site URLs to use Load Balancer DNS: http://$${LB_DNS_NAME}..."
    if mysql -h "$$DB_HOST" -u "$$DB_USER" -p"$$DB_PASSWORD" "$$DB_NAME" -e "SELECT 1" &> /dev/null; then
        mysql -h "$$DB_HOST" -u "$$DB_USER" -p"$$DB_PASSWORD" "$$DB_NAME" <<MYSQL_EOF
    UPDATE wp_options SET option_value = 'http://$${LB_DNS_NAME}' WHERE option_name = 'siteurl';
    UPDATE wp_options SET option_value = 'http://$${LB_DNS_NAME}' WHERE option_name = 'home';
MYSQL_EOF
    else
        echo "Error: Could not connect to the database. Manual update of site URLs required."
    fi

    # 18. Restart Apache
    echo "Restarting Apache..."
    systemctl restart httpd

    echo "=========================================================="
    echo "CliXX Retail Application setup complete!"
    echo "EFS filesystem $${FILE_SYSTEM_ID} is mounted at $${MOUNT_POINT}"
    echo "Your site should be available via: http://$${PUBLIC_IP}"
    echo "Load Balancer DNS: http://$${LB_DNS_NAME}"
    echo "=========================================================="
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "Clixx-App-Instance"
      Environment = "Production"
      Application = "ClixxRetailApp"
      ManagedBy   = "Terraform"
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = var.launch_template_name
    Environment = "Production"
    Application = "ClixxRetailApp"
    ManagedBy   = "Terraform"
  }
}
