# Cấu Hình Nâng Cao cho Dify Deployment

## 1. Multi-Node Deployment

### 1.1 Load Balancer Configuration

```yaml
# docker-compose.lb.yaml
version: '3.8'
services:
  nginx-lb:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/lb.conf:/etc/nginx/nginx.conf
    depends_on:
      - dify-node1
      - dify-node2
```

### 1.2 External Database Setup

```bash
# PostgreSQL Cluster
DB_HOST=postgres-cluster.example.com
DB_PORT=5432
DB_USERNAME=dify_user
DB_PASSWORD=secure_password
DB_DATABASE=dify

# Redis Cluster
REDIS_USE_CLUSTERS=true
REDIS_CLUSTERS=redis1:6379,redis2:6379,redis3:6379
REDIS_CLUSTERS_PASSWORD=cluster_password
```

## 2. Monitoring và Logging

### 2.1 Prometheus + Grafana

```yaml
# monitoring/docker-compose.monitoring.yaml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  prometheus_data:
  grafana_data:
```

### 2.2 ELK Stack Integration

```bash
# Elasticsearch configuration
ELASTICSEARCH_HOST=elasticsearch
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_USERNAME=elastic
ELASTICSEARCH_PASSWORD=changeme

# Logstash configuration
LOG_LEVEL=INFO
ENABLE_REQUEST_LOGGING=true
```

### 2.3 OpenTelemetry

```bash
# Enable OpenTelemetry
ENABLE_OTEL=true
OTLP_BASE_ENDPOINT=http://jaeger:14268
OTEL_EXPORTER_TYPE=otlp
OTEL_SAMPLING_RATE=0.1
```

## 3. Performance Tuning

### 3.1 Database Optimization

```sql
-- PostgreSQL performance tuning
ALTER SYSTEM SET shared_buffers = '1GB';
ALTER SYSTEM SET effective_cache_size = '4GB';
ALTER SYSTEM SET maintenance_work_mem = '256MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
SELECT pg_reload_conf();
```

### 3.2 Redis Optimization

```bash
# Redis configuration
REDIS_MAXMEMORY=2gb
REDIS_MAXMEMORY_POLICY=allkeys-lru
REDIS_SAVE_POLICY="900 1 300 10 60 10000"
```

### 3.3 Application Tuning

```bash
# API Performance
SERVER_WORKER_AMOUNT=8
SERVER_WORKER_CLASS=gevent
SERVER_WORKER_CONNECTIONS=1000
GUNICORN_TIMEOUT=300

# Celery Performance
CELERY_WORKER_AMOUNT=4
CELERY_AUTO_SCALE=true
CELERY_MAX_WORKERS=8
CELERY_MIN_WORKERS=2

# Connection Pooling
SQLALCHEMY_POOL_SIZE=100
SQLALCHEMY_POOL_RECYCLE=3600
SQLALCHEMY_MAX_OVERFLOW=20
```

## 4. Security Hardening

### 4.1 Network Security

```bash
# Create custom network
docker network create --driver bridge dify-network

# Isolate services
docker-compose.yaml:
networks:
  dify-network:
    external: true
  db-network:
    internal: true
```

### 4.2 Container Security

```dockerfile
# Security-hardened Dockerfile example
FROM python:3.11-slim
RUN groupadd -r dify && useradd -r -g dify dify
USER dify
COPY --chown=dify:dify . /app
WORKDIR /app
```

### 4.3 Secrets Management

```bash
# Using Docker Secrets
echo "your-secret-key" | docker secret create dify_secret_key -
echo "your-db-password" | docker secret create dify_db_password -

# docker-compose.yaml
services:
  api:
    secrets:
      - dify_secret_key
      - dify_db_password
    environment:
      SECRET_KEY_FILE: /run/secrets/dify_secret_key
      DB_PASSWORD_FILE: /run/secrets/dify_db_password

secrets:
  dify_secret_key:
    external: true
  dify_db_password:
    external: true
```

## 5. Backup Strategies

### 5.1 Automated Backup Script

```bash
#!/bin/bash
# advanced_backup.sh

BACKUP_DIR="/opt/dify/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup directory
mkdir -p $BACKUP_DIR/{db,volumes,configs}

# Database backup with compression
docker compose exec -T db pg_dump -U postgres -Fc dify > $BACKUP_DIR/db/dify_$DATE.dump

# Volume backup
tar -czf $BACKUP_DIR/volumes/volumes_$DATE.tar.gz volumes/

# Configuration backup
tar -czf $BACKUP_DIR/configs/configs_$DATE.tar.gz .env docker-compose.yaml nginx/

# Upload to S3 (optional)
if [ "$BACKUP_TO_S3" = "true" ]; then
    aws s3 sync $BACKUP_DIR s3://your-backup-bucket/dify-backups/
fi

# Cleanup old backups
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete

# Send notification
curl -X POST -H 'Content-type: application/json' \
    --data '{"text":"Dify backup completed: '$DATE'"}' \
    $SLACK_WEBHOOK_URL
```

