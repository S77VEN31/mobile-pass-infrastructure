# Pass Generator Infrastructure

Centralized infrastructure management for the Pass Generator application.

## 🏗️ Architecture

This repository manages all services for the Pass Generator application:

```
pass-generator-infrastructure/
├── docker-compose.yml          # Main orchestration file
├── deploy.sh                   # Deployment script
├── check-status.sh            # Status monitoring
├── verify-nginx-config.sh     # Nginx configuration validator
├── nginx.conf                 # Main nginx configuration
├── conf.d/                    # Virtual host configurations
├── certificates/              # SSL certificates
│   └── api.itass.cloud/
│       ├── certificate.crt
│       └── private.key
└── secrets/                   # Sensitive credentials (gitignored)
    ├── google-service-account.json
    └── wwdr.pem
```

## 📦 Services

The infrastructure manages the following services:

| Service | Container Name | Port | Description |
|---------|---------------|------|-------------|
| SQL Server | pass-generator-db | 1433 | Database |
| Pass Converter | pass-converter | 3002 | Apple Wallet to Google Wallet converter |
| Backend API | pass-generator-api | 3001 | Main API server |
| Frontend | pass-generator-frontend | 3000 | Next.js application |
| Nginx | pass-generator-nginx | 443, 80 | Reverse proxy & SSL termination |

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose installed
- Access to the repository
- SSL certificates for your domain
- Google Wallet API credentials (optional, for Google Wallet features)

### Setup

1. **Clone the repository:**
   ```bash
   cd /home/mobilepass/apps/mobile-pass-infrastructure
   ```

2. **Configure secrets** (see `secrets/README.md`):
   ```bash
   # Copy your Google Wallet credentials
   cp /path/to/your/google-service-account.json secrets/

   # Copy Apple WWDR certificate
   cp /path/to/wwdr.pem secrets/
   ```

3. **Deploy all services:**
   ```bash
   ./deploy.sh deploy
   ```

## 🔧 Management Commands

### Deployment

```bash
# Full deployment
./deploy.sh deploy

# Update specific service
./deploy.sh update api
./deploy.sh update frontend
./deploy.sh update pass-converter
```

### Building

```bash
# Build specific service
./deploy.sh build api
./deploy.sh build frontend
./deploy.sh build pass-converter
```

### Monitoring

```bash
# Check status
./deploy.sh status

# View logs (all services)
./deploy.sh logs

# View logs (specific service)
./deploy.sh logs api
./deploy.sh logs frontend
./deploy.sh logs nginx
```

### Maintenance

```bash
# Restart all services
./deploy.sh restart

# Stop all services
./deploy.sh stop

# Backup volumes
./deploy.sh backup
```

## 🌐 Service URLs

- **Production Frontend:** https://wallet.itass.cloud
- **Production API:** https://wallet.itass.cloud/api
- **API Health Check:** https://wallet.itass.cloud/api/health
- **Pass Converter:** http://localhost:3002 (internal only)

## 📝 Configuration

### Environment Variables

Main configuration is in `docker-compose.yml`. Key variables:

**Database:**
- `DB_SERVER`: Database server hostname
- `DB_PASSWORD`: Database password
- `DB_NAME`: Database name

**JWT:**
- `JWT_SECRET`: Secret for signing JWT tokens
- `JWT_EXPIRES_IN`: Access token expiration
- `JWT_REFRESH_EXPIRES_IN`: Refresh token expiration

**Google Wallet:**
- `GOOGLE_SERVICE_ACCOUNT_PATH`: Path to service account JSON
- `GOOGLE_ISSUER_ID`: Your Google Wallet Issuer ID
- `GOOGLE_STORAGE_BUCKET`: (Optional) GCS bucket for images
- `IMAGE_HOST_URL`: Public URL for images
- `PASS_CONVERTER_URL`: Internal URL to pass-converter service

**CORS:**
- `CORS_ORIGIN`: Allowed origin for CORS

### SSL Certificates

Place your SSL certificates in:
```
certificates/api.itass.cloud/
├── certificate.crt
└── private.key
```

### Nginx Configuration

- Main config: `nginx.conf`
- Virtual hosts: `conf.d/*.conf`

To validate nginx configuration:
```bash
./verify-nginx-config.sh
```

## 🔒 Security Best Practices

1. **Secrets Management:**
   - Never commit files in `secrets/` to git
   - Use strong, unique passwords
   - Rotate credentials regularly

2. **SSL/TLS:**
   - Use valid SSL certificates
   - Keep certificates up to date
   - Configure strong cipher suites

3. **Database:**
   - Change default database password
   - Restrict database access to internal network
   - Regular backups

4. **JWT:**
   - Use a strong, random JWT secret
   - Keep access token lifetime short
   - Implement refresh token rotation

## 📊 Monitoring & Health Checks

All services have health checks configured:

- **Database:** SQL query check
- **Pass Converter:** HTTP endpoint check
- **Backend API:** Health endpoint check
- **Frontend:** HTTP availability check
- **Nginx:** HTTPS endpoint check

View health status:
```bash
docker-compose ps
```

## 🗄️ Data Persistence

The following volumes persist data:

- `sqlserver_data`: Database files
- `api_files`: Uploaded files
- `api_logs`: Application logs
- `nginx_cache`: Nginx cache
- `nginx_logs`: Nginx access/error logs

### Backup

Create backup:
```bash
./deploy.sh backup
```

Backups are stored in `backups/YYYYMMDD_HHMMSS/`

### Restore

```bash
# Stop services
./deploy.sh stop

# Restore volume
docker run --rm -v mobile-pass-backend_sqlserver_data:/data \
  -v "$(pwd)/backups/BACKUP_DIR":/backup alpine \
  sh -c "cd /data && tar xzf /backup/sqlserver_data.tar.gz"

# Start services
./deploy.sh deploy
```

## 🐛 Troubleshooting

### Service won't start

```bash
# Check logs
./deploy.sh logs <service>

# Check service status
./deploy.sh status

# Restart service
./deploy.sh update <service>
```

### Database connection issues

```bash
# Check database is running
docker exec pass-generator-db /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "SELECT 1"

# Restart database
docker-compose restart sqlserver
```

### SSL certificate issues

```bash
# Verify nginx config
./verify-nginx-config.sh

# Check certificate expiry
openssl x509 -in certificates/api.itass.cloud/certificate.crt \
  -noout -dates
```

### Network issues

```bash
# Inspect network
docker network inspect pass-generator-network

# Recreate network
docker-compose down
docker network prune
./deploy.sh deploy
```

## 🔄 Updates & Upgrades

### Update a single service

```bash
# Pull latest code
cd ../mobile-pass-backend  # or frontend, pass-converter
git pull

# Return to infrastructure
cd ../mobile-pass-infrastructure

# Update service
./deploy.sh update api  # or frontend, pass-converter
```

### Full system update

```bash
# Pull all repositories
cd ../mobile-pass-backend && git pull && cd -
cd ../mobile-pass-frontend && git pull && cd -
cd ../pass-converter && git pull && cd -

# Redeploy
./deploy.sh deploy
```

## 📚 Additional Resources

- **Frontend Repository:** `../mobile-pass-frontend`
- **Backend Repository:** `../mobile-pass-backend`
- **Pass Converter:** `../pass-converter`
- **Nginx Configuration:** `NGINX-CONFIGURATION.md`
- **Secrets Setup:** `secrets/README.md`

## 🤝 Contributing

1. Make changes in respective service repositories
2. Test locally
3. Update infrastructure configuration if needed
4. Deploy through this infrastructure repository

## 📄 License

Proprietary - Mobile Pass Team
