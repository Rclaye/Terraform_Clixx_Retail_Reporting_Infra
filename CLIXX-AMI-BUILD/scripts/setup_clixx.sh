#!/bin/bash
set -x

# Update system
sudo yum update -y

# Install necessary dependencies for Clixx application
sudo yum install -y httpd mariadb-server php php-mysqlnd git nfs-utils
sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2

# Install AWS Inspector Agent
sudo wget https://inspector-agent.amazonaws.com/linux/latest/install
sudo curl -O https://inspector-agent.amazonaws.com/linux/latest/install
sudo bash install

# Setup sudo to allow no-password sudo for "clixx" group and adding "clixx" user
sudo groupadd -r clixx
sudo useradd -m -s /bin/bash clixx
sudo usermod -a -G clixx clixx
sudo cp /etc/sudoers /etc/sudoers.orig
echo "clixx  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/clixx

# Installing SSH key
sudo mkdir -p /home/clixx/.ssh
sudo chmod 700 /home/clixx/.ssh
sudo cp /tmp/clixx-packer.pub /home/clixx/.ssh/authorized_keys
sudo chmod 600 /home/clixx/.ssh/authorized_keys
sudo chown -R clixx /home/clixx/.ssh
sudo usermod --shell /bin/bash clixx

# Install WordPress CLI
cd /tmp
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Set up Apache
sudo systemctl enable httpd
sudo systemctl enable mariadb

# Create application directories
sudo mkdir -p /var/www/html
sudo chown -R apache:apache /var/www/html
sudo chmod -R 755 /var/www/html

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Set up LVM tools for EBS volume management
sudo yum install -y lvm2

# Configure Apache for WordPress
sudo sed -i 's/AllowOverride None/AllowOverride All/g' /etc/httpd/conf/httpd.conf

echo "Clixx AMI setup completed successfully"
