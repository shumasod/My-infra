#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Update package index and install Nginx without prompts
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Create a directory for the website
sudo mkdir -p /var/www/example.com/html

# Set the ownership and permissions for the website directory
sudo chown -R www-data:www-data /var/www/example.com/html
sudo chmod -R 755 /var/www/example.com/html

# Create a sample index.html file
echo "<html><body><h1>Welcome to example.com!</h1></body></html>" | sudo tee /var/www/example.com/html/index.html

# Create the Nginx configuration file
sudo tee /etc/nginx/sites-available/example.com << EOF
server {
    listen 80;
    listen [::]:80;
    root /var/www/example.com/html;
    index index.html index.htm index.nginx-debian.html;
    server_name example.com www.example.com;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Enable the Nginx configuration
sudo ln -sf /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/

# Remove default Nginx configuration
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Reload Nginx to apply the changes
sudo systemctl reload nginx

echo "Nginx server setup complete!"
echo "You can now access your website at http://localhost or http://$(hostname -I | awk '{print $1}')"