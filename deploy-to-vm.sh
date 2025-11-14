#!/bin/bash

# Deployment script to be run on the Cloud VM
# This script sets up WordPress on the Cloud VM

set -euo pipefail

VM_IP="${VM_IP:-}"
VM_USER="${VM_USER:-}"
REPO_URL="https://github.com/ttariik/Wordpress.git"
BRANCH="feature/wordpress"

if [ -z "${VM_IP}" ] || [ -z "${VM_USER}" ]; then
    echo "ERROR: VM_IP and VM_USER environment variables must be set"
    echo "Usage: VM_IP=your.vm.ip VM_USER=username ./deploy-to-vm.sh"
    exit 1
fi

echo "Deploying WordPress to Cloud VM: ${VM_IP}"

# Check if we can connect
if ! ssh -o ConnectTimeout=5 ${VM_USER}@${VM_IP} "echo 'Connection test'" 2>/dev/null; then
    echo "ERROR: Cannot connect to ${VM_USER}@${VM_IP}"
    echo "Please ensure:"
    echo "1. Your SSH public key is added to the server's ~/.ssh/authorized_keys"
    echo "2. You can manually connect with: ssh ${VM_USER}@${VM_IP}"
    exit 1
fi

echo "Connection successful. Deploying..."

# Execute commands on remote server
ssh ${VM_USER}@${VM_IP} << 'ENDSSH'
set -euo pipefail

WORK_DIR="$HOME/wordpress"
echo "Working directory: ${WORK_DIR}"

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "Docker installed. You may need to log out and back in."
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Clone or update repository
if [ -d "${WORK_DIR}" ]; then
    echo "Updating existing repository..."
    cd "${WORK_DIR}"
    git fetch origin
    git checkout feature/wordpress
    git pull origin feature/wordpress
else
    echo "Cloning repository..."
    git clone https://github.com/ttariik/Wordpress.git "${WORK_DIR}"
    cd "${WORK_DIR}"
    git checkout feature/wordpress
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
    # Generate secure passwords
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    sed -i "s/YOUR_DATABASE_PASSWORD/${DB_PASSWORD}/" .env
    sed -i "s/YOUR_ROOT_PASSWORD/${ROOT_PASSWORD}/" .env
    echo "Generated passwords saved in .env file"
fi

# Stop existing containers
docker-compose down 2>/dev/null || true

# Start containers
echo "Starting WordPress containers..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 15

# Configure firewall
echo "Configuring firewall..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 8080/tcp
    sudo ufw reload
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
elif command -v iptables &> /dev/null; then
    sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
    if command -v netfilter-persistent &> /dev/null; then
        sudo netfilter-persistent save
    fi
fi

# Check container status
echo "Container status:"
docker-compose ps

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo ""
echo "=========================================="
echo "WordPress deployment complete!"
echo "WordPress is accessible at:"
echo "http://${PUBLIC_IP}:8080"
echo "=========================================="
ENDSSH

echo "Deployment complete!"

