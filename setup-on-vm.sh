#!/bin/bash

# WordPress Setup Script for Cloud VM
# Execute this script on the VM: bash setup-on-vm.sh

set -euo pipefail

WORK_DIR="$HOME/wordpress"
REPO_URL="https://github.com/ttariik/Wordpress.git"
BRANCH="feature/wordpress"
VM_IP="91.99.193.112"
WORDPRESS_PORT="8080"

echo "WordPress Setup for ${VM_IP}:${WORDPRESS_PORT}"
echo "=========================================="

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    sudo usermod -aG docker $USER
    rm /tmp/get-docker.sh
    echo "Docker installed. Run: newgrp docker"
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
    git pull origin ${BRANCH} || true
else
    echo "Cloning repository..."
    git clone ${REPO_URL} "${WORK_DIR}"
    cd "${WORK_DIR}"
    git checkout ${BRANCH}
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cat > .env << 'ENVEOF'
# WordPress Docker Environment Configuration
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress_user
MYSQL_PASSWORD=YOUR_DATABASE_PASSWORD
MYSQL_ROOT_PASSWORD=YOUR_ROOT_PASSWORD
WORDPRESS_PORT=8080
WORDPRESS_DEBUG=0
WORDPRESS_TABLE_PREFIX=wp_
ENVEOF
    
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
fi

# Stop existing containers
echo "Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Start containers
echo "Starting WordPress containers on port ${WORDPRESS_PORT}..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 15

# Configure firewall
echo "Configuring firewall for port ${WORDPRESS_PORT}..."
if command -v ufw &> /dev/null; then
    sudo ufw allow ${WORDPRESS_PORT}/tcp
    sudo ufw reload
    echo "UFW: Port ${WORDPRESS_PORT} opened"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port=${WORDPRESS_PORT}/tcp
    sudo firewall-cmd --reload
    echo "Firewalld: Port ${WORDPRESS_PORT} opened"
elif command -v iptables &> /dev/null; then
    sudo iptables -A INPUT -p tcp --dport ${WORDPRESS_PORT} -j ACCEPT
    if command -v netfilter-persistent &> /dev/null; then
        sudo netfilter-persistent save
    fi
    echo "iptables: Port ${WORDPRESS_PORT} opened"
else
    echo "Warning: No firewall detected. Please manually configure port ${WORDPRESS_PORT}."
fi

# Check container status
echo ""
echo "Container status:"
docker-compose ps

echo ""
echo "=========================================="
echo "WordPress setup complete!"
echo "=========================================="
echo "WordPress is accessible at:"
echo "http://${VM_IP}:${WORDPRESS_PORT}"
echo ""
echo "Next steps:"
echo "1. Open http://${VM_IP}:${WORDPRESS_PORT} in your browser"
echo "2. Follow the WordPress installation wizard"
echo "3. Configure your admin credentials"
echo "=========================================="

