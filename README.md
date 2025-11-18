# WordPress Docker Setup

## Table of Contents

- [Description](#description)
- [Installation](#installation)
- [Environment Setup](#environment-setup)
- [Usage](#usage)
- [Security Guidelines](#security-guidelines)
- [License](#license)
- [Contact](#contact)

## Description

This repository contains a Docker Compose configuration for running a WordPress installation with MySQL database. The setup provides a containerized environment that ensures data persistence, automatic container restart on failure, and isolated networking between services.

### Key Components

- **WordPress Service**: Latest WordPress image running on port 8080 (configurable)
- **MySQL Database Service**: MySQL 8.0 database with persistent volume storage
- **Docker Compose Configuration**: Orchestrates both services with health checks and dependency management
- **Environment Configuration**: Secure configuration via environment variables

### Purpose

This repository serves as a production-ready WordPress deployment template that follows DevSecOps best practices. It enables rapid deployment of WordPress instances with proper data persistence, security configurations, and container orchestration.

## Installation

### Prerequisites

- Docker Engine 20.10 or higher
- Docker Compose 2.0 or higher
- Git (for cloning the repository)

### Installation Steps

1. Clone the repository:
```bash
git clone <repository-url>
cd Wordpress
```

2. Copy the environment template:
```bash
cp .env.example .env
```

3. Edit `.env` and configure required variables:
   - Set `MYSQL_PASSWORD` and `MYSQL_ROOT_PASSWORD` with unique passwords
   - Adjust `WORDPRESS_PORT` if port 8080 is already in use

4. Start the services:
```bash
docker-compose up -d
```

5. Access WordPress:
   - Open browser and navigate to `http://YOUR_IP:8080`
   - Follow WordPress installation wizard
   - Configure admin credentials during setup

## Environment Setup

### Environment Variables

All configuration is managed through environment variables stored in `.env`. Refer to `.env.example` for placeholders and replicate the structure precisely.

#### Database Configuration

- `MYSQL_DATABASE`: Database name for WordPress (default: `wordpress`)
- `MYSQL_USER`: Database user for WordPress (default: `wordpress_user`)
- `MYSQL_PASSWORD`: Password for the WordPress database user (required)
- `MYSQL_ROOT_PASSWORD`: Root password for MySQL (required)

#### WordPress Configuration

- `WORDPRESS_PORT`: Host port mapping for WordPress (default: `8080`)
- `WORDPRESS_DEBUG`: Enable WordPress debug mode (default: `0`)
- `WORDPRESS_TABLE_PREFIX`: Database table prefix (default: `wp_`)

### Modifying Configuration

To change the WordPress port from 8080 to another port (e.g., 9000):

1. Edit `.env`:
```bash
WORDPRESS_PORT=9000
```

2. Restart services:
```bash
docker-compose down
docker-compose up -d
```

To enable WordPress debug mode:

1. Edit `.env`:
```bash
WORDPRESS_DEBUG=1
```

2. Restart WordPress service:
```bash
docker-compose restart wordpress
```

## Usage

### Service Management

Start services:
```bash
docker-compose up -d
```

Stop services:
```bash
docker-compose down
```

View logs:
```bash
docker-compose logs -f
```

Restart services:
```bash
docker-compose restart
```

### Data Persistence

Database and WordPress data are stored in Docker volumes:
- `db_data`: Contains MySQL database files
- `wordpress_data`: Contains WordPress installation and uploads

To backup data:
```bash
docker run --rm -v wordpress_db_data:/data -v $(pwd):/backup alpine tar czf /backup/db_backup.tar.gz /data
docker run --rm -v wordpress_wordpress_data:/data -v $(pwd):/backup alpine tar czf /backup/wp_backup.tar.gz /data
```

To restore from backup:
```bash
docker run --rm -v wordpress_db_data:/data -v $(pwd):/backup alpine tar xzf /backup/db_backup.tar.gz -C /
docker run --rm -v wordpress_wordpress_data:/data -v $(pwd):/backup alpine tar xzf /backup/wp_backup.tar.gz -C /
```

### Network Configuration

Both services operate in the `wordpress_network` bridge network, enabling secure communication between WordPress and MySQL containers without exposing the database to the host network.

### Deployment Scripts

The repository includes several deployment scripts for automated setup:

- **[`setup-on-vm.sh`](setup-on-vm.sh)**: Complete setup script to be executed directly on the Cloud VM. Installs Docker, Docker Compose, clones the repository, creates environment configuration, and starts the containers.

- **[`install-on-vm.sh`](install-on-vm.sh)**: Alternative installation script for direct execution on the VM. Similar functionality to `setup-on-vm.sh` with additional error handling.

- **[`deploy-to-vm.sh`](deploy-to-vm.sh)**: Remote deployment script that connects to the VM via SSH and executes the setup. Requires `VM_IP` and `VM_USER` environment variables:
  ```bash
  VM_IP=your.vm.ip VM_USER=username ./deploy-to-vm.sh
  ```

- **[`setup-cloud-vm.sh`](setup-cloud-vm.sh)**: Firewall configuration script for the Cloud VM. Configures firewall rules to allow access on port 8080 and verifies container status.

**Note**: All scripts use environment variables for sensitive information. Never hardcode IP addresses, passwords, or credentials in scripts.

### Firewall Configuration

Execute the hardened firewall routine only on Cloud VMs that require explicit ingress rules:
```bash
./setup-cloud-vm.sh
```
The script validates required environment variables, limits ingress to the configured `WORDPRESS_PORT`, and performs deterministic health checks to confirm container availability.

## Security Guidelines

### Environment Variables

- Never commit `.env` files to version control
- Use strong, unique passwords for database credentials
- Rotate passwords regularly in production environments
- Store sensitive credentials in secure secret management systems

### Best Practices

- Keep Docker images updated to latest versions
- Regularly review and update WordPress plugins and themes
- Implement firewall rules to restrict access to port 8080
- Use HTTPS in production (requires reverse proxy configuration)
- Enable WordPress security plugins for additional protection

### Security Notes

- Database is not exposed to host network
- WordPress communicates with database via internal Docker network
- Container restart policy ensures service availability
- Health checks monitor database connectivity

## License

This project is provided under the [MIT License](LICENSE.md).

## Contact

For security disclosures or operational inquiries contact:
- Email: tarik.sabanovic03@gmail.com