### 5.2 Point-in-Time Recovery

```bash
# Enable WAL archiving for PostgreSQL
POSTGRES_ARCHIVE_MODE=on
POSTGRES_ARCHIVE_COMMAND='cp %p /var/lib/postgresql/wal_archive/%f'
POSTGRES_WAL_LEVEL=replica
```

## 6. Disaster Recovery

### 6.1 Multi-Region Setup

```bash
# Primary region
REGION=us-east-1
DB_HOST=dify-primary.cluster-xxx.us-east-1.rds.amazonaws.com

# Disaster recovery region
DR_REGION=us-west-2
DR_DB_HOST=dify-dr.cluster-yyy.us-west-2.rds.amazonaws.com
```

### 6.2 Failover Script

```bash
#!/bin/bash
# failover.sh

PRIMARY_DB="dify-primary.cluster-xxx.us-east-1.rds.amazonaws.com"
DR_DB="dify-dr.cluster-yyy.us-west-2.rds.amazonaws.com"

# Check primary database
if ! pg_isready -h $PRIMARY_DB -U postgres; then
    echo "Primary database is down, initiating failover..."
    
    # Update environment
    sed -i "s/$PRIMARY_DB/$DR_DB/g" .env
    
    # Restart services
    docker compose down
    docker compose up -d
    
    # Send alert
    echo "Failover completed to DR site" | mail -s "Dify Failover Alert" admin@company.com
fi
```

## 7. Custom Integrations

### 7.1 Custom Vector Database

```python
# custom_vector_store.py
from dify.core.vector_store.base import BaseVectorStore

class CustomVectorStore(BaseVectorStore):
    def __init__(self, config):
        self.endpoint = config.get('endpoint')
        self.api_key = config.get('api_key')
    
    def add_texts(self, texts, metadatas=None):
        # Implementation
        pass
    
    def similarity_search(self, query, k=4):
        # Implementation
        pass
```

### 7.2 Custom Authentication

```python
# custom_auth.py
from flask import request
from dify.core.auth.base import BaseAuthProvider

class CustomAuthProvider(BaseAuthProvider):
    def authenticate(self):
        token = request.headers.get('Authorization')
        # Custom authentication logic
        return self.validate_token(token)
```

## 8. Development Environment

### 8.1 Local Development Setup

```yaml
# docker-compose.dev.yaml
version: '3.8'
services:
  api:
    build:
      context: ../api
      dockerfile: Dockerfile.dev
    volumes:
      - ../api:/app/api
      - /app/api/.venv
    environment:
      - DEBUG=true
      - FLASK_DEBUG=true
    ports:
      - "5001:5001"
```

### 8.2 Testing Configuration

```bash
# Test environment variables
DEPLOY_ENV=TESTING
DB_DATABASE=dify_test
REDIS_DB=1

# Run tests
docker compose -f docker-compose.test.yaml up --abort-on-container-exit
```

## 9. Migration Scripts

### 9.1 Version Upgrade

```bash
#!/bin/bash
# upgrade.sh

OLD_VERSION="0.7.1"
NEW_VERSION="0.7.2"

echo "Upgrading Dify from $OLD_VERSION to $NEW_VERSION"

# Backup before upgrade
./backup.sh

# Pull new images
docker compose pull

# Run migrations
docker compose run --rm api python -m flask db upgrade

# Restart services
docker compose down
docker compose up -d

echo "Upgrade completed successfully"
```

### 9.2 Data Migration

```python
# migrate_data.py
import psycopg2
from sqlalchemy import create_engine

def migrate_user_data():
    # Migration logic
    pass

def migrate_app_data():
    # Migration logic
    pass

if __name__ == "__main__":
    migrate_user_data()
    migrate_app_data()
```

## 10. Troubleshooting Tools

### 10.1 Health Check Script

```bash
#!/bin/bash
# health_check.sh

echo "=== Dify Health Check ==="

# Check containers
echo "Container Status:"
docker compose ps

# Check database connectivity
echo "Database Connection:"
docker compose exec db pg_isready -U postgres

# Check Redis
echo "Redis Connection:"
docker compose exec redis redis-cli ping

# Check API health
echo "API Health:"
curl -f http://localhost/health || echo "API health check failed"

# Check disk space
echo "Disk Usage:"
df -h | grep -E "(/$|/opt)"

# Check memory usage
echo "Memory Usage:"
free -h

# Check logs for errors
echo "Recent Errors:"
docker compose logs --tail=50 | grep -i error
```

### 10.2 Performance Monitoring

```bash
#!/bin/bash
# performance_monitor.sh

# Monitor resource usage
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

# Monitor database performance
docker compose exec db psql -U postgres -d dify -c "
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;"

# Monitor Redis performance
docker compose exec redis redis-cli info stats
```

---

**Lưu ý**: Các cấu hình nâng cao này yêu cầu kiến thức sâu về DevOps và system administration. Hãy test kỹ trong môi trường development trước khi áp dụng vào production.
