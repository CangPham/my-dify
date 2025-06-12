# Hướng Dẫn Deploy Dify Project Lên VPS với Docker Compose

## Tổng Quan
Tài liệu này hướng dẫn deploy toàn bộ project Dify (bao gồm API, Web, Dashboard tùy chỉnh) lên VPS sử dụng Docker Compose.

## Yêu Cầu Hệ Thống

### VPS Tối Thiểu
- **CPU**: >= 4 cores (khuyến nghị 8 cores)
- **RAM**: >= 8GB (khuyến nghị 16GB)
- **Storage**: >= 50GB SSD
- **OS**: Ubuntu 20.04/22.04 LTS hoặc CentOS 7/8

### Phần Mềm Cần Thiết
- Docker Engine >= 20.10
- Docker Compose >= 2.0
- Git
- Nginx (tùy chọn, cho reverse proxy)

## Bước 1: Chuẩn Bị VPS

### 1.1 Cập Nhật Hệ Thống
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

### 1.2 Cài Đặt Docker
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Khởi động lại session hoặc logout/login
newgrp docker

# Kiểm tra
docker --version
docker compose version
```

### 1.3 Cài Đặt Git và Các Công Cụ
```bash
sudo apt install -y git curl wget htop
```

## Bước 2: Clone và Chuẩn Bị Project

### 2.1 Clone Repository
```bash
cd /opt
sudo git clone https://github.com/your-username/dify.git
sudo chown -R $USER:$USER dify
cd dify
```

### 2.2 Tạo File Environment
```bash
cd docker
cp .env.example .env
```

### 2.3 Cấu Hình Environment Variables
Chỉnh sửa file `.env`:

```bash
nano .env
```

**Các biến quan trọng cần thay đổi:**

```env
# Domain và URL
CONSOLE_API_URL=https://your-domain.com/console/api
CONSOLE_WEB_URL=https://your-domain.com
SERVICE_API_URL=https://your-domain.com/api
APP_API_URL=https://your-domain.com/api
APP_WEB_URL=https://your-domain.com
FILES_URL=https://your-domain.com/files

# Security
SECRET_KEY=your-super-secret-key-here
INIT_PASSWORD=your-admin-password

# Database
DB_PASSWORD=your-strong-db-password
POSTGRES_PASSWORD=your-strong-db-password

# Redis
REDIS_PASSWORD=your-redis-password

# Nginx
NGINX_SERVER_NAME=your-domain.com
NGINX_HTTPS_ENABLED=true
NGINX_SSL_CERT_FILENAME=your-domain.crt
NGINX_SSL_CERT_KEY_FILENAME=your-domain.key

# Ports
EXPOSE_NGINX_PORT=80
EXPOSE_NGINX_SSL_PORT=443
```

## Bước 3: Cấu Hình SSL Certificate

### 3.1 Sử dụng Let's Encrypt (Khuyến nghị)
```bash
# Cài đặt Certbot
sudo apt install -y certbot

# Tạo certificate
sudo certbot certonly --standalone -d your-domain.com

# Copy certificates
sudo mkdir -p docker/nginx/ssl
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem docker/nginx/ssl/your-domain.crt
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem docker/nginx/ssl/your-domain.key
sudo chown -R $USER:$USER docker/nginx/ssl
```

### 3.2 Hoặc Sử dụng Self-signed Certificate (Development)
```bash
mkdir -p docker/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout docker/nginx/ssl/your-domain.key \
  -out docker/nginx/ssl/your-domain.crt \
  -subj "/C=VN/ST=HCM/L=HCM/O=YourOrg/CN=your-domain.com"
```

## Bước 4: Build và Deploy

### 4.1 Build Images
```bash
cd docker

# Build tất cả custom images
docker compose build --no-cache
```

### 4.2 Tạo Volumes và Networks
```bash
# Tạo thư mục volumes
mkdir -p volumes/{app/storage,db/data,redis/data,sandbox/{dependencies,conf},plugin_daemon}
mkdir -p volumes/{certbot/{conf,www,logs},weaviate,qdrant,pgvector/data}

# Set permissions
sudo chown -R 999:999 volumes/db/data
sudo chown -R 999:999 volumes/redis/data
```

### 4.3 Deploy Services
```bash
# Start database và redis trước
docker compose up -d db redis

# Đợi database khởi động
sleep 30

# Start tất cả services
docker compose up -d
```

## Bước 5: Kiểm Tra và Monitoring

### 5.1 Kiểm Tra Services
```bash
# Xem status
docker compose ps

# Xem logs
docker compose logs -f api
docker compose logs -f web
docker compose logs -f dashboard
docker compose logs -f nginx
```

### 5.2 Health Check
```bash
# Test API
curl -k https://your-domain.com/api/health

# Test Web
curl -k https://your-domain.com

# Test Dashboard
curl -k https://your-domain.com:8501
```

## Bước 6: Cấu Hình Firewall

### 6.1 UFW (Ubuntu)
```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8501/tcp  # Dashboard port
sudo ufw --force enable
```

### 6.2 Firewalld (CentOS)
```bash
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=8501/tcp
sudo firewall-cmd --reload
```

## Bước 7: Backup và Maintenance

### 7.1 Script Backup Database
Tạo file `backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
docker compose exec -T db pg_dump -U postgres dify > $BACKUP_DIR/dify_db_$DATE.sql

