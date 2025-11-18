#!/bin/bash

# WordPress Installation Script
# Run this script directly on the Cloud VM
# Execute: bash install-on-vm.sh

set -euo pipefail

WORK_DIR="$HOME/wordpress"
REPO_URL="https://github.com/ttariik/Wordpress.git"
BRANCH="feature/wordpress"

echo "WordPress Installation Script for Cloud VM"
echo "=========================================="

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "Docker installed. You may need to log out and back in for group changes to take effect."
    echo "Or run: newgrp docker"
    exit 0
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose --version
fi

# Clone or update repository
if [ -d "${WORK_DIR}" ]; then
    echo "Updating existing repository..."
    cd "${WORK_DIR}"
    git fetch origin
    git checkout ${BRANCH} 2>/dev/null || git checkout -b ${BRANCH} origin/${BRANCH}
    git pull origin ${BRANCH}
else
    echo "Cloning repository..."
    git clone ${REPO_URL} "${WORK_DIR}"
    cd "${WORK_DIR}"
    git checkout ${BRANCH}
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
    # Generate secure passwords
    if command -v openssl &> /dev/null; then
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    else
        DB_PASSWORD=$(date +%s | sha256sum | base64 | head -c 25)
        ROOT_PASSWORD=$(date +%s | sha256sum | base64 | head -c 25)
    fi
    sed -i "s/YOUR_DATABASE_PASSWORD/${DB_PASSWORD}/" .env
    sed -i "s/YOUR_ROOT_PASSWORD/${ROOT_PASSWORD}/" .env
    echo "Generated passwords saved in .env file"
    echo "Database Password: ${DB_PASSWORD}"
    echo "Root Password: ${ROOT_PASSWORD}"
fi

# Stop existing containers
echo "Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Start containers
echo "Starting WordPress containers..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 15

# Configure firewall
echo "Configuring firewall for port 8080..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 8080/tcp
    sudo ufw reload
    echo "UFW: Port 8080 opened"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
    echo "Firewalld: Port 8080 opened"
elif command -v iptables &> /dev/null; then
    sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
    if command -v netfilter-persistent &> /dev/null; then
        sudo netfilter-persistent save
    elif [ -f /etc/redhat-release ]; then
        sudo service iptables save
    fi
    echo "iptables: Port 8080 opened"
else
    echo "Warning: No firewall detected. Please manually configure port 8080."
fi

# Check container status
echo ""
echo "Container status:"
docker-compose ps

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "YOUR_VM_IP")

echo ""
echo "=========================================="
echo "WordPress installation complete!"
echo "=========================================="
echo "WordPress is accessible at:"
echo "http://${PUBLIC_IP}:8080"
echo ""
echo "Next steps:"
echo "1. Open http://${PUBLIC_IP}:8080 in your browser"
echo "2. Follow the WordPress installation wizard"
echo "3. Configure your admin credentials"
echo "=========================================="

