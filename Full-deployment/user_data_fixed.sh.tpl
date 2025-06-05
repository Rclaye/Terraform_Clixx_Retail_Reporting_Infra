#!/bin/bash
set -e

# CliXX Retail Application deployment script
echo "Starting CliXX Retail Application deployment..."

# ensure we’re root
[ "$(id -u)" -ne 0 ] && exec sudo bash "$0" "$@"

# Config variables (injected by Terraform)
AWS_REGION="${AWS_REGION}"
MOUNT_POINT=/var/www/html
WP_CONFIG_PATH="$${MOUNT_POINT}/wp-config.php" 

# --- fetch all settings from SSM Parameter Store ---
DB_NAME=$(aws ssm get-parameter --name "${SSM_PARAM_DB_NAME}" --with-decryption --output text --query Parameter.Value --region "$AWS_REGION")
DB_USER=$(aws ssm get-parameter --name "${SSM_PARAM_DB_USER}" --with-decryption --output text --query Parameter.Value --region "$AWS_REGION")
DB_PASSWORD=$(aws ssm get-parameter --name "${SSM_PARAM_DB_PASSWORD}" --with-decryption --output text --query Parameter.Value --region "$AWS_REGION")
FILE_SYSTEM_ID=$(aws ssm get-parameter --name "${SSM_PARAM_FILE_SYSTEM_ID}" --output text --query Parameter.Value --region "$AWS_REGION")
LB_DNS_NAME=$(aws ssm get-parameter --name "${SSM_PARAM_LB_DNS_NAME}" --output text --query Parameter.Value --region "$AWS_REGION")
HOSTED_ZONE_RECORD_NAME=$(aws ssm get-parameter --name "${SSM_PARAM_HOSTED_ZONE_RECORD_NAME}" --output text --query Parameter.Value --region "$AWS_REGION")
WP_ADMIN_USER=$(aws ssm get-parameter --name "${SSM_PARAM_WP_ADMIN_USER}" --with-decryption --output text --query Parameter.Value --region "$AWS_REGION")
WP_ADMIN_PASSWORD=$(aws ssm get-parameter --name "${SSM_PARAM_WP_ADMIN_PASSWORD}" --with-decryption --output text --query Parameter.Value --region "$AWS_REGION")
WP_ADMIN_EMAIL=$(aws ssm get-parameter --name "${SSM_PARAM_WP_ADMIN_EMAIL}" --output text --query Parameter.Value --region "$AWS_REGION")

# --- fetch RDS endpoint from SSM and map to DB_HOST ---
RDS_ENDPOINT=$(aws ssm get-parameter \
  --name "${SSM_PARAM_RDS_ENDPOINT}" \
  --output text --query Parameter.Value \
  --region "$AWS_REGION")
DB_HOST="$RDS_ENDPOINT"

