#!/bin/bash

# Update package index
sudo apt-get update

# Install Nginx
sudo apt-get install -y nginx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Create a directory for the website
sudo mkdir -p /var/www/example.com/html

# Set the ownership and permissions for the website directory
sudo chown -R $USER:$USER /var/www/example.com/html
sudo chmod -R 755 /var/www/example.com

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
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/

# Reload Nginx to apply the changes
sudo systemctl reload nginx

echo "Nginx server setup complete!"