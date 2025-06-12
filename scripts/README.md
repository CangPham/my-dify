# Dify Management Scripts

Bộ script quản lý và vận hành Dify trên VPS.

## Danh Sách Scripts

### 1. deploy.sh - Script Deploy Tự Động
```bash
./deploy.sh [domain] [email]
```

**Chức năng:**
- Cài đặt Docker và Docker Compose
- Clone repository Dify
- Cấu hình SSL certificate (Let's Encrypt hoặc self-signed)
- Thiết lập environment variables
- Deploy toàn bộ services
- Cấu hình firewall và monitoring

**Ví dụ:**
```bash
# Deploy với domain thật
./deploy.sh mydify.com admin@mydify.com

# Deploy localhost (development)
./deploy.sh localhost
```

### 2. backup.sh - Script Backup
```bash
./backup.sh [backup_name]
```

**Chức năng:**
- Backup database PostgreSQL
- Backup volumes (storage, logs, configs)
- Backup configuration files
- Backup custom code
- Tạo manifest file
- Verify backup integrity
- Cleanup old backups

**Ví dụ:**
```bash
# Auto backup với timestamp
./backup.sh

# Named backup
./backup.sh before_major_update
```

### 3. health-check.sh - Script Kiểm Tra Sức Khỏe
```bash
./health-check.sh [--verbose] [--alert]
```

**Chức năng:**
- Kiểm tra status các Docker containers
- Test URL endpoints
- Monitor system resources (CPU, RAM, Disk)
- Kiểm tra database connections
- Kiểm tra Redis memory
- Gửi alerts qua Slack/Email

**Ví dụ:**
```bash
# Basic health check
./health-check.sh

# Verbose output với alerts
./health-check.sh --verbose --alert
```

### 4. update.sh - Script Update
```bash
./update.sh [--force] [--no-backup]
```

**Chức năng:**
- Kiểm tra updates từ Git repository
- Tạo backup trước khi update
- Pull latest code
- Rebuild Docker images
- Run database migrations
- Verify update success

**Ví dụ:**
```bash
# Interactive update
./update.sh

# Force update without confirmation
./update.sh --force

# Update without backup (không khuyến nghị)
./update.sh --no-backup
```

## Cấu Hình Environment Variables

Tạo file `/etc/environment` hoặc `~/.bashrc` với các biến sau:

```bash
# Dify Configuration
export DIFY_DOMAIN="your-domain.com"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
export ALERT_EMAIL="admin@your-domain.com"

# Backup Configuration
export BACKUP_RETENTION_DAYS=7
export BACKUP_COMPRESSION=true

# Monitoring Thresholds
export DISK_THRESHOLD=80
export MEMORY_THRESHOLD=80
export CPU_THRESHOLD=80
```

## Cron Jobs Setup

Thêm vào crontab (`crontab -e`):

```bash
# Health check every 5 minutes
*/5 * * * * /opt/dify/health-check.sh --alert >> /var/log/dify/health.log 2>&1

# Daily backup at 2 AM
0 2 * * * /opt/dify/backup.sh >> /var/log/dify/backup.log 2>&1

# Weekly update check (Sunday 3 AM)
0 3 * * 0 /opt/dify/update.sh --force >> /var/log/dify/update.log 2>&1

# Monthly cleanup (1st day of month, 4 AM)
0 4 1 * * /opt/dify/cleanup.sh >> /var/log/dify/cleanup.log 2>&1
```

## Log Files

Tất cả logs được lưu tại `/var/log/dify/`:

- `health.log` - Health check logs
- `backup.log` - Backup operation logs
- `update.log` - Update operation logs
- `deploy.log` - Deployment logs

## Alerts và Notifications

### Slack Integration
1. Tạo Slack App và Incoming Webhook
2. Set environment variable: `SLACK_WEBHOOK_URL`
3. Scripts sẽ tự động gửi alerts

### Email Alerts
1. Cài đặt mailutils: `sudo apt install mailutils`
2. Cấu hình SMTP
3. Set environment variable: `ALERT_EMAIL`

## Troubleshooting

### Script Permissions
```bash
chmod +x /opt/dify/*.sh
```

### Log Rotation
Tạo file `/etc/logrotate.d/dify`:
```
/var/log/dify/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
```

### Common Issues

1. **Docker permission denied**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Git authentication issues**
   ```bash
   git config --global credential.helper store
   ```

3. **SSL certificate renewal**
   ```bash
   sudo certbot renew
   sudo cp /etc/letsencrypt/live/your-domain.com/* /opt/dify/docker/nginx/ssl/
   cd /opt/dify/docker && docker compose restart nginx
   ```

## Security Best Practices

1. **Secure script files:**
   ```bash
   sudo chown root:root /opt/dify/*.sh
   sudo chmod 755 /opt/dify/*.sh
   ```

2. **Protect sensitive files:**
   ```bash
   sudo chmod 600 /opt/dify/docker/.env
   ```

3. **Regular security updates:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Monitoring Dashboard

Để setup Grafana monitoring (tùy chọn):

```bash
cd /opt/dify/monitoring
docker compose -f docker-compose.monitoring.yml up -d
```

Access:
- Grafana: http://your-domain:3000 (admin/admin123)
- Prometheus: http://your-domain:9090

## Support

Nếu gặp vấn đề:

1. Kiểm tra logs: `tail -f /var/log/dify/*.log`
2. Chạy health check: `/opt/dify/health-check.sh --verbose`
3. Kiểm tra Docker: `cd /opt/dify/docker && docker compose ps`
4. Restart services: `cd /opt/dify/docker && docker compose restart`

## Backup và Recovery

### Manual Backup
```bash
/opt/dify/backup.sh manual_backup_$(date +%Y%m%d)
```

### Restore từ Backup
```bash
# Stop services
cd /opt/dify/docker && docker compose down

# Restore database
docker compose up -d db redis
sleep 30
docker compose exec -T db psql -U postgres -c "DROP DATABASE IF EXISTS dify;"
docker compose exec -T db psql -U postgres -c "CREATE DATABASE dify;"
docker compose exec -T db psql -U postgres dify < /opt/backups/backup_name_database.sql

# Restore volumes
cd /opt/dify/docker
tar -xzf /opt/backups/backup_name_volumes.tar.gz

# Start all services
docker compose up -d
```

---

**Lưu ý**: Luôn test scripts trên môi trường development trước khi sử dụng trên production.
