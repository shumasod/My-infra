#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Update package index
sudo apt-get update

# Install Nginx
sudo apt-get install -y nginx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Install dependencies for Kong
sudo apt-get install -y apt-transport-https curl lsb-core

# Add Kong's official APT repository
echo "deb [trusted=yes] https://download.konghq.com/gateway-3.x-ubuntu-$(lsb_release -sc)/ default all" | sudo tee /etc/apt/sources.list.d/kong.list

# Update package index again
sudo apt-get update

# Install Kong
sudo apt-get install -y kong

# Generate Kong configuration file
sudo kong config init

# Start Kong
sudo kong start

# Create a directory for the API monitoring dashboard
sudo mkdir -p /var/www/api-monitoring/html

# Set the ownership and permissions for the dashboard directory
sudo chown -R $USER:$USER /var/www/api-monitoring/html
sudo chmod -R 755 /var/www/api-monitoring/html

# Create a sample index.html file
echo "<h1>API Monitoring Dashboard</h1>" | sudo tee /var/www/api-monitoring/html/index.html

# Create the Nginx configuration file for the API monitoring dashboard
sudo tee /etc/nginx/sites-available/api-monitoring << EOF
server {
    listen 80;
    listen [::]:80;
    root /var/www/api-monitoring/html;
    index index.html index.htm index.nginx-debian.html;
    server_name api-monitoring.example.com;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Enable the Nginx configuration for the API monitoring dashboard
sudo ln -s /etc/nginx/sites-available/api-monitoring /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Reload Nginx to apply the changes
sudo systemctl reload nginx

echo "Nginx server and API gateway monitoring setup complete!"
