#!/bin/bash
set -e

echo "Starting CliXX Retail Application deployment..."

# Config variables (injected by Terraform)
AWS_REGION="${AWS_REGION}"
MOUNT_POINT="${MOUNT_POINT}"

# Fetch settings from SSM Parameter Store
DB_NAME=$(aws ssm get-parameter --name "${SSM_PARAM_DB_NAME}" --with-decryption --output text --query Parameter.Value --region "$AWS_REGION")
DB_USER=$(aws ssm get-parameter --name "${SSM_PARAM_DB_USER}" --with-decryption --output text --query Parameter.Value --region "$AWS_REGION")
DB_PASSWORD=$(aws ssm get-parameter --name "${SSM_PARAM_DB_PASSWORD}" --with-decryption --output text --query Parameter.Value --region "$AWS_REGION")
FILE_SYSTEM_ID=$(aws ssm get-parameter --name "${SSM_PARAM_FILE_SYSTEM_ID}" --output text --query Parameter.Value --region "$AWS_REGION")
RDS_ENDPOINT=$(aws ssm get-parameter --name "${SSM_PARAM_RDS_ENDPOINT}" --output text --query Parameter.Value --region "$AWS_REGION")
LB_DNS_NAME=$(aws ssm get-parameter --name "${SSM_PARAM_LB_DNS_NAME}" --output text --query Parameter.Value --region "$AWS_REGION")

# Start services that should already be installed from AMI
systemctl start httpd
systemctl start mariadb

# Set up directories
mkdir -p $${MOUNT_POINT}
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www

# Mount EFS
mount -t nfs4 $${FILE_SYSTEM_ID}.efs.$${AWS_REGION}.amazonaws.com:/ $${MOUNT_POINT}
echo "$${FILE_SYSTEM_ID}.efs.$${AWS_REGION}.amazonaws.com:/ $${MOUNT_POINT} nfs4 defaults 0 0" >> /etc/fstab

# Clone Clixx application if not already present
if [ ! -f "$${MOUNT_POINT}/wp-config.php" ]; then
    git clone https://github.com/stackitgit/CliXX_Retail_Repository.git /tmp/clixx_repo
    cp -r /tmp/clixx_repo/* $${MOUNT_POINT}/
    rm -rf /tmp/clixx_repo
fi

# Set permissions
chown -R apache:apache $${MOUNT_POINT}
find $${MOUNT_POINT} -type d -exec chmod 2775 {} \;
find $${MOUNT_POINT} -type f -exec chmod 0664 {} \;

# Update wp-config.php with database credentials
WP_CONFIG_PATH="$${MOUNT_POINT}/wp-config.php"
if [ -f "$WP_CONFIG_PATH" ]; then
    sed -i "s/define( *'DB_NAME', *'[^']*' *);/define('DB_NAME', '$DB_NAME');/" "$WP_CONFIG_PATH"
    sed -i "s/define( *'DB_USER', *'[^']*' *);/define('DB_USER', '$DB_USER');/" "$WP_CONFIG_PATH"
    sed -i "s/define( *'DB_PASSWORD', *'[^']*' *);/define('DB_PASSWORD', '$DB_PASSWORD');/" "$WP_CONFIG_PATH"
    sed -i "s/define( *'DB_HOST', *'[^']*' *);/define('DB_HOST', '$RDS_ENDPOINT');/" "$WP_CONFIG_PATH"
fi

# Update WordPress URLs in database
mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<EOF
UPDATE wp_options SET option_value = "https://clixx.stack-claye.com" WHERE option_value LIKE '%ELB%';
EOF

# Restart Apache
systemctl restart httpd

echo "CliXX Retail Application deployment complete!"
echo "Website URL: https://clixx.stack-claye.com"
