# 🚀 Dashboard Integration Guide

## Tổng quan

Dashboard module đã được tích hợp hoàn toàn vào Dify project với các tính năng:

- ✅ **Account Management**: Quản lý users, quotas, plans
- ✅ **Plan Management**: Tạo và chỉnh sửa pricing plans  
- ✅ **Payment Integration**: Cấu hình payment gateway
- ✅ **Explore Management**: Quản lý recommended apps
- ✅ **API Authentication**: Secure API với token-based auth
- ✅ **Docker Integration**: Fully containerized deployment

## 🏗️ Kiến trúc

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Streamlit     │    │   Flask API     │    │   PostgreSQL    │
│   Dashboard     │◄──►│   /dashboard/*  │◄──►│   Database      │
│   Port: 8501    │    │   Port: 5001    │    │   Port: 5432    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Development Mode

```bash
# Windows
.\dev\start-dashboard.ps1

# Linux/Mac  
./dev/start-dashboard.sh
```

### Production Mode

```bash
# Start all services
cd docker
docker-compose up -d

# Access dashboard
open http://localhost:8501
```

**Login credentials:**
- Username: `admin`
- Password: `@DifyAdmin2024`

## 📁 File Structure

```
dify/
├── dashboard/                    # Streamlit Frontend
│   ├── main.py                  # Entry point
│   ├── config.yaml              # Auth config
│   ├── components/              # UI Components
│   │   ├── accounts.py          # Account management
│   │   ├── plans.py             # Plan management
│   │   ├── payments.py          # Payment settings
│   │   └── explore.py           # Recommended apps
│   └── tests/                   # Integration tests
├── api/controllers/dashboard/    # Flask Backend API
│   ├── __init__.py              # Blueprint + auth
│   ├── accounts.py              # Account endpoints
│   ├── plan.py                  # Plan endpoints
│   └── explore.py               # Explore endpoints
├── api/models/                  # Database Models
│   ├── alies_payments_custom.py # Payment aliases
│   ├── payments_history_custom.py # Payment history
│   └── system_custom_info.py    # System config
└── dev/                         # Development tools
    ├── start-dashboard.ps1      # Windows startup
    ├── start-dashboard.sh       # Linux startup
    └── test-dashboard-api.sh    # API testing
```

## 🔧 Configuration

### Environment Variables

```bash
# Dashboard specific
DASHBOARD_API_TOKEN=89fisiqoo009
DASHBOARD_PORT=8501

# Database
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=dify
DB_USERNAME=postgres
DB_PASSWORD=difyai123456
```

### API Authentication

All dashboard API endpoints require header:
```
api-token: 89fisiqoo009
```

## 📊 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/dashboard/` | GET | Health check |
| `/dashboard/accounts` | GET | List accounts |
| `/dashboard/accounts` | PUT | Update accounts |
| `/dashboard/plans` | GET | List plans |
| `/dashboard/plans` | PUT | Update plans |
| `/dashboard/explore` | GET | List recommended apps |
| `/dashboard/explore` | POST | Add recommended app |

## 🧪 Testing

### Run Integration Tests

```bash
cd dashboard
python -m pytest tests/test_integration.py -v
```

### Manual API Testing

```bash
# Test all endpoints
./dev/test-dashboard-api.sh

# Test specific endpoint
curl -H "api-token: 89fisiqoo009" http://localhost:5001/dashboard/accounts
```

## 🐳 Docker Deployment

### Build Images

```bash
# Build dashboard image
docker build -t dify/dashboard ./dashboard

# Build API image  
docker build -t dify/api ./api
```

### Run with Docker Compose

```bash
cd docker
docker-compose up -d dashboard
```

## 🔍 Monitoring & Logging

### Dashboard Logs

```bash
# Docker logs
docker-compose logs -f dashboard

# Local logs
~/.streamlit/logs/
```

### API Logs

```bash
# Docker logs
docker-compose logs -f api

# Local logs
tail -f api/logs/server.log
```

## 🛠️ Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Connection refused | Check API service: `curl http://localhost:5001/health` |
| Authentication failed | Verify API token in config.yaml |
| Database error | Check database: `docker-compose logs db` |
| Permission denied | Ensure file permissions: `chmod 644 config.yaml` |

### Health Checks

```bash
# Check API health
curl http://localhost:5001/dashboard/

# Check dashboard health  
curl http://localhost:8501/_stcore/health

# Check database
docker-compose exec db pg_isready
```

## 🔄 Updates & Maintenance

### Update Dashboard

```bash
# Pull latest changes
git pull origin main

# Rebuild containers
docker-compose build dashboard
docker-compose up -d dashboard
```

### Database Migrations

```bash
cd api
uv run flask db upgrade
```

## 📚 Additional Resources

- **[DASHBOARD_README.md](./DASHBOARD_README.md)** - Quick start guide
- **[DASHBOARD_TECHNICAL_DOCUMENTATION.md](./DASHBOARD_TECHNICAL_DOCUMENTATION.md)** - Technical details
- **[API Documentation](./api/controllers/dashboard/)** - API reference

---

*Last updated: 2024-01-15*
