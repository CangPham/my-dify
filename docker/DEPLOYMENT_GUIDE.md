# Hướng Dẫn Triển Khai Dify trên VPS với Docker Compose

## Tổng Quan

Hướng dẫn này sẽ giúp bạn triển khai toàn bộ dự án Dify trên VPS chỉ bằng cách copy thư mục `docker` và sử dụng Docker Compose với các images từ DockerHub.

## 1. Yêu cầu Hệ Thống

### Phần Cứng Tối Thiểu
- **CPU**: 4 cores (khuyến nghị 8 cores)
- **RAM**: 8GB (khuyến nghị 16GB)
- **Ổ cứng**: 50GB SSD (khuyến nghị 100GB)
- **Băng thông**: 100Mbps

### Phần Mềm
- **Hệ điều hành**: Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- **Docker**: 24.0.0+
- **Docker Compose**: 2.20.0+

## 2. Chuẩn Bị VPS

### 2.1 Cập Nhật Hệ Thống

```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

### 2.2 Cài Đặt Docker

#### Ubuntu/Debian:
```bash
# Gỡ bỏ phiên bản cũ
sudo apt-get remove docker docker-engine docker.io containerd runc

# Cài đặt dependencies
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg lsb-release

# Thêm Docker GPG key
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Thêm repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Cài đặt Docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Khởi động Docker
sudo systemctl start docker
sudo systemctl enable docker

# Thêm user vào group docker
sudo usermod -aG docker $USER
```

#### CentOS/RHEL:
```bash
# Cài đặt yum-utils
sudo yum install -y yum-utils

# Thêm Docker repository
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Cài đặt Docker
sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Khởi động Docker
sudo systemctl start docker
sudo systemctl enable docker

# Thêm user vào group docker
sudo usermod -aG docker $USER
```

### 2.3 Kiểm Tra Cài Đặt

```bash
# Kiểm tra Docker version
docker --version

# Kiểm tra Docker Compose version
docker compose version

# Test Docker
docker run hello-world
```

### 2.4 Cấu Hình Firewall

```bash
# Ubuntu/Debian (UFW)
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 8501/tcp    # Dashboard (tùy chọn)
sudo ufw enable

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=8501/tcp
sudo firewall-cmd --reload
```

### 2.5 Tối Ưu Hệ Thống

```bash
# Tăng file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Tối ưu kernel parameters
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "net.core.somaxconn=65535" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## 3. Cấu Hình

### 3.1 Upload Thư Mục Docker

```bash
# Tạo thư mục cho dự án
mkdir -p /opt/dify
cd /opt/dify

# Upload thư mục docker từ local machine
# Sử dụng scp, rsync hoặc git clone
scp -r ./docker user@your-vps-ip:/opt/dify/

# Hoặc nếu có git repository
git clone https://github.com/your-repo/dify.git
cd dify
```

### 3.2 Cấu Hình Environment Variables

```bash
cd /opt/dify/docker

# Copy file .env.example thành .env
cp .env.example .env

# Chỉnh sửa file .env
nano .env
```

### 3.3 Các Biến Môi Trường Quan Trọng Cần Cấu Hình

```bash
# === URLs Configuration ===
CONSOLE_API_URL=http://your-domain.com
CONSOLE_WEB_URL=http://your-domain.com
SERVICE_API_URL=http://your-domain.com
APP_API_URL=http://your-domain.com
APP_WEB_URL=http://your-domain.com
FILES_URL=http://your-domain.com

# === Security ===
SECRET_KEY=your-secret-key-here
INIT_PASSWORD=your-admin-password

# === Database ===
DB_USERNAME=postgres
DB_PASSWORD=your-strong-db-password
DB_HOST=db
DB_PORT=5432
DB_DATABASE=dify

# === Redis ===
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your-strong-redis-password

# === Vector Store (chọn một) ===
VECTOR_STORE=weaviate
# VECTOR_STORE=qdrant
# VECTOR_STORE=pgvector

# === Nginx ===
NGINX_PORT=80
NGINX_SSL_PORT=443
EXPOSE_NGINX_PORT=80
EXPOSE_NGINX_SSL_PORT=443

# === SSL (nếu sử dụng HTTPS) ===
NGINX_HTTPS_ENABLED=false
NGINX_SSL_CERT_FILENAME=dify.crt
NGINX_SSL_CERT_KEY_FILENAME=dify.key
```

### 3.4 Cấu Hình Vector Database Chi Tiết

