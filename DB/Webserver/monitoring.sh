#!/bin/bash
set -e

# Configuration
INSTALL_DIR="/opt/api-monitor"
RSS_DATA_DIR="$INSTALL_DIR/rss_data"
URLS_FILE="$INSTALL_DIR/rss_urls.txt"
LOG_DIR="$INSTALL_DIR/logs"
CONFIG_DIR="$INSTALL_DIR/config"

# Create necessary directories
setup_directories() {
    echo "Creating directories..."
    sudo mkdir -p "$INSTALL_DIR" "$RSS_DATA_DIR" "$LOG_DIR" "$CONFIG_DIR"
    sudo chown -R $USER:$USER "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
}

# Install system dependencies
install_dependencies() {
    echo "Installing dependencies..."
    sudo apt-get update
    sudo apt-get install -y nginx curl xmlstarlet apache2-utils jq \
        apt-transport-https lsb-core
}

# Setup Kong
setup_kong() {
    echo "Setting up Kong..."
    echo "deb [trusted=yes] https://download.konghq.com/gateway-3.x-ubuntu-$(lsb_release -sc)/ default all" | \
        sudo tee /etc/apt/sources.list.d/kong.list
    sudo apt-get update
    sudo apt-get install -y kong
    sudo kong config init
    sudo kong start
}

# Create RSS collector script
create_rss_collector() {
    local collector_script="$INSTALL_DIR/rss_collector.sh"
    
    echo "Creating RSS collector script..."
    cat > "$collector_script" << 'EOF'
#!/bin/bash
set -euo pipefail

INSTALL_DIR="/opt/api-monitor"
RSS_DATA_DIR="$INSTALL_DIR/rss_data"
URLS_FILE="$INSTALL_DIR/rss_urls.txt"
LOG_FILE="$INSTALL_DIR/logs/rss_collector.log"
KEYWORD="${1:-""}"
INTERVAL="${2:-300}"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# RSS feed fetching and parsing
fetch_and_parse_rss() {
    local url="$1"
    curl -sS --max-time 30 "$url" 2>/dev/null | xmlstarlet format 2>/dev/null
}

# Filter items by keyword
filter_items() {
    local content="$1"
    local keyword="$2"
    if [ -z "$keyword" ]; then
        echo "$content"
    else
        echo "$content" | xmlstarlet sel -t -c "//item[contains(translate(title,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'), 
            '$(echo "$keyword" | tr '[:upper:]' '[:lower:]')')]"
    fi
}

# Process RSS items
process_items() {
    local content="$1"
    local url="$2"
    
    echo "$content" | xmlstarlet sel -t -m "//item" -v "concat(title,'|',link,'|',pubDate)" -n | \
    while IFS='|' read -r title link date; do
        local hash=$(echo "$link" | sha256sum | cut -d' ' -f1)
        local hash_file="$RSS_DATA_DIR/$hash"
        
        if [ ! -f "$hash_file" ]; then
            log "New item from $url:"
            log "Title: $title"
            log "Link: $link"
            log "Date: $date"
            log "---"
            echo "$link" > "$hash_file"
            
            # Send to monitoring dashboard (can be extended)
            curl -s -X POST http://localhost:8001/services \
                -d "name=rss-$hash" \
                -d "url=$link" >/dev/null 2>&1 || true
        fi
    done
}

# Main monitoring loop
main() {
    log "Starting RSS monitoring..."
    log "Keyword filter: ${KEYWORD:-none}"
    log "Check interval: $INTERVAL seconds"
    
    while true; do
        while IFS= read -r url || [ -n "$url" ]; do
            [[ "$url" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$url" ]] && continue
            
            log "Checking feed: $url"
            content=$(fetch_and_parse_rss "$url")
            if [ -n "$content" ]; then
                filtered_content=$(filter_items "$content" "$KEYWORD")
                process_items "$filtered_content" "$url"
            else
                log "Warning: Failed to fetch feed from $url"
            fi
        done < "$URLS_FILE"
        
        sleep "$INTERVAL"
    done
}

main
EOF

    chmod +x "$collector_script"
}

# Setup Nginx configuration
setup_nginx() {
    echo "Configuring Nginx..."
    
    # Create dashboard HTML
    sudo mkdir -p /var/www/api-monitoring/html
    sudo chown -R $USER:$USER /var/www/api-monitoring/html
    
    cat > /var/www/api-monitoring/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>API Monitoring Dashboard</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 2em; }
        .feed-item { border: 1px solid #ddd; margin: 1em 0; padding: 1em; }
    </style>
</head>
<body>
    <h1>API Monitoring Dashboard</h1>
    <div id="feed-items"></div>
    <script>
        function updateDashboard() {
            fetch('/api/feeds')
                .then(response => response.json())
                .then(data => {
                    const container = document.getElementById('feed-items');
                    container.innerHTML = data.map(item => `
                        <div class="feed-item">
                            <h3>${item.title}</h3>
                            <p>Date: ${item.date}</p>
                            <p><a href="${item.link}" target="_blank">Read more</a></p>
                        </div>
                    `).join('');
                });
        }
        setInterval(updateDashboard, 60000);
        updateDashboard();
    </script>
</body>
</html>
EOF

    # Create Nginx site configuration
    sudo tee /etc/nginx/sites-available/api-monitoring << EOF
server {
    listen 80;
    listen [::]:80;
    root /var/www/api-monitoring/html;
    index index.html;
    server_name api-monitoring.example.com;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /api/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    sudo ln -s /etc/nginx/sites-available/api-monitoring /etc/nginx/sites-enabled/ 2>/dev/null || true
    sudo nginx -t
    sudo systemctl reload nginx
}

# Create systemd service
create_service() {
    echo "Creating systemd service..."
    
    sudo tee /etc/systemd/system/rss-collector.service << EOF
[Unit]
Description=RSS Feed Collector and Monitor
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$INSTALL_DIR/rss_collector.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable rss-collector
    sudo systemctl start rss-collector
}

# Setup initial RSS URLs
setup_initial_urls() {
    echo "Setting up initial RSS URLs..."
    cat > "$URLS_FILE" << EOF
# Add your RSS feed URLs below (one per line)
# Example:
# https://example.com/feed.xml
EOF
}

# Main installation process
main() {
    echo "Starting installation..."
    
    setup_directories
    install_dependencies
    setup_kong
    create_rss_collector
    setup_nginx
    setup_initial_urls
    create_service
    
    echo "Installation complete!"
    echo "Please add your RSS feed URLs to: $URLS_FILE"
    echo "Monitor logs at: $LOG_DIR/rss_collector.log"
    echo "Access dashboard at: http://api-monitoring.example.com"
}

main
