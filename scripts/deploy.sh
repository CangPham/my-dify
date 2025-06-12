#!/bin/bash

# Dify VPS Deployment Script
# Usage: ./deploy.sh [domain] [email]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN=${1:-"localhost"}
EMAIL=${2:-"admin@example.com"}
DIFY_DIR="/opt/dify"
BACKUP_DIR="/opt/backups"

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "           DIFY VPS DEPLOYMENT SCRIPT"
    echo "=================================================="
    echo -e "${NC}"
    echo "Domain: $DOMAIN"
    echo "Email: $EMAIL"
    echo "Install Directory: $DIFY_DIR"
    echo ""
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
    fi
}

check_system() {
    log "Checking system requirements..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS version"
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "debian" ]] && [[ "$ID" != "centos" ]] && [[ "$ID" != "rhel" ]]; then
        warn "Unsupported OS: $ID. Continuing anyway..."
    fi
    
    # Check memory
    MEMORY_GB=$(free -g | awk 'NR==2{print $2}')
    if [[ $MEMORY_GB -lt 4 ]]; then
        warn "System has only ${MEMORY_GB}GB RAM. Minimum 8GB recommended."
    fi
    
    # Check disk space
    DISK_GB=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $DISK_GB -lt 20 ]]; then
        error "Insufficient disk space. Need at least 50GB free."
    fi
    
    log "System check passed"
}

install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker already installed"
        return
    fi
    
    log "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    
    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    
    log "Docker installation completed"
}

setup_directories() {
    log "Setting up directories..."
    
    sudo mkdir -p $DIFY_DIR $BACKUP_DIR
    sudo chown -R $USER:$USER $DIFY_DIR $BACKUP_DIR
    
    # Create log directory
    sudo mkdir -p /var/log/dify
    sudo chown -R $USER:$USER /var/log/dify
}

clone_repository() {
    log "Cloning Dify repository..."
    
    if [[ -d "$DIFY_DIR/.git" ]]; then
        log "Repository already exists, pulling latest changes..."
        cd $DIFY_DIR
        git pull origin main
    else
        git clone https://github.com/langgenius/dify.git $DIFY_DIR
        cd $DIFY_DIR
    fi
}

setup_ssl() {
    log "Setting up SSL certificates..."
    
    if [[ "$DOMAIN" == "localhost" ]]; then
        log "Using self-signed certificate for localhost..."
        mkdir -p docker/nginx/ssl
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout docker/nginx/ssl/dify.key \
            -out docker/nginx/ssl/dify.crt \
            -subj "/C=VN/ST=HCM/L=HCM/O=Dify/CN=localhost"
        return
    fi
    
    # Install certbot
    if ! command -v certbot &> /dev/null; then
        log "Installing Certbot..."
        if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
            sudo apt update
            sudo apt install -y certbot
        elif [[ "$ID" == "centos" ]] || [[ "$ID" == "rhel" ]]; then
            sudo yum install -y certbot
        fi
    fi
    
    # Get certificate
    log "Obtaining SSL certificate for $DOMAIN..."
    sudo certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
    
    # Copy certificates
    mkdir -p docker/nginx/ssl
    sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem docker/nginx/ssl/dify.crt
    sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem docker/nginx/ssl/dify.key
    sudo chown -R $USER:$USER docker/nginx/ssl
}

configure_environment() {
    log "Configuring environment variables..."
    
    cd docker
    cp .env.example .env
    
    # Generate secure keys
    SECRET_KEY=$(openssl rand -base64 42)
    DB_PASSWORD=$(openssl rand -base64 32)
    REDIS_PASSWORD=$(openssl rand -base64 32)
    
    # Update .env file
    sed -i "s|SECRET_KEY=.*|SECRET_KEY=$SECRET_KEY|g" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|g" .env
    sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$DB_PASSWORD|g" .env
    sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|g" .env
    
    if [[ "$DOMAIN" != "localhost" ]]; then
        sed -i "s|CONSOLE_API_URL=.*|CONSOLE_API_URL=https://$DOMAIN/console/api|g" .env
        sed -i "s|CONSOLE_WEB_URL=.*|CONSOLE_WEB_URL=https://$DOMAIN|g" .env
        sed -i "s|SERVICE_API_URL=.*|SERVICE_API_URL=https://$DOMAIN/api|g" .env
        sed -i "s|APP_API_URL=.*|APP_API_URL=https://$DOMAIN/api|g" .env
        sed -i "s|APP_WEB_URL=.*|APP_WEB_URL=https://$DOMAIN|g" .env
        sed -i "s|FILES_URL=.*|FILES_URL=https://$DOMAIN/files|g" .env
        sed -i "s|NGINX_SERVER_NAME=.*|NGINX_SERVER_NAME=$DOMAIN|g" .env
        sed -i "s|NGINX_HTTPS_ENABLED=.*|NGINX_HTTPS_ENABLED=true|g" .env
    fi
    
    log "Environment configuration completed"
}