#### Weaviate (Khuyến nghị cho production)
```bash
VECTOR_STORE=weaviate
WEAVIATE_ENDPOINT=http://weaviate:8080
WEAVIATE_API_KEY=WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih
```

#### Qdrant (Tốt cho performance cao)
```bash
VECTOR_STORE=qdrant
QDRANT_URL=http://qdrant:6333
QDRANT_API_KEY=difyai123456
QDRANT_CLIENT_TIMEOUT=20
```

#### PGVector (Tích hợp với PostgreSQL)
```bash
VECTOR_STORE=pgvector
PGVECTOR_HOST=pgvector
PGVECTOR_PORT=5432
PGVECTOR_USER=postgres
PGVECTOR_PASSWORD=difyai123456
PGVECTOR_DATABASE=dify
```

### 3.5 Cấu Hình Production-Ready

```bash
# === Performance ===
SERVER_WORKER_AMOUNT=4
CELERY_WORKER_AMOUNT=2
GUNICORN_TIMEOUT=600

# === Logging ===
LOG_LEVEL=INFO
LOG_FILE=/app/logs/server.log
LOG_FILE_MAX_SIZE=50
LOG_FILE_BACKUP_COUNT=10

# === Security ===
DEBUG=false
FLASK_DEBUG=false
DEPLOY_ENV=PRODUCTION

# === Database Optimization ===
SQLALCHEMY_POOL_SIZE=50
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=512MB
POSTGRES_WORK_MEM=8MB
POSTGRES_EFFECTIVE_CACHE_SIZE=8192MB
```

### 3.6 Tạo Secret Key

```bash
# Tạo secret key mạnh
openssl rand -base64 42
```

### 3.7 Cấu Hình Cloud Storage (Tùy chọn)

#### AWS S3
```bash
STORAGE_TYPE=s3
S3_ENDPOINT=https://s3.amazonaws.com
S3_REGION=us-east-1
S3_BUCKET_NAME=your-dify-bucket
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
```

#### Azure Blob Storage
```bash
STORAGE_TYPE=azure-blob
AZURE_BLOB_ACCOUNT_NAME=your-account
AZURE_BLOB_ACCOUNT_KEY=your-key
AZURE_BLOB_CONTAINER_NAME=dify-container
```

### 3.8 Security Best Practices

```bash
# Thay đổi default passwords
DB_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 42)

# Giới hạn CORS
WEB_API_CORS_ALLOW_ORIGINS=https://your-domain.com
CONSOLE_CORS_ALLOW_ORIGINS=https://your-domain.com

# Disable debug mode
DEBUG=false
FLASK_DEBUG=false
```

## 4. Triển Khai

### 4.1 Tạo Thư Mục Volumes

```bash
cd /opt/dify/docker

# Tạo các thư mục cần thiết
sudo mkdir -p volumes/{app/storage,db/data,redis/data,sandbox,plugin_daemon,certbot/{conf,www,logs}}
sudo mkdir -p volumes/{weaviate,qdrant,pgvector/data,chroma,nginx/ssl}

# Phân quyền
sudo chown -R $USER:$USER volumes/
sudo chmod -R 755 volumes/
```

### 4.2 Pull Docker Images

```bash
# Pull tất cả images cần thiết
docker compose pull
```

### 4.3 Khởi Động Services

```bash
# Khởi động với vector database mặc định (weaviate)
docker compose --profile weaviate up -d

# Hoặc với qdrant
# docker compose --profile qdrant up -d

# Hoặc với pgvector
# docker compose --profile pgvector up -d
```

### 4.4 Kiểm Tra Logs

```bash
# Xem logs của tất cả services
docker compose logs -f

# Xem logs của service cụ thể
docker compose logs -f api
docker compose logs -f web
docker compose logs -f db
```

## 5. Kiểm Tra

### 5.1 Kiểm Tra Services

```bash
# Kiểm tra trạng thái containers
docker compose ps

# Kiểm tra health của database
docker compose exec db pg_isready -U postgres

# Kiểm tra Redis
docker compose exec redis redis-cli ping
```

### 5.2 Kiểm Tra Ứng Dụng

```bash
# Test API endpoint
curl http://localhost/health

# Test web interface
curl http://localhost

# Kiểm tra dashboard
curl http://localhost:8501
```

### 5.3 Truy Cập Ứng Dụng

- **Web Interface**: http://your-domain.com
- **API Documentation**: http://your-domain.com/docs
- **Dashboard**: http://your-domain.com:8501
- **Admin Panel**: http://your-domain.com/admin

## 6. Troubleshooting

### 6.1 Lỗi Thường Gặp

