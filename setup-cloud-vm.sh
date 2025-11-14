#!/bin/bash

# WordPress Cloud VM Setup Script
# This script configures firewall rules and ensures WordPress is accessible on port 8080

set -euo pipefail

echo "Configuring firewall for WordPress on port 8080..."

# Detect firewall type and configure accordingly
if command -v ufw &> /dev/null; then
    echo "Detected UFW firewall"
    sudo ufw allow 8080/tcp
    sudo ufw reload
    echo "UFW: Port 8080 opened"
elif command -v firewall-cmd &> /dev/null; then
    echo "Detected firewalld"
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
    echo "Firewalld: Port 8080 opened"
elif command -v iptables &> /dev/null; then
    echo "Detected iptables"
    sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
    # Save iptables rules (distribution-specific)
    if command -v netfilter-persistent &> /dev/null; then
        sudo netfilter-persistent save
    elif [ -f /etc/redhat-release ]; then
        sudo service iptables save
    fi
    echo "iptables: Port 8080 opened"
else
    echo "Warning: No firewall detected. Please manually configure port 8080."
fi

# Verify Docker is running
if ! docker ps &> /dev/null; then
    echo "Error: Docker is not running or not accessible"
    exit 1
fi

# Check if containers are running
if docker-compose ps | grep -q "wordpress_app.*Up"; then
    echo "WordPress containers are running"
    echo "WordPress should be accessible at: http://$(curl -s ifconfig.me || hostname -I | awk '{print $1}'):8080"
else
    echo "Starting WordPress containers..."
    docker-compose up -d
    echo "Waiting for services to start..."
    sleep 10
    echo "WordPress should be accessible at: http://$(curl -s ifconfig.me || hostname -I | awk '{print $1}'):8080"
fi

echo "Setup complete!"