# Function to set up EBS volumes with LVM
setup_ebs_volumes() {
    # Check if LVM tools are available, install if missing
    yum install -y lvm2 || { echo "Warning: Could not install lvm2, but continuing anyway"; }
    
    # No-fail check - if LVM already exists, continue
    lvs | grep -q "stack_vg" && { echo "LVM already exists. Skipping."; return 0; }
    
    # No-fail check - Verify any disks exist before proceeding
    DISKS=(sdb sdc sdd sde sdf)
    DISKS_FOUND=0
    
    for disk in "$${DISKS[@]}"; do
        [ -e "/dev/$disk" ] && DISKS_FOUND=1
    done
    
    # If no disks found, log and return success anyway
    if [ $DISKS_FOUND -eq 0 ]; then
        echo "No EBS volumes found to configure for LVM. Continuing deployment without EBS storage."
        return 0
    fi
    
    # Create partitions on disks
    for disk in "$${DISKS[@]}"; do
        [ -e "/dev/$disk" ] && ! [ -e "/dev/$${disk}1" ] && {
            echo -e "n\np\n1\n\n\nw" | fdisk "/dev/$disk" || echo "Warning: Partitioning /dev/$disk failed, but continuing"
            sleep 2
        }
    done
    
    # Create physical volumes - with no-fail option
    for disk in "$${DISKS[@]}"; do
        [ -e "/dev/$${disk}1" ] && pvcreate "/dev/$${disk}1" 2>/dev/null || true
    done
    
    # Create volume group - with no-fail checking
    if ! vgs | grep -q "stack_vg"; then
        DISK_PARTS=""
        for disk in "$${DISKS[@]}"; do
            [ -e "/dev/$${disk}1" ] && DISK_PARTS+="/dev/$${disk}1 "
        done
        
        if [ -n "$DISK_PARTS" ]; then
            vgcreate stack_vg $DISK_PARTS || { 
                echo "Warning: Volume group creation failed, but continuing deployment" 
                return 0
            }
        else
            echo "No partitions available for volume group. Continuing without LVM."
            return 0
        fi
    fi
    
    # Check if volume group exists before attempting to create logical volumes
    if ! vgs | grep -q "stack_vg"; then
        echo "Volume group does not exist. Continuing without logical volumes."
        return 0
    fi
    
    # Create and format logical volumes - with no-fail conditions
    # Using individual variables instead of associative array 
    LV_NAMES=("Lv_u01" "Lv_u02" "Lv_u03" "Lv_u04")
    LV_SIZES=("8" "5" "5" "5")
    
    for i in {0..3}; do
        lv_name="$${LV_NAMES[$i]}"
        lv_size="$${LV_SIZES[$i]}"
        
        if ! lvs | grep -q "$lv_name"; then
            lvcreate -L $${lv_size}G -n "$lv_name" stack_vg || {
                echo "Warning: Failed to create logical volume $lv_name, but continuing"
                continue
            }
            mkfs.ext4 "/dev/stack_vg/$lv_name" 2>/dev/null || echo "Warning: Failed to format $lv_name, but continuing"
        fi
        
        # Mount directories - with no-fail conditions
        mount_point="/$${lv_name#Lv_}"
        lv_path="/dev/stack_vg/$lv_name"
        mkdir -p "$mount_point" || echo "Warning: Failed to create mountpoint $mount_point, but continuing"
        
        # Only attempt to mount if logical volume exists
        if [ -e "$lv_path" ]; then
            mount | grep -q "$mount_point" || mount "$lv_path" "$mount_point" || echo "Warning: Failed to mount $lv_path, but continuing"
            grep -q "$lv_path" /etc/fstab || echo "$lv_path $mount_point ext4 defaults 0 2" >> /etc/fstab
        else
            echo "Logical volume $lv_path does not exist. Skipping mount."
        fi
    done
    
    echo "EBS volume setup completed with no-fail policy - deployment will continue regardless of EBS status"
}

# Install packages
yum update -y
amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
yum install -y httpd mariadb-server php-mysqlnd git nfs-utils 

# Set up EBS volumes
setup_ebs_volumes

# Start Apache
systemctl start httpd
systemctl enable httpd

# Install WordPress CLI
echo "Installing WP-CLI..."
cd /tmp
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Verify WP-CLI installation
echo "Verifying WP-CLI installation..."
if ! wp --info > /dev/null 2>&1; then
    echo "WP-CLI installation failed. Trying with full path..."
    if ! /usr/local/bin/wp --info > /dev/null 2>&1; then
        echo "ERROR: WP-CLI installation verification failed. This may cause WordPress setup to fail."
    fi
fi

# Set up WP-CLI for Apache user
echo "Setting up WP-CLI for Apache user..."
mkdir -p /var/www/.wp-cli/cache
chown -R apache:apache /var/www/.wp-cli
chmod -R 755 /var/www/.wp-cli

echo "Verifying WordPress CLI as apache user (using MOUNT_POINT: $${MOUNT_POINT})..."
sudo -u apache /usr/local/bin/wp --info || echo "Warning: WP-CLI basic info check as apache user failed."