#### Container không khởi động được
```bash
# Kiểm tra logs chi tiết
docker compose logs [service-name]

# Kiểm tra resource usage
docker stats

# Restart service
docker compose restart [service-name]
```

#### Database connection failed
```bash
# Kiểm tra database
docker compose exec db psql -U postgres -d dify -c "SELECT 1;"

# Reset database
docker compose down
docker volume rm docker_db_data
docker compose up -d
```

#### Redis connection failed
```bash
# Kiểm tra Redis
docker compose exec redis redis-cli -a your-redis-password ping

# Clear Redis data
docker compose exec redis redis-cli -a your-redis-password FLUSHALL
```

#### Port conflicts
```bash
# Kiểm tra ports đang sử dụng
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443

# Thay đổi ports trong .env
EXPOSE_NGINX_PORT=8080
EXPOSE_NGINX_SSL_PORT=8443
```

### 6.2 Performance Issues

#### High Memory Usage
```bash
# Giảm số workers
SERVER_WORKER_AMOUNT=1
CELERY_WORKER_AMOUNT=1

# Tối ưu PostgreSQL
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_WORK_MEM=8MB
```

#### Slow Response
```bash
# Tăng timeout
GUNICORN_TIMEOUT=600
NGINX_PROXY_READ_TIMEOUT=600s

# Scale services
docker compose up -d --scale worker=2
```

## 7. Backup và Maintenance

### 7.1 Backup Database

```bash
# Tạo backup script
cat > backup_db.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/dify/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Backup PostgreSQL
docker compose exec -T db pg_dump -U postgres dify > $BACKUP_DIR/dify_db_$DATE.sql

# Backup Redis
docker compose exec -T redis redis-cli -a your-redis-password --rdb /data/dump_$DATE.rdb

# Compress backups older than 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -exec gzip {} \;

echo "Backup completed: $DATE"
EOF

chmod +x backup_db.sh
```

### 7.2 Backup Volumes

```bash
# Backup volumes
tar -czf dify_volumes_$(date +%Y%m%d).tar.gz volumes/

# Restore volumes
tar -xzf dify_volumes_YYYYMMDD.tar.gz
```

### 7.3 Update Images

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose down
docker compose up -d

# Clean old images
docker image prune -f
```

### 7.4 Monitoring

```bash
# Tạo monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "=== Docker Compose Status ==="
docker compose ps

echo "=== Resource Usage ==="
docker stats --no-stream

echo "=== Disk Usage ==="
df -h

echo "=== Memory Usage ==="
free -h
EOF

chmod +x monitor.sh
```

### 7.5 Cron Jobs

```bash
# Thêm vào crontab
crontab -e

# Backup hàng ngày lúc 2:00 AM
0 2 * * * /opt/dify/docker/backup_db.sh

# Monitoring mỗi 5 phút
*/5 * * * * /opt/dify/docker/monitor.sh >> /var/log/dify_monitor.log

# Clean logs hàng tuần
0 0 * * 0 docker system prune -f
```

## 8. SSL/HTTPS Configuration

### 8.1 Sử dụng Let's Encrypt

```bash
# Cấu hình trong .env
NGINX_HTTPS_ENABLED=true
CERTBOT_EMAIL=your-email@domain.com
CERTBOT_DOMAIN=your-domain.com

# Khởi động với certbot
docker compose --profile certbot up -d
```

### 8.2 Sử dụng SSL Certificate Tự Có

```bash
# Copy certificates
cp your-cert.crt docker/nginx/ssl/dify.crt
cp your-key.key docker/nginx/ssl/dify.key

# Cấu hình .env
NGINX_HTTPS_ENABLED=true
NGINX_SSL_CERT_FILENAME=dify.crt
NGINX_SSL_CERT_KEY_FILENAME=dify.key
```

## 9. Scaling và High Availability

### 9.1 Scale Services

```bash
# Scale workers
docker compose up -d --scale worker=3

# Scale API
docker compose up -d --scale api=2
```

### 9.2 External Database

```bash
# Sử dụng external PostgreSQL
DB_HOST=your-external-db-host
DB_PORT=5432
DB_USERNAME=dify_user
DB_PASSWORD=strong-password

# Disable local db service
docker compose up -d --scale db=0
```

---

**Lưu ý**: Thay thế `your-domain.com`, `your-email@domain.com`, và các passwords bằng giá trị thực tế của bạn.

**Hỗ trợ**: Nếu gặp vấn đề, kiểm tra logs chi tiết và tham khảo documentation chính thức của Dify.
