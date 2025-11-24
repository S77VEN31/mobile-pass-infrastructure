#!/bin/bash

# Deployment script for Pass Generator Infrastructure
# This script manages all services from a centralized location

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required secrets exist
check_secrets() {
    log_info "Checking required secrets..."
    
    if [ ! -f "./secrets/google-service-account.json" ]; then
        log_warning "Google Wallet credentials not found (secrets/google-service-account.json)"
        log_warning "Google Wallet conversion will not work without these credentials"
    else
        log_success "Google Wallet credentials found"
    fi
    
    if [ ! -f "./secrets/wwdr.pem" ]; then
        log_warning "Apple WWDR certificate not found (secrets/wwdr.pem)"
        log_warning "PKPass signing may not work without this certificate"
    else
        log_success "Apple WWDR certificate found"
    fi
}

# Build specific service
build_service() {
    local service=$1
    local no_cache=${2:-false}
    log_info "Building $service..."
    if [ "$no_cache" = "true" ]; then
        log_warning "Building without cache (slower but ensures clean build)"
        docker-compose build --no-cache "$service"
    else
        log_info "Building with cache (faster, use --no-cache flag for clean build)"
        DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose build "$service"
    fi
    log_success "$service built successfully"
}

# Deploy all services
deploy_all() {
    log_info "Starting full deployment..."
    
    # Check secrets
    check_secrets
    
    # Pull latest images
    log_info "Pulling latest base images..."
    docker-compose pull sqlserver nginx
    
    # Build custom services with BuildKit for faster builds
    log_info "Building custom services (using BuildKit cache)..."
    DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose build pass-converter pass-converter-huawei api frontend
    
    # Stop old containers
    log_info "Stopping old containers..."
    docker-compose down
    
    # Start services
    log_info "Starting all services..."
    docker-compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be healthy..."
    sleep 10
    
    # Check status
    docker-compose ps
    
    log_success "Deployment completed!"
    log_info "Services available at:"
    log_info "  - Frontend: https://wallet.itass.cloud"
    log_info "  - API: https://wallet.itass.cloud/api"
    log_info "  - Pass Converter (Google): http://localhost:3002"
    log_info "  - Pass Converter (Huawei): http://localhost:3003"
}

# Update specific service
update_service() {
    local service=$1
    log_info "Updating $service..."
    
    # Build the service with BuildKit cache
    DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose build "$service"
    
    # Recreate only that service
    docker-compose up -d --no-deps "$service"
    
    log_success "$service updated successfully"
}

# Show logs
show_logs() {
    local service=$1
    if [ -z "$service" ]; then
        docker-compose logs -f --tail=100
    else
        docker-compose logs -f --tail=100 "$service"
    fi
}

# Stop all services
stop_all() {
    log_info "Stopping all services..."
    docker-compose down
    log_success "All services stopped"
}

# Restart all services
restart_all() {
    log_info "Restarting all services..."
    docker-compose restart
    log_success "All services restarted"
}

# Show status
show_status() {
    log_info "Service Status:"
    docker-compose ps
    echo ""
    log_info "Network Status:"
    docker network inspect pass-generator-network --format='{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}' 2>/dev/null || log_warning "Network not found"
}

# Backup volumes
backup_volumes() {
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    log_info "Creating backup in $backup_dir..."
    
    docker run --rm -v mobile-pass-backend_sqlserver_data:/data -v "$(pwd)/$backup_dir":/backup alpine tar czf /backup/sqlserver_data.tar.gz -C /data .
    docker run --rm -v mobile-pass-backend_files_data:/data -v "$(pwd)/$backup_dir":/backup alpine tar czf /backup/files_data.tar.gz -C /data .
    
    log_success "Backup created at $backup_dir"
}

# Show help
show_help() {
    cat << EOF
Pass Generator Infrastructure Deployment Script

Usage: ./deploy.sh [COMMAND] [OPTIONS]

Commands:
    deploy              Deploy all services
    build <service> [--no-cache]  Build specific service (with cache by default)
    update <service>    Update and restart specific service
    restart             Restart all services
    stop                Stop all services
    status              Show status of all services
    logs [service]      Show logs (all services or specific)
    backup              Backup volumes
    help                Show this help message

Services:
    - sqlserver         SQL Server database
    - pass-converter    Pass converter service (Google Wallet)
    - pass-converter-huawei  Pass converter service (Huawei Wallet)
    - api               Backend API
    - frontend          Next.js frontend
    - nginx             Nginx reverse proxy

Examples:
    ./deploy.sh deploy                 # Full deployment
    ./deploy.sh build api              # Build only API
    ./deploy.sh update frontend        # Update only frontend
    ./deploy.sh logs api               # Show API logs
    ./deploy.sh status                 # Show all services status

EOF
}

# Main script
main() {
    local command=${1:-help}
    local service=$2
    
    case "$command" in
        deploy)
            deploy_all
            ;;
        build)
            if [ -z "$service" ]; then
                log_error "Service name required. Use: ./deploy.sh build <service> [--no-cache]"
                exit 1
            fi
            local no_cache=false
            if [ "$2" = "--no-cache" ] || [ "$3" = "--no-cache" ]; then
                no_cache=true
            fi
            build_service "$service" "$no_cache"
            ;;
        update)
            if [ -z "$service" ]; then
                log_error "Service name required. Use: ./deploy.sh update <service>"
                exit 1
            fi
            update_service "$service"
            ;;
        restart)
            restart_all
            ;;
        stop)
            stop_all
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$service"
            ;;
        backup)
            backup_volumes
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