# Set up directories
mkdir -p $${MOUNT_POINT}
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \; 2>/dev/null || true
find /var/www -type f -exec chmod 0664 {} \; 2>/dev/null || true

# Back up and unmount if needed
[ -d "$${MOUNT_POINT}" ] && [ "$(ls -A $${MOUNT_POINT})" ] && {
    BACKUP_DIR="/tmp/clixx_backup_$(date +%Y%m%d%H%M%S)"
    mkdir -p $${BACKUP_DIR}
    cp -r $${MOUNT_POINT}/* $${BACKUP_DIR}/ 2>/dev/null || true
}
umount $${MOUNT_POINT} 2>/dev/null || true

# Mount EFS
mount -t nfs4 $${FILE_SYSTEM_ID}.efs.$${AWS_REGION}.amazonaws.com:/ $${MOUNT_POINT}

# Replace with more robust mounting logic with retry mechanism
mount -t nfs4 $${FILE_SYSTEM_ID}.efs.$${AWS_REGION}.amazonaws.com:/ $${MOUNT_POINT} || {
  echo "Initial EFS mount attempt failed, waiting and trying again..."
  
  # Create a function for mount attempts with debugging
  attempt_mount() {
    echo "Checking network connectivity to EFS endpoint..."
    ping -c 3 $${FILE_SYSTEM_ID}.efs.$${AWS_REGION}.amazonaws.com || echo "Cannot ping EFS endpoint - this is normal if ICMP is blocked"
    
    echo "Checking for port 2049 connectivity..."
    nc -zv $${FILE_SYSTEM_ID}.efs.$${AWS_REGION}.amazonaws.com 2049 || echo "Port check failed"
    
    echo "Attempting EFS mount with verbose output..."
    mount -v -t nfs4 $${FILE_SYSTEM_ID}.efs.$${AWS_REGION}.amazonaws.com:/ $${MOUNT_POINT}
    return $?
  }
  
  # Try several times with increasing delays
  for retry in 1 2 3 4 5; do
    echo "Mount attempt $retry..."
    sleep $((retry * 10))
    attempt_mount && {
      echo "Mount successful on attempt $retry!"
      break
    }
    
    if [ $retry -eq 5 ]; then
      echo "All mount attempts failed. Creating a local directory for application functionality..."
      mkdir -p $${MOUNT_POINT}
      chown -R apache:apache $${MOUNT_POINT} 2>/dev/null || true
      echo "EFS mount failure - continuing with local storage. Check security groups, routes, and IAM permissions."
    fi
  done
}

# Update fstab more safely
grep -v "$${FILE_SYSTEM_ID}" /etc/fstab > /etc/fstab.tmp 2>/dev/null || true
mv /etc/fstab.tmp /etc/fstab 2>/dev/null || true
echo "$${FILE_SYSTEM_ID}.efs.$${AWS_REGION}.amazonaws.com:/ $${MOUNT_POINT} nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" >> /etc/fstab

# Improved verification
if df -h | grep -q "$${FILE_SYSTEM_ID}"; then
  echo "EFS mount successful!"
else
  echo "WARNING: EFS mount verification failed, but continuing the deployment using local storage"
fi

# Clone repository
git clone https://github.com/stackitgit/CliXX_Retail_Repository.git /tmp/clixx_repo
cp -r /tmp/clixx_repo/* $${MOUNT_POINT}/
cp -r /tmp/clixx_repo/.* $${MOUNT_POINT}/ 2>/dev/null || true
rm -rf /tmp/clixx_repo

# Set permissions
if id apache &>/dev/null; then
    chown -R apache:apache $${MOUNT_POINT} 2>/dev/null || true
    find $${MOUNT_POINT} -type d -exec chmod 2775 {} \; 2>/dev/null || true
    find $${MOUNT_POINT} -type f -exec chmod 0664 {} \; 2>/dev/null || true
else
    chown -R ec2-user:ec2-user $${MOUNT_POINT} 2>/dev/null || true
fi

# Configure Apache
sed -i 's/AllowOverride None/AllowOverride All/g' /etc/httpd/conf/httpd.conf
rm -f /etc/httpd/conf.d/welcome.conf
/sbin/sysctl -w net.ipv4.tcp_keepalive_time=200 net.ipv4.tcp_keepalive_intvl=200 net.ipv4.tcp_keepalive_probes=5

# Update wp-config.php with database credentials
if [ -f "$WP_CONFIG_PATH" ]; then
    sed -i "s/define( *'DB_NAME', *'[^']*' *);/define('DB_NAME', '$DB_NAME');/" "$WP_CONFIG_PATH"
    sed -i "s/define( *'DB_USER', *'[^']*' *);/define('DB_USER', '$DB_USER');/" "$WP_CONFIG_PATH"
    sed -i "s/define( *'DB_PASSWORD', *'[^']*' *);/define('DB_PASSWORD', '$DB_PASSWORD');/" "$WP_CONFIG_PATH"
    sed -i "s/define( *'DB_HOST', *'[^']*' *);/define('DB_HOST', '$DB_HOST');/" "$WP_CONFIG_PATH"

    # Add HTTPS settings for ALB/LB environment if not already present
    if ! grep -q "FORCE_SSL_ADMIN" "$WP_CONFIG_PATH"; then
        sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i define('FORCE_SSL_ADMIN', true);\ndefine('FORCE_SSL_LOGIN', true);\nif (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) \&\& \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {\n    \$_SERVER['HTTPS'] = 'on';\n}\n" "$WP_CONFIG_PATH"
    fi
fi

# Create health check file for ALB
cat > $${MOUNT_POINT}/health.php << 'HEALTH'
<?php
// Simple health check file that returns 200 OK
header("Content-Type: text/plain");
echo "OK";
?>
HEALTH

# Set ownership of the health check file
chown apache:apache $${MOUNT_POINT}/health.php
chmod 644 $${MOUNT_POINT}/health.php

# Update WordPress URLs in database
# Get private IP (for logging purposes only)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# We'll use MySQL directly instead of WP-CLI to set site URLs
echo "Updating WordPress site URLs using MySQL..."

echo "Attempting to connect to database..."
if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" &> /dev/null; then
    echo "Successfully connected to database $DB_NAME on $DB_HOST."
    
    # Update WordPress URLs directly in the database using the ALB DNS name
    echo "Updating WordPress URLs to use ALB DNS: $LB_DNS_NAME"
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<EOF
USE $DB_NAME;
-- Update site URL 
UPDATE wp_options SET option_value = "https://clixx.stack-claye.com" WHERE option_value LIKE '%ELB%';
-- Print URLS 
SELECT option_name, option_value FROM wp_options WHERE option_name LIKE '%http%';
EOF
    echo "WordPress URLs updated successfully in database."
else
    echo "Could not connect to database $DB_NAME on $DB_HOST. Check credentials, RDS security group, and EC2 instance outbound rules."
    echo "DB_HOST: $DB_HOST, DB_USER: $DB_USER, DB_NAME: $DB_NAME"
fi

# Restart Apache
systemctl restart httpd || (yum install -y httpd && systemctl start httpd && systemctl enable httpd)

# Verify WordPress installation
if [ ! -f "$${MOUNT_POINT}/wp-config.php" ]; then
    git clone https://github.com/stackitgit/CliXX_Retail_Repository.git /tmp/clixx_recovery
    [ -d "/tmp/clixx_recovery" ] && {
        cp -r /tmp/clixx_recovery/* $${MOUNT_POINT}/ 2>/dev/null || true
        cp -r /tmp/clixx_recovery/.* $${MOUNT_POINT}/ 2>/dev/null || true
        rm -rf /tmp/clixx_recovery
    }
fi

echo "========================================================="
echo "CliXX Retail Application deployment complete!"
echo "EFS filesystem $${FILE_SYSTEM_ID} mounted at $${MOUNT_POINT}"
echo "Private IP: $${PRIVATE_IP}"
echo "Website URL: https://clixx.stack-claye.com"
echo "=========================================================="
exit 0