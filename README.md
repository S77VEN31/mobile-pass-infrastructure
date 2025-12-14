# Mobile Pass Infrastructure

## Overview

Mobile Pass Infrastructure is a Docker Compose-based orchestration system that manages the deployment and networking of a multi-platform mobile wallet pass generator. This infrastructure project provides centralized deployment, SSL termination, load balancing, and security features for generating digital wallet passes compatible with Apple Wallet, Google Wallet, and Huawei Wallet.

The main goal is to provide a production-ready, containerized environment that coordinates multiple microservices required for wallet pass generation, including backend APIs, frontend interfaces, and platform-specific pass conversion services.

## Features

- **Multi-platform Pass Generation**: Supports Apple Wallet (PKPass), Google Wallet, and Huawei Wallet pass formats
- **SSL/TLS Termination**: Secure HTTPS connections handled by Nginx reverse proxy
- **Rate Limiting**: API endpoint protection with configurable rate limits for authentication and general API routes
- **Health Checks**: Automated health monitoring for all services with Docker healthcheck configurations
- **Security Headers**: Comprehensive security headers including HSTS, XSS protection, frame options, and content type protection
- **Centralized Deployment**: Single deployment script (`deploy.sh`) for managing all services
- **Service Isolation**: Docker network isolation with dedicated network for inter-service communication
- **Volume Management**: Persistent storage for application files, logs, and certificates
- **Proxy Caching**: Nginx caching configuration for improved performance
- **Gzip Compression**: Automatic compression for text-based responses

## Project Structure

```
mobile-pass-infrastructure/
├── docker-compose.yml          # Main Docker Compose orchestration file
├── nginx.conf                   # Nginx main configuration (worker processes, logging, gzip, caching)
├── deploy.sh                    # Deployment automation script
├── .gitignore                   # Git ignore rules (certificates, logs, env files)
└── conf.d/                      # Nginx server configuration directory
    ├── pass-generator.conf      # Server blocks for frontend and API routing
    ├── common-proxy-headers.conf    # Standard proxy headers configuration
    ├── common-security-headers.conf # Security headers (HSTS, XSS, etc.)
    └── common-ssl.conf          # SSL/TLS protocol and cipher configuration
```

### Key Files

- **`docker-compose.yml`**: Defines all services (API, frontend, pass converters, nginx), their dependencies, environment variables, volumes, networks, and health checks
- **`nginx.conf`**: Main Nginx configuration including worker processes, logging formats, gzip settings, rate limiting zones, and proxy cache configuration
- **`conf.d/pass-generator.conf`**: Server blocks for `mobilepass.itass.cloud` (frontend) and `wallet.itass.cloud` (API), including SSL configuration and routing rules
- **`deploy.sh`**: Bash script providing commands for deployment, building, updating, logging, and managing services
- **`certificates/`**: Directory containing SSL certificates and wallet signing keys (excluded from git)

## Technologies Used

- **Docker & Docker Compose**: Container orchestration and service management
- **Nginx**: Reverse proxy, SSL termination, load balancing, and caching
- **Node.js**: Runtime for backend API and pass converter services
- **Next.js**: React framework for the frontend application
- **SQL Server**: External database (not containerized in this infrastructure)
- **Bash**: Deployment automation scripting

## Installation

### Prerequisites

- Docker Engine (version 20.10 or later)
- Docker Compose (version 1.29 or later)
- Bash shell
- SSL certificates and wallet signing certificates (see Configuration section)

### Setup Steps

1. **Clone the repository** (if not already cloned):
   ```bash
   git clone <repository-url>
   cd mobile-pass-infrastructure
   ```

2. **Create required Docker network**:
   ```bash
   docker network create mobile-pass-backend_pass-generator-network
   ```

3. **Create required Docker volumes**:
   ```bash
   docker volume create mobile-pass-backend_files_data
   ```

4. **Prepare certificates directory**:
   ```bash
   mkdir -p certificates/{google,apple,huawei,api.itass.cloud}
   ```
   
   Place the following certificates in their respective directories:
   - `certificates/google/google-service-account.json` - Google Wallet service account credentials
   - `certificates/apple/wwdr.pem` - Apple WWDR certificate
   - `certificates/apple/AuthKey_*.p8` - Apple APNS key files
   - `certificates/huawei/private-key.pem` - Huawei signing private key
   - `certificates/huawei/certificate.cer` - Huawei signing certificate
   - `certificates/api.itass.cloud/certificate.crt` - SSL certificate
   - `certificates/api.itass.cloud/private.key` - SSL private key

