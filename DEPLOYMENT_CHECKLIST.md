# Dify VPS Deployment Checklist

## Pre-Deployment Checklist

### 🖥️ VPS Requirements
- [ ] VPS có ít nhất 8GB RAM (khuyến nghị 16GB)
- [ ] VPS có ít nhất 4 CPU cores (khuyến nghị 8 cores)
- [ ] VPS có ít nhất 50GB storage SSD
- [ ] OS: Ubuntu 20.04/22.04 LTS hoặc CentOS 7/8
- [ ] Root access hoặc sudo privileges

### 🌐 Domain và DNS
- [ ] Domain đã được đăng ký
- [ ] DNS A record trỏ về IP của VPS
- [ ] Domain đã propagate (kiểm tra với `nslookup your-domain.com`)
- [ ] Port 80 và 443 accessible từ internet

### 🔐 Security Preparation
- [ ] SSH key pair đã được tạo
- [ ] SSH access với key (không dùng password)
- [ ] Firewall rules đã được plan
- [ ] SSL certificate strategy đã được quyết định (Let's Encrypt/Custom)

## Deployment Process Checklist

### 📋 Step 1: VPS Setup
- [ ] Connect to VPS via SSH
- [ ] Update system packages
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- [ ] Create non-root user (nếu chưa có)
  ```bash
  sudo adduser dify
  sudo usermod -aG sudo dify
  ```
- [ ] Configure SSH for new user
- [ ] Disable root login (optional but recommended)

### 🐳 Step 2: Docker Installation
- [ ] Install Docker Engine
  ```bash
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo usermod -aG docker $USER
  ```
- [ ] Install Docker Compose
- [ ] Verify Docker installation
  ```bash
  docker --version
  docker compose version
  ```
- [ ] Test Docker without sudo
  ```bash
  docker run hello-world
  ```

### 📁 Step 3: Project Setup
- [ ] Clone Dify repository
  ```bash
  git clone https://github.com/your-repo/dify.git /opt/dify
  ```
- [ ] Set proper permissions
  ```bash
  sudo chown -R $USER:$USER /opt/dify
  ```
- [ ] Copy deployment scripts
  ```bash
  cp scripts/*.sh /opt/dify/
  chmod +x /opt/dify/*.sh
  ```

### ⚙️ Step 4: Configuration
- [ ] Copy environment file
  ```bash
  cd /opt/dify/docker
  cp .env.example .env
  ```
- [ ] Update .env with production values:
  - [ ] Domain URLs (CONSOLE_API_URL, APP_WEB_URL, etc.)
  - [ ] Strong SECRET_KEY
  - [ ] Database passwords
  - [ ] Redis password
  - [ ] SSL settings
- [ ] Verify configuration syntax

### 🔒 Step 5: SSL Certificate
- [ ] Choose SSL method (Let's Encrypt recommended)
- [ ] Install Certbot (if using Let's Encrypt)
  ```bash
  sudo apt install certbot
  ```
- [ ] Obtain SSL certificate
  ```bash
  sudo certbot certonly --standalone -d your-domain.com
  ```
- [ ] Copy certificates to nginx directory
  ```bash
  sudo cp /etc/letsencrypt/live/your-domain.com/* /opt/dify/docker/nginx/ssl/
  ```
- [ ] Set proper permissions on certificates

### 🚀 Step 6: Deployment
- [ ] Create necessary directories
  ```bash
  mkdir -p /opt/dify/docker/volumes/{app/storage,db/data,redis/data}
  ```
- [ ] Build Docker images
  ```bash
  cd /opt/dify/docker
  docker compose build --no-cache
  ```
- [ ] Start database services first
  ```bash
  docker compose up -d db redis
  ```
- [ ] Wait for database initialization (30-60 seconds)
- [ ] Start all services
  ```bash
  docker compose up -d
  ```

### 🔥 Step 7: Firewall Configuration
- [ ] Configure UFW (Ubuntu) or firewalld (CentOS)
  ```bash
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw allow 8501/tcp
  sudo ufw enable
  ```
- [ ] Verify firewall rules
- [ ] Test external access

## Post-Deployment Verification

### ✅ Service Health Checks
- [ ] All Docker containers are running
  ```bash
  docker compose ps
  ```
- [ ] No containers in "Restarting" state
- [ ] Check container logs for errors
  ```bash
  docker compose logs api
  docker compose logs web
  docker compose logs dashboard
  ```

### 🌐 Web Interface Tests
- [ ] Main web interface accessible: `https://your-domain.com`
- [ ] API health endpoint: `https://your-domain.com/api/health`
- [ ] Dashboard accessible: `https://your-domain.com:8501`
- [ ] Admin setup page: `https://your-domain.com/install`
- [ ] SSL certificate valid (no browser warnings)

### 📊 Performance Tests
- [ ] Response time < 3 seconds for main page
- [ ] API response time < 1 second
- [ ] Dashboard loads within 5 seconds
- [ ] No memory leaks after 1 hour of running

### 🔧 System Resource Checks
- [ ] CPU usage < 50% at idle
- [ ] Memory usage < 70%
- [ ] Disk usage < 80%
- [ ] All services have adequate resources

## Security Hardening Checklist

### 🔐 SSH Security
- [ ] SSH key-only authentication
- [ ] Disable root login
- [ ] Change default SSH port (optional)
- [ ] Configure fail2ban
  ```bash
  sudo apt install fail2ban
  sudo systemctl enable fail2ban
  ```

### 🛡️ Application Security
- [ ] Strong passwords in .env file
- [ ] CORS settings properly configured
- [ ] Rate limiting enabled in nginx
- [ ] Security headers configured
- [ ] Database not accessible from outside

### 🔄 SSL/TLS Security
- [ ] SSL certificate auto-renewal configured
  ```bash
  sudo crontab -e
  # Add: 0 12 * * * /usr/bin/certbot renew --quiet
  ```
- [ ] TLS 1.2+ only
- [ ] HSTS headers enabled
- [ ] Certificate chain complete

## Monitoring Setup Checklist

### 📈 Health Monitoring
- [ ] Health check script installed
  ```bash
  cp scripts/health-check.sh /opt/dify/
  chmod +x /opt/dify/health-check.sh
  ```
- [ ] Cron job for health checks
  ```bash
  crontab -e
  # Add: */5 * * * * /opt/dify/health-check.sh --alert
  ```
- [ ] Log rotation configured

### 💾 Backup Setup
- [ ] Backup script installed and tested
  ```bash
  /opt/dify/backup.sh test_backup
  ```
- [ ] Backup directory created with proper permissions
- [ ] Daily backup cron job
  ```bash
  # Add: 0 2 * * * /opt/dify/backup.sh
  ```
- [ ] Backup verification process

### 📧 Alerting Setup
- [ ] Slack webhook configured (optional)
- [ ] Email alerts configured (optional)
- [ ] Test alert notifications
- [ ] Alert thresholds properly set

## Maintenance Checklist

### 🔄 Regular Tasks
- [ ] Weekly system updates
- [ ] Monthly Docker image updates
- [ ] Quarterly security audit
- [ ] SSL certificate renewal (automated)

### 📋 Documentation
- [ ] Document custom configurations
- [ ] Record admin credentials securely
- [ ] Create runbook for common issues
- [ ] Document backup/restore procedures

## Troubleshooting Checklist

### 🐛 Common Issues
- [ ] Know how to check Docker logs
- [ ] Know how to restart services
- [ ] Know how to check system resources
- [ ] Know how to restore from backup

### 🆘 Emergency Procedures
- [ ] Rollback procedure documented
- [ ] Emergency contact information
- [ ] Backup restore procedure tested
- [ ] Service restart procedures

## Final Verification

### ✅ Complete System Test
- [ ] Create test user account
- [ ] Upload test document
- [ ] Create test AI application
- [ ] Test API endpoints
- [ ] Verify dashboard functionality
- [ ] Test backup and restore
- [ ] Simulate service failure and recovery

### 📝 Documentation
- [ ] Update deployment documentation
- [ ] Record any custom configurations
- [ ] Document known issues and solutions
- [ ] Create user guide for team

## Sign-off

- [ ] **Technical Lead Approval**: _________________ Date: _______
- [ ] **Security Review**: _________________ Date: _______
- [ ] **Operations Handover**: _________________ Date: _______

---

**Deployment Status**: ⬜ In Progress ⬜ Completed ⬜ Failed

**Deployment Date**: _______________

**Deployed By**: _______________

**Production URL**: https://_______________

**Notes**: 
_________________________________________________
_________________________________________________
_________________________________________________
