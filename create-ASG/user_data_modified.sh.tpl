#!/bin/bash
set -e

# CliXX Retail Application deployment script
echo "Starting CliXX Retail Application deployment..."

# Run as root check
[ $(id -u) -ne 0 ] && exec sudo bash "$0" "$@"

# Config variables
AWS_REGION="us-east-1"
SECRET_NAME="clixx-app/sm-credentials"
MOUNT_POINT=/var/www/html

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
    # Using individual variables instead of associative array for Terraform compatibility
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
yum install -y httpd mariadb-server php-mysqlnd git nfs-utils jq

# Set up EBS volumes
setup_ebs_volumes

# Start Apache
systemctl start httpd
systemctl enable httpd

# Get credentials from Secrets Manager
SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$AWS_REGION" --query 'SecretString' --output text)
[ -z "$SECRET_VALUE" ] && { echo "Failed to retrieve credentials"; exit 1; }

# Extract values from JSON
FILE_SYSTEM_ID=$(echo $SECRET_VALUE | jq -r '.file_system_id')
DB_NAME=$(echo $SECRET_VALUE | jq -r '.rds_dbname')
DB_USER=$(echo $SECRET_VALUE | jq -r '.rds_username')
DB_PASSWORD=$(echo $SECRET_VALUE | jq -r '.rds_password')
DB_HOST=$(echo $SECRET_VALUE | jq -r '.rds_endpoint')
LB_DNS_NAME=$(echo $SECRET_VALUE | jq -r '.load_balancer_dns')
HOSTED_ZONE_NAME=$(echo $SECRET_VALUE | jq -r '.hosted_zone_name')
HOSTED_ZONE_RECORD_NAME=$(echo $SECRET_VALUE | jq -r '.hosted_zone_record_name')

# Verify values
if [ -z "$FILE_SYSTEM_ID" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_HOST" ] || [ -z "$LB_DNS_NAME" ]; then
    echo "Failed to extract credentials, exiting"
    exit 1
fi

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
grep -v "$${FILE_SYSTEM_ID}" /etc/fstab > /etc/fstab.tmp 2>/dev/null || true
mv /etc/fstab.tmp /etc/fstab 2>/dev/null || true
echo "$${FILE_SYSTEM_ID}.efs.$${AWS_REGION}.amazonaws.com:/ $${MOUNT_POINT} nfs4 defaults 0 0" >> /etc/fstab

# Verify mount
df -h | grep -q "$${FILE_SYSTEM_ID}" || { echo "EFS mount failed"; exit 1; }
sleep 3
rm -rf $${MOUNT_POINT}/*

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

# Update wp-config.php
WP_CONFIG_PATH="$${MOUNT_POINT}/wp-config.php"
if [ -f "$WP_CONFIG_PATH" ]; then
    sed -i "s/define( *'DB_NAME', *'[^']*' *);/define('DB_NAME', '$DB_NAME');/" "$WP_CONFIG_PATH"
    sed -i "s/define( *'DB_USER', *'[^']*' *);/define('DB_USER', '$DB_USER');/" "$WP_CONFIG_PATH"
    sed -i "s/define( *'DB_PASSWORD', *'[^']*' *);/define('DB_PASSWORD', '$DB_PASSWORD');/" "$WP_CONFIG_PATH"
    sed -i "s/define( *'DB_HOST', *'[^']*' *);/define('DB_HOST', '$DB_HOST');/" "$WP_CONFIG_PATH"
    
    # Add HTTPS settings
    if ! grep -q "FORCE_SSL_ADMIN" "$WP_CONFIG_PATH"; then
        sed -i "/That's all, stop editing/i\\define('FORCE_SSL_ADMIN', true);\\ndefine('FORCE_SSL_LOGIN', true);\\n\\$_SERVER['HTTPS'] = 'on';\\n" "$WP_CONFIG_PATH"
    fi
fi

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || curl -s http://checkip.amazonaws.com)

# Update WordPress URLs in database
if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" &> /dev/null; then
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<EOF
USE $DB_NAME;
-- Update core URLs
UPDATE wp_options SET option_value = 'https://$${HOSTED_ZONE_RECORD_NAME}' WHERE option_name IN ('siteurl','home');

-- Fix content URLs
UPDATE wp_posts SET 
    guid = REPLACE(REPLACE(guid, 'http://$${PUBLIC_IP}', 'https://$${HOSTED_ZONE_RECORD_NAME}'), 'http://$${HOSTED_ZONE_RECORD_NAME}', 'https://$${HOSTED_ZONE_RECORD_NAME}'),
    post_content = REPLACE(REPLACE(post_content, 'http://$${PUBLIC_IP}', 'https://$${HOSTED_ZONE_RECORD_NAME}'), 'http://$${HOSTED_ZONE_RECORD_NAME}', 'https://$${HOSTED_ZONE_RECORD_NAME}');

-- Fix meta values
UPDATE wp_postmeta SET meta_value = REPLACE(REPLACE(meta_value, 'http://$${PUBLIC_IP}', 'https://$${HOSTED_ZONE_RECORD_NAME}'), 'http://$${HOSTED_ZONE_RECORD_NAME}', 'https://$${HOSTED_ZONE_RECORD_NAME}') 
WHERE meta_value LIKE '%http://%';

-- Fix options with URLs
UPDATE wp_options SET option_value = REPLACE(REPLACE(option_value, 'http://$${PUBLIC_IP}', 'https://$${HOSTED_ZONE_RECORD_NAME}'), 'http://$${HOSTED_ZONE_RECORD_NAME}', 'https://$${HOSTED_ZONE_RECORD_NAME}')
WHERE option_name LIKE '%url%' OR option_name LIKE '%permalink%' OR option_name LIKE '%links%' OR option_name IN ('_transient_doing_cron', 'widget_text', 'widget_custom_html', 'theme_mods_open-shop');
EOF
else
    echo "Could not connect to database. Check credentials."
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

echo "=========================================================="
echo "CliXX Retail Application deployment complete!"
echo "EFS filesystem $${FILE_SYSTEM_ID} mounted at $${MOUNT_POINT}"
echo "Site available at: https://$${HOSTED_ZONE_RECORD_NAME}"
echo "=========================================================="
exit 0