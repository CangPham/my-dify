# Dashboard Module - Quick Start Guide

## 🚀 Khởi động nhanh

### 1. Chạy Dashboard trong 5 phút

```bash
# Clone repository
git clone <dify-repo>
cd dify

# Start với Docker Compose
cd docker
docker-compose up -d dashboard

# Truy cập dashboard
open http://localhost:8501
```

**Login credentials:**
- Username: `admin`
- Password: `@DifyAdmin2024`

### 2. Cấu trúc Project

```
dify/
├── dashboard/              # Streamlit Frontend
│   ├── main.py            # Entry point
│   ├── config.yaml        # Authentication config
│   ├── components/        # UI Components
│   └── modules/           # Shared utilities
├── api/controllers/dashboard/  # Flask Backend API
│   ├── __init__.py        # Blueprint setup
│   ├── accounts.py        # Account management
│   ├── plans.py           # Plan management
│   └── explore.py         # Recommended apps
└── docker/
    └── docker-compose.yaml
```

### 3. Các tính năng chính

| Component | Chức năng | URL |
|-----------|-----------|-----|
| **Accounts** | Quản lý user accounts, quotas, plans | `/dashboard/accounts` |
| **Plans** | Tạo và chỉnh sửa pricing plans | `/dashboard/plans` |
| **Payments** | Cấu hình payment gateway | `/dashboard/payment_settings` |
| **Explore** | Quản lý recommended apps | `/dashboard/explore` |

### 4. API Endpoints

```http
# Authentication required: api-token: 89fisiqoo009

GET    /dashboard/accounts          # Lấy danh sách accounts
PUT    /dashboard/accounts          # Cập nhật accounts
GET    /dashboard/plans             # Lấy danh sách plans
PUT    /dashboard/plans             # Cập nhật plans
GET    /dashboard/explore           # Lấy recommended apps
POST   /dashboard/explore           # Thêm recommended app
GET    /dashboard/payment_settings  # Lấy payment config
PUT    /dashboard/payment_settings  # Cập nhật payment config
```

### 5. Development Setup

```bash
# Backend API
cd api
pip install -r requirements.txt
python app.py

# Frontend Dashboard
cd dashboard
pip install -r requirements.txt
export API_URL="http://localhost:5001"
streamlit run main.py
```

### 6. Configuration

**config.yaml:**
```yaml
api:
  url: "http://localhost:5001"
  token: "89fisiqoo009"

credentials:
  usernames:
    admin:
      password: "@DifyAdmin2024"
      email: admin@gmail.com
```

**Environment Variables:**
```bash
API_URL=http://localhost:5001
STREAMLIT_SERVER_PORT=8501
```

### 7. Troubleshooting

| Lỗi | Giải pháp |
|-----|-----------|
| Connection refused | Kiểm tra API service: `curl http://localhost:5001/health` |
| Authentication failed | Verify API token trong config.yaml |
| Database error | Check database: `docker-compose logs db` |
| Permission denied | Ensure file permissions: `chmod 644 config.yaml` |

### 8. Tài liệu chi tiết

📖 **[DASHBOARD_TECHNICAL_DOCUMENTATION.md](./DASHBOARD_TECHNICAL_DOCUMENTATION.md)**

Tài liệu kỹ thuật đầy đủ bao gồm:
- Kiến trúc chi tiết và data flow
- API documentation với examples
- Database schema và relationships
- Development guide và best practices
- Security considerations
- Advanced features (caching, monitoring, analytics)

### 9. Support

- **Issues**: Tạo issue trên GitHub repository
- **Documentation**: Xem file DASHBOARD_TECHNICAL_DOCUMENTATION.md
- **Logs**: `docker-compose logs dashboard` hoặc `~/.streamlit/logs/`

---

## 📋 Quick Reference

### Common Commands

```bash
# Start dashboard
docker-compose up -d dashboard

# View logs
docker-compose logs -f dashboard

# Restart dashboard
docker-compose restart dashboard

# Update dashboard
docker-compose pull dashboard
docker-compose up -d dashboard

# Access database
docker-compose exec db psql -U postgres -d dify

# Run migrations
docker-compose exec api flask upgrade-db
```

### API Testing

```bash
# Test API health
curl -H "api-token: 89fisiqoo009" http://localhost:5001/dashboard/

# Get accounts
curl -H "api-token: 89fisiqoo009" http://localhost:5001/dashboard/accounts

# Get plans
curl -H "api-token: 89fisiqoo009" http://localhost:5001/dashboard/plans
```

### File Locations

```
Logs:           ~/.streamlit/logs/
Config:         dashboard/config.yaml
Database:       docker/volumes/db/
API Code:       api/controllers/dashboard/
Frontend Code:  dashboard/components/
```

---

*Last updated: 2024-01-15*