# Backup volumes
tar -czf $BACKUP_DIR/dify_volumes_$DATE.tar.gz volumes/

# Cleanup old backups (keep 7 days)
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

### 7.2 Cron Job cho Auto Backup
```bash
chmod +x backup.sh
crontab -e

# Thêm dòng sau (backup hàng ngày lúc 2:00 AM)
0 2 * * * /opt/dify/backup.sh >> /var/log/dify-backup.log 2>&1
```

## Bước 8: Monitoring và Logging

### 8.1 Setup Log Rotation
```bash
sudo nano /etc/logrotate.d/dify
```

Nội dung:
```
/opt/dify/docker/volumes/app/storage/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
```

### 8.2 Monitoring Script
Tạo file `monitor.sh`:

```bash
#!/bin/bash
cd /opt/dify/docker

# Check services
services=("api" "web" "dashboard" "db" "redis" "nginx")

for service in "${services[@]}"; do
    if ! docker compose ps $service | grep -q "Up"; then
        echo "$(date): $service is down, restarting..." >> /var/log/dify-monitor.log
        docker compose restart $service
    fi
done
```

## Troubleshooting

### Lỗi Thường Gặp

1. **Database Connection Error**
   ```bash
   # Kiểm tra database
   docker compose logs db
   docker compose exec db pg_isready -U postgres
   ```

2. **Permission Denied**
   ```bash
   # Fix permissions
   sudo chown -R $USER:$USER volumes/
   sudo chmod -R 755 volumes/
   ```

3. **Out of Memory**
   ```bash
   # Tăng swap
   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

4. **SSL Certificate Issues**
   ```bash
   # Renew Let's Encrypt
   sudo certbot renew
   # Copy new certs
   sudo cp /etc/letsencrypt/live/your-domain.com/* docker/nginx/ssl/
   docker compose restart nginx
   ```

## URLs Truy Cập

Sau khi deploy thành công:

- **Main Application**: https://your-domain.com
- **API Documentation**: https://your-domain.com/api/docs
- **Dashboard**: https://your-domain.com:8501
- **Admin Setup**: https://your-domain.com/install

## Bảo Mật Bổ Sung

### 1. Fail2Ban
```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 2. Automatic Updates
```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 3. SSH Hardening
```bash
sudo nano /etc/ssh/sshd_config
# Thay đổi:
# Port 2222
# PermitRootLogin no
# PasswordAuthentication no
sudo systemctl restart ssh
```

## Bước 9: Tối Ưu Hóa Performance

### 9.1 Docker Compose Override cho Production
Tạo file `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  api:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
    restart: unless-stopped

  web:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'
    restart: unless-stopped

  dashboard:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'
    restart: unless-stopped

  db:
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
        reservations:
          memory: 2G
          cpus: '1.0'
    restart: unless-stopped
    command: >
      postgres -c max_connections=200
               -c shared_buffers=256MB
               -c work_mem=8MB
               -c maintenance_work_mem=128MB
               -c effective_cache_size=8192MB
               -c checkpoint_completion_target=0.9
               -c wal_buffers=16MB
               -c default_statistics_target=100

  redis:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD:-difyai123456} --maxmemory 768mb --maxmemory-policy allkeys-lru
```

### 9.2 Sử dụng Production Config
```bash
# Deploy với production config
docker compose -f docker-compose.yaml -f docker-compose.prod.yml up -d
```

### 9.3 Nginx Optimization
Tạo file `nginx-custom.conf`:

```nginx
# /opt/dify/docker/nginx/nginx-custom.conf
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50M;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=web:10m rate=30r/s;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

## Bước 10: Monitoring và Alerting

### 10.1 Setup Prometheus + Grafana (Tùy chọn)
Tạo file `monitoring/docker-compose.monitoring.yml`:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
```

### 10.2 Health Check Script Nâng Cao
Tạo file `health-check.sh`:

```bash
#!/bin/bash

# Configuration
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"  # Optional
LOG_FILE="/var/log/dify-health.log"
DIFY_DIR="/opt/dify/docker"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

send_alert() {
    local message="$1"
    log_message "ALERT: $message"

    # Send to Slack (optional)
    if [ ! -z "$WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 Dify Alert: $message\"}" \
            $WEBHOOK_URL
    fi
}

check_service() {
    local service_name="$1"
    local container_name="$2"

    if docker compose -f $DIFY_DIR/docker-compose.yaml ps $service_name | grep -q "Up"; then
        echo -e "${GREEN}✓${NC} $service_name is running"
        return 0
    else
        echo -e "${RED}✗${NC} $service_name is down"
        send_alert "$service_name service is down"
        return 1
    fi
}

check_url() {
    local url="$1"
    local service_name="$2"
    local expected_code="${3:-200}"

    response_code=$(curl -s -o /dev/null -w "%{http_code}" -k "$url" --max-time 10)

    if [ "$response_code" = "$expected_code" ]; then
        echo -e "${GREEN}✓${NC} $service_name URL check passed ($response_code)"
        return 0
    else
        echo -e "${RED}✗${NC} $service_name URL check failed ($response_code)"
        send_alert "$service_name URL check failed with code $response_code"
        return 1
    fi
}

check_disk_space() {
    local threshold=80
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ "$usage" -lt "$threshold" ]; then
        echo -e "${GREEN}✓${NC} Disk usage: ${usage}%"
        return 0
    else
        echo -e "${RED}✗${NC} Disk usage: ${usage}% (threshold: ${threshold}%)"
        send_alert "High disk usage: ${usage}%"
        return 1
    fi
}

check_memory() {
    local threshold=80
    local usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')

    if [ "$usage" -lt "$threshold" ]; then
        echo -e "${GREEN}✓${NC} Memory usage: ${usage}%"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Memory usage: ${usage}% (threshold: ${threshold}%)"
        send_alert "High memory usage: ${usage}%"
        return 1
    fi
}

main() {
    log_message "Starting health check..."

    cd $DIFY_DIR

    # Check services
    services=("api" "web" "dashboard" "db" "redis" "nginx")
    failed_services=0

    for service in "${services[@]}"; do
        if ! check_service "$service"; then
            ((failed_services++))
        fi
    done

    # Check URLs (replace with your domain)
    urls=(
        "https://your-domain.com|Web"
        "https://your-domain.com/api/health|API"
        "https://your-domain.com:8501|Dashboard"
    )

    for url_info in "${urls[@]}"; do
        IFS='|' read -r url name <<< "$url_info"
        check_url "$url" "$name"
    done

    # Check system resources
    check_disk_space
    check_memory

    # Summary
    if [ $failed_services -eq 0 ]; then
        log_message "Health check completed successfully"
        exit 0
    else
        log_message "Health check completed with $failed_services failed services"
        exit 1
    fi
}

main "$@"
```

### 10.3 Setup Cron Jobs
```bash
chmod +x health-check.sh

# Crontab
crontab -e

# Health check every 5 minutes
*/5 * * * * /opt/dify/health-check.sh >> /var/log/dify-health.log 2>&1