setup_volumes() {
    log "Setting up Docker volumes..."
    
    mkdir -p volumes/{app/storage,db/data,redis/data,sandbox/{dependencies,conf},plugin_daemon}
    mkdir -p volumes/{certbot/{conf,www,logs},weaviate,qdrant,pgvector/data}
    
    # Set proper permissions
    sudo chown -R 999:999 volumes/db/data volumes/redis/data
    chmod -R 755 volumes/
}

deploy_services() {
    log "Building and deploying services..."
    
    # Build images
    docker compose build --no-cache
    
    # Start database and redis first
    docker compose up -d db redis
    
    log "Waiting for database to initialize..."
    sleep 30
    
    # Start all services
    docker compose up -d
    
    log "Waiting for all services to start..."
    sleep 60
}

setup_firewall() {
    log "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow 22/tcp
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw allow 8501/tcp
        sudo ufw --force enable
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=22/tcp
        sudo firewall-cmd --permanent --add-port=80/tcp
        sudo firewall-cmd --permanent --add-port=443/tcp
        sudo firewall-cmd --permanent --add-port=8501/tcp
        sudo firewall-cmd --reload
    else
        warn "No firewall detected. Please configure manually."
    fi
}

setup_monitoring() {
    log "Setting up monitoring scripts..."
    
    # Copy monitoring scripts
    cp ../scripts/*.sh /opt/dify/
    chmod +x /opt/dify/*.sh
    
    # Setup cron jobs
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/dify/health-check.sh >> /var/log/dify/health.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/dify/backup.sh >> /var/log/dify/backup.log 2>&1") | crontab -
}

verify_deployment() {
    log "Verifying deployment..."
    
    # Check services
    if ! docker compose ps | grep -q "Up"; then
        error "Some services are not running"
    fi
    
    # Test URLs
    local base_url="http://localhost"
    if [[ "$DOMAIN" != "localhost" ]]; then
        base_url="https://$DOMAIN"
    fi
    
    sleep 30  # Wait for services to fully start
    
    if curl -f -s "$base_url" > /dev/null; then
        log "Web interface is accessible"
    else
        warn "Web interface may not be ready yet"
    fi
    
    if curl -f -s "$base_url/api/health" > /dev/null; then
        log "API is accessible"
    else
        warn "API may not be ready yet"
    fi
}

print_summary() {
    echo -e "${GREEN}"
    echo "=================================================="
    echo "           DEPLOYMENT COMPLETED!"
    echo "=================================================="
    echo -e "${NC}"
    
    local base_url="http://localhost"
    if [[ "$DOMAIN" != "localhost" ]]; then
        base_url="https://$DOMAIN"
    fi
    
    echo "🌐 Web Interface: $base_url"
    echo "📊 Dashboard: $base_url:8501"
    echo "🔧 API Docs: $base_url/api/docs"
    echo "⚙️  Setup: $base_url/install"
    echo ""
    echo "📁 Installation Directory: $DIFY_DIR"
    echo "💾 Backup Directory: $BACKUP_DIR"
    echo "📋 Logs: /var/log/dify/"
    echo ""
    echo "🔧 Management Commands:"
    echo "  - View logs: cd $DIFY_DIR/docker && docker compose logs -f"
    echo "  - Restart: cd $DIFY_DIR/docker && docker compose restart"
    echo "  - Update: /opt/dify/update.sh"
    echo "  - Backup: /opt/dify/backup.sh"
    echo "  - Health check: /opt/dify/health-check.sh"
    echo ""
    echo "⚠️  Important: Please change default passwords after first login!"
}

main() {
    print_header
    
    check_root
    check_system
    install_docker
    setup_directories
    clone_repository
    setup_ssl
    configure_environment
    setup_volumes
    deploy_services
    setup_firewall
    setup_monitoring
    verify_deployment
    
    print_summary
    
    log "Deployment completed successfully!"
}

# Run main function
main "$@"