5. **Configure environment variables** (optional):
   
   Create a `.env` file or set environment variables for customization. See Configuration section for available variables.

6. **Make deploy script executable**:
   ```bash
   chmod +x deploy.sh
   ```

## Usage

### Full Deployment

Deploy all services with a single command:

```bash
./deploy.sh deploy
```

This will:
- Check for required certificates
- Pull latest base images (nginx)
- Build custom services (pass-converter, pass-converter-huawei, api, frontend)
- Stop old containers
- Start all services
- Display service status

**Note**: The deployment script may reference services not present in docker-compose.yml (e.g., sqlserver). Only services defined in docker-compose.yml will be deployed.

### Individual Service Management

**Build a specific service**:
```bash
./deploy.sh build <service-name> [--no-cache]
```

Example:
```bash
./deploy.sh build api
./deploy.sh build frontend --no-cache  # Force clean build
```

**Update a specific service**:
```bash
./deploy.sh update <service-name>
```

Example:
```bash
./deploy.sh update frontend
```

**View logs**:
```bash
./deploy.sh logs              # All services
./deploy.sh logs api          # Specific service
```

**Check service status**:
```bash
./deploy.sh status
```

**Restart all services**:
```bash
./deploy.sh restart
```

**Stop all services**:
```bash
./deploy.sh stop
```

**Backup volumes**:
```bash
./deploy.sh backup
```

### Available Services

- `pass-converter` - Google Wallet pass converter (port 3002)
- `pass-converter-huawei` - Huawei Wallet pass converter (port 3003)
- `api` - Backend API service (port 3001)
- `frontend` - Next.js frontend application (port 3000)
- `nginx` - Reverse proxy (ports 80, 443)

### Direct Docker Compose Usage

You can also use Docker Compose directly:

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f

# Rebuild and restart a service
docker-compose up -d --build <service-name>
```

## Configuration

### Environment Variables

The following environment variables can be configured via `.env` file or system environment:

#### General
- `NODE_ENV` - Node.js environment (default: `production`)

#### Pass Converter (Google)
- `PASS_CONVERTER_BIND_HOST` - Bind host (default: `0.0.0.0`)
- `PASS_CONVERTER_BIND_PORT` - Bind port (default: `3002`)

#### Pass Converter (Huawei)
- `HUAWEI_CONVERTER_BIND_HOST` - Bind host (default: `0.0.0.0`)
- `HUAWEI_CONVERTER_BIND_PORT` - Bind port (default: `3003`)
- `HUAWEI_PASS_SIGNING_KEY_PATH` - Path to Huawei signing key (default: `/app/certs/huawei/private-key.pem`)
- `HUAWEI_PASS_SIGNING_CERT_PATH` - Path to Huawei certificate (default: `/app/certs/huawei/certificate.cer`)

#### Backend API
- `PORT` - API port (default: `3001`)
- `DB_SERVER` - SQL Server host (default: `10.56.220.233`)
- `DB_PORT` - SQL Server port (default: `1433`)
- `DB_NAME` - Database name (default: `MobilePass`)
- `DB_USER` - Database user (default: `mobilepass`)
- `DB_PASSWORD` - Database password
- `DB_ENCRYPT` - Enable encryption (default: `true`)
- `DB_TRUST_SERVER_CERTIFICATE` - Trust server certificate (default: `true`)
- `JWT_SECRET` - JWT signing secret
- `JWT_EXPIRES_IN` - JWT expiration (default: `24h`)
- `JWT_REFRESH_EXPIRES_IN` - Refresh token expiration (default: `7d`)
- `CORS_ORIGIN` - Allowed CORS origins (comma-separated)
- `GOOGLE_SERVICE_ACCOUNT_PATH` - Google service account JSON path
- `GOOGLE_ISSUER_ID` - Google Wallet issuer ID
- `GOOGLE_STORAGE_BUCKET` - Google Cloud Storage bucket
- `IMAGE_HOST_URL` - Image hosting URL
- `DEFAULT_ORG_NAME` - Default organization name
- `PASS_CONVERTER_URL` - Google pass converter URL (default: `http://pass-converter:3002`)
- `HUAWEI_APP_ID` - Huawei App ID
- `HUAWEI_APP_SECRET` - Huawei App secret
- `HUAWEI_ISSUER_ID` - Huawei issuer ID
- `HUAWEI_PASS_CONVERTER_URL` - Huawei pass converter URL (default: `http://pass-converter-huawei:3003`)
- `APNS_KEY_PATH` - Apple APNS key file path
- `APNS_KEY_ID` - Apple APNS key ID
- `APNS_TEAM_ID` - Apple team ID
- `APNS_PRODUCTION` - Use production APNS (default: `true`)

#### Frontend
- `NEXT_PUBLIC_API_URL` - Public API URL (default: `https://wallet.itass.cloud/api`)
- `NEXT_PUBLIC_API_TIMEOUT` - API timeout in ms (default: `30000`)
- `NEXT_PUBLIC_APP_NAME` - Application name (default: `Pass Generator`)
- `NEXT_PUBLIC_APP_VERSION` - Application version (default: `1.0.0`)
- `NEXT_PUBLIC_APP_DESCRIPTION` - Application description
- `FRONTEND_API_URL` - Internal API URL for frontend (default: `http://pass-generator-api:3001/api`)

### Certificate Requirements

The following certificates must be placed in the `certificates/` directory:

**SSL Certificates**:
- `certificates/api.itass.cloud/certificate.crt` - SSL certificate
- `certificates/api.itass.cloud/private.key` - SSL private key

**Google Wallet**:
- `certificates/google/google-service-account.json` - Google Cloud service account JSON

**Apple Wallet**:
- `certificates/apple/wwdr.pem` - Apple WWDR intermediate certificate
- `certificates/apple/AuthKey_*.p8` - Apple APNS authentication keys

**Huawei Wallet**:
- `certificates/huawei/private-key.pem` - Huawei signing private key
- `certificates/huawei/certificate.cer` - Huawei signing certificate

### Network Configuration

- **Network Name**: `mobile-pass-backend_pass-generator-network` (external network, must be created separately)
- **Service Communication**: Services communicate via service names (e.g., `http://api:3001`)

### Port Mappings

- **80**: HTTP (redirects to HTTPS)
- **443**: HTTPS (Nginx)
- **3000**: Frontend (internal)
- **3001**: API (internal)
- **3002**: Pass Converter - Google (exposed)
- **3003**: Pass Converter - Huawei (exposed)

### Volume Mounts

- `api_logs` - API application logs
- `api_files` - API file storage (external volume: `mobile-pass-backend_files_data`)
- `nginx_cache` - Nginx proxy cache
- `nginx_logs` - Nginx access and error logs

## Architecture / Design Notes

### Service Architecture

The infrastructure follows a microservices architecture with the following components:

```
┌─────────────────┐
│   Internet      │
└────────┬────────┘
         │ HTTPS (443)
         │
┌────────▼─────────────────────────────────────┐
│            Nginx Reverse Proxy                │
│  - SSL Termination                           │
│  - Rate Limiting                             │
│  - Security Headers                           │
│  - Request Routing                           │
└─────┬───────────────────┬─────────────────────┘
      │                   │
      │                   │
┌─────▼─────┐    ┌────────▼────────┐
│ Frontend  │    │   Backend API   │
│ (Next.js) │    │   (Node.js)     │
│ Port 3000 │    │   Port 3001     │
└───────────┘    └─────┬──────┬────┘
                       │      │
            ┌──────────┘      └──────────┐
            │                             │
    ┌───────▼────────┐          ┌────────▼────────┐
    │ Pass Converter │          │ Pass Converter   │
    │   (Google)     │          │   (Huawei)       │
    │   Port 3002    │          │   Port 3003      │
    └────────────────┘          └──────────────────┘
```

### Request Flow

1. **Client Request**: HTTPS request arrives at Nginx (port 443)
2. **SSL Termination**: Nginx terminates SSL/TLS connection
3. **Routing**: Nginx routes requests based on domain and path:
   - `mobilepass.itass.cloud/` → Frontend service (port 3000)
   - `wallet.itass.cloud/api/*` → API service (port 3001)
   - `wallet.itass.cloud/` → API service root (port 3001)
4. **Rate Limiting**: API routes are protected by rate limiting zones:
   - `/api/auth` - 5 requests/second (burst: 5)
   - `/api/*` - 10 requests/second (burst: 20)
5. **Service Processing**: Backend services process requests and may call pass converters
6. **Response**: Response flows back through Nginx to client