# Daily backup at 2 AM
0 2 * * * /opt/dify/backup.sh >> /var/log/dify-backup.log 2>&1

# Weekly cleanup at 3 AM Sunday
0 3 * * 0 /opt/dify/cleanup.sh >> /var/log/dify-cleanup.log 2>&1
```

## Bước 11: Update và Maintenance

### 11.1 Update Script
Tạo file `update.sh`:

```bash
#!/bin/bash

DIFY_DIR="/opt/dify"
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Starting Dify update process..."

# Backup before update
echo "Creating backup..."
cd $DIFY_DIR/docker
docker compose exec -T db pg_dump -U postgres dify > $BACKUP_DIR/pre_update_$DATE.sql
tar -czf $BACKUP_DIR/volumes_pre_update_$DATE.tar.gz volumes/

# Pull latest code
echo "Pulling latest code..."
cd $DIFY_DIR
git stash
git pull origin main
git stash pop

# Rebuild images
echo "Rebuilding images..."
cd docker
docker compose build --no-cache

# Update containers
echo "Updating containers..."
docker compose down
docker compose up -d

# Wait for services to start
echo "Waiting for services to start..."
sleep 60

# Health check
echo "Running health check..."
if /opt/dify/health-check.sh; then
    echo "Update completed successfully!"
else
    echo "Update failed! Check logs and consider rollback."
    exit 1
fi
```

### 11.2 Rollback Script
Tạo file `rollback.sh`:

```bash
#!/bin/bash

BACKUP_DIR="/opt/backups"
DIFY_DIR="/opt/dify/docker"

if [ -z "$1" ]; then
    echo "Usage: $0 <backup_date>"
    echo "Available backups:"
    ls -la $BACKUP_DIR/pre_update_*.sql | awk '{print $9}' | sed 's/.*pre_update_//' | sed 's/.sql//'
    exit 1
fi

BACKUP_DATE="$1"

echo "Rolling back to backup: $BACKUP_DATE"

# Stop services
cd $DIFY_DIR
docker compose down

# Restore database
echo "Restoring database..."
docker compose up -d db redis
sleep 30
docker compose exec -T db psql -U postgres -c "DROP DATABASE IF EXISTS dify;"
docker compose exec -T db psql -U postgres -c "CREATE DATABASE dify;"
docker compose exec -T db psql -U postgres dify < $BACKUP_DIR/pre_update_$BACKUP_DATE.sql

# Restore volumes
echo "Restoring volumes..."
cd /opt/dify/docker
tar -xzf $BACKUP_DIR/volumes_pre_update_$BACKUP_DATE.tar.gz

# Start all services
docker compose up -d

echo "Rollback completed!"
```

---

**Lưu ý**:
- Thay thế `your-domain.com` bằng domain thực tế của bạn
- Cập nhật các thông tin bảo mật phù hợp
- Test kỹ trên môi trường staging trước khi deploy production
- Backup thường xuyên và test restore process