### Service Dependencies

- **API** depends on: `pass-converter`, `pass-converter-huawei`
- **Frontend** depends on: `api` (waits for healthy status)
- **Nginx** depends on: `frontend`, `api` (waits for healthy status)

### Health Checks

All services implement health check endpoints:
- **API**: `http://localhost:3001/health`
- **Pass Converter (Google)**: `http://localhost:3002/health`
- **Pass Converter (Huawei)**: `http://localhost:3003/health`
- **Frontend**: `http://localhost:3000/`
- **Nginx**: `https://127.0.0.1:443/health`

Health checks run every 30 seconds with appropriate timeouts and retry counts.

### Security Features

- **SSL/TLS**: TLS 1.2 and 1.3 only, strong cipher suites
- **Security Headers**: HSTS, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy
- **Rate Limiting**: Per-IP rate limiting on API endpoints
- **Certificate Mounting**: Certificates mounted as read-only volumes
- **Network Isolation**: Services communicate via isolated Docker network

### Nginx Configuration

- **Worker Processes**: Auto-detected based on CPU cores
- **Gzip Compression**: Enabled for text-based content types
- **Proxy Caching**: 10GB cache with 60-minute inactive timeout
- **Client Body Size**: Limited to 50MB
- **Keepalive Timeout**: 65 seconds

## Development Notes

### Building Services

Services are built using Docker BuildKit for improved caching and performance:

```bash
DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose build <service>
```

### Health Check Endpoints

All services expose health check endpoints that return HTTP 200 when healthy. These are used by Docker health checks and can be accessed directly for monitoring.

### Log Locations

- **Nginx Access Logs**: `/var/log/nginx/access.log` and `/var/log/nginx/frontend-access.log`, `/var/log/nginx/backend-access.log`
- **Nginx Error Logs**: `/var/log/nginx/error.log` and service-specific error logs
- **API Logs**: Mounted in `api_logs` volume, accessible at `/app/logs` in container

### Certificate Management

- Certificates are stored in the `certificates/` directory (gitignored)
- Certificates are mounted as read-only volumes into containers
- Certificate paths are configurable via environment variables
- The deployment script checks for required certificates and warns if missing

### Service Updates

To update a service without affecting others:

1. Make code changes in the respective service repository
2. Use `./deploy.sh update <service-name>` to rebuild and restart only that service
3. The `--no-deps` flag ensures dependencies are not rebuilt

### Network and Volume Prerequisites

Before deployment, ensure:
- Docker network `mobile-pass-backend_pass-generator-network` exists
- Docker volume `mobile-pass-backend_files_data` exists (if using persistent file storage)

Create them manually if needed:
```bash
docker network create mobile-pass-backend_pass-generator-network
docker volume create mobile-pass-backend_files_data
```

## Known Limitations

- **External Dependencies**: Requires external SQL Server database that is not managed by this infrastructure
- **Certificate Management**: Certificates must be manually placed in the `certificates/` directory; no automatic certificate provisioning or renewal
- **Network and Volumes**: Docker network and volumes must be created externally before deployment
- **Environment Variables**: No `.env` file support by default; environment variables must be set in shell or docker-compose override files
- **Single Host Deployment**: Designed for single-host deployment; multi-host deployment would require additional orchestration
- **No Load Balancing**: Nginx acts as reverse proxy but doesn't load balance multiple instances of services
- **Certificate Paths**: Some certificate paths are hardcoded in docker-compose.yml and may need adjustment for different deployment scenarios

## Future Improvements

- **Environment File Support**: Add `.env` file parsing in docker-compose.yml for easier configuration management
- **Certificate Auto-Renewal**: Integrate Let's Encrypt or similar for automatic SSL certificate renewal
- **Monitoring Integration**: Add Prometheus, Grafana, or similar monitoring solutions
- **CI/CD Pipeline**: Integrate with CI/CD systems for automated builds and deployments
- **Multi-Instance Support**: Add load balancing configuration for scaling services horizontally
- **Secrets Management**: Integrate with Docker Secrets or external secrets management systems
- **Backup Automation**: Schedule automatic volume backups
- **Health Check Dashboard**: Create a dashboard to visualize service health status
- **Configuration Validation**: Add pre-deployment validation for required certificates and environment variables
- **Documentation**: Add API documentation and service-specific configuration guides

## License

License information is not specified in the repository. Please consult with the project maintainers for licensing details.
