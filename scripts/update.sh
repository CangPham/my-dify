#!/bin/bash

# Dify Update Script
# Usage: ./update.sh [--force] [--no-backup]

set -e

# Configuration
DIFY_DIR="/opt/dify"
BACKUP_DIR="/opt/backups"
DOCKER_DIR="$DIFY_DIR/docker"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Flags
FORCE_UPDATE=false
SKIP_BACKUP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_UPDATE=true
            shift
            ;;
        --no-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--force] [--no-backup]"
            echo "  --force      Force update without confirmation"
            echo "  --no-backup  Skip backup before update"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "              DIFY UPDATE SCRIPT"
    echo "=================================================="
    echo -e "${NC}"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    if [[ ! -d "$DIFY_DIR" ]]; then
        error "Dify directory not found: $DIFY_DIR"
    fi
    
    if [[ ! -d "$DIFY_DIR/.git" ]]; then
        error "Not a git repository: $DIFY_DIR"
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker not found"
    fi
    
    if ! command -v git &> /dev/null; then
        error "Git not found"
    fi
    
    cd "$DIFY_DIR"
    
    # Check if services are running
    if ! docker compose -f "$DOCKER_DIR/docker-compose.yaml" ps | grep -q "Up"; then
        warn "Some services are not running"
        if [[ "$FORCE_UPDATE" != "true" ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

check_for_updates() {
    log "Checking for updates..."
    
    cd "$DIFY_DIR"
    
    # Fetch latest changes
    git fetch origin
    
    # Check if there are updates
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/main)
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
        log "Already up to date"
        if [[ "$FORCE_UPDATE" != "true" ]]; then
            exit 0
        else
            log "Forcing update anyway..."
        fi
    else
        log "Updates available"
        
        # Show what will be updated
        echo ""
        echo "Changes to be applied:"
        git log --oneline "$local_commit..$remote_commit"
        echo ""
        
        if [[ "$FORCE_UPDATE" != "true" ]]; then
            read -p "Proceed with update? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
        fi
    fi
}

create_backup() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        warn "Skipping backup as requested"
        return
    fi
    
    log "Creating backup before update..."
    
    local backup_name="pre_update_$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "/opt/dify/backup.sh" ]]; then
        /opt/dify/backup.sh "$backup_name"
    else
        # Fallback backup method
        mkdir -p "$BACKUP_DIR"
        
        # Database backup
        cd "$DOCKER_DIR"
        docker compose exec -T db pg_dump -U postgres dify > "$BACKUP_DIR/${backup_name}_database.sql"
        gzip "$BACKUP_DIR/${backup_name}_database.sql"
        
        # Volumes backup
        tar -czf "$BACKUP_DIR/${backup_name}_volumes.tar.gz" volumes/
        
        log "Backup completed: $backup_name"
    fi
}

stop_services() {
    log "Stopping services..."
    
    cd "$DOCKER_DIR"
    
    # Stop services gracefully
    docker compose stop
    
    # Wait for services to stop
    sleep 10
    
    # Force stop if needed
    docker compose down
}

update_code() {
    log "Updating code..."
    
    cd "$DIFY_DIR"
    
    # Stash local changes
    if git diff --quiet && git diff --cached --quiet; then
        info "No local changes to stash"
    else
        log "Stashing local changes..."
        git stash push -m "Auto-stash before update $(date)"
    fi
    
    # Pull latest changes
    git pull origin main
    
    # Restore local changes if any
    if git stash list | grep -q "Auto-stash before update"; then
        log "Restoring local changes..."
        if ! git stash pop; then
            warn "Failed to restore local changes automatically"
            warn "You may need to resolve conflicts manually"
            warn "Use 'git stash list' and 'git stash pop' to restore changes"
        fi
    fi
}

update_dependencies() {
    log "Updating dependencies..."
    
    cd "$DOCKER_DIR"
    
    # Pull latest base images
    docker compose pull
    
    # Rebuild custom images
    docker compose build --no-cache --pull
}

update_configuration() {
    log "Checking configuration updates..."
    
    cd "$DOCKER_DIR"
    
    # Check if .env.example has been updated
    if [[ -f ".env.example" ]] && [[ -f ".env" ]]; then
        # Compare .env with .env.example
        local new_vars=$(comm -13 <(grep -E '^[A-Z_]+=.*' .env | cut -d= -f1 | sort) <(grep -E '^[A-Z_]+=.*' .env.example | cut -d= -f1 | sort))
        
        if [[ -n "$new_vars" ]]; then
            warn "New configuration variables found:"
            echo "$new_vars"
            warn "Please review and update your .env file manually"
        fi
    fi
}

start_services() {
    log "Starting services..."
    
    cd "$DOCKER_DIR"
    
    # Start database and redis first
    docker compose up -d db redis
    
    log "Waiting for database to be ready..."
    sleep 30
    
    # Start all services
    docker compose up -d
    
    log "Waiting for all services to start..."
    sleep 60
}

run_migrations() {
    log "Running database migrations..."
    
    cd "$DOCKER_DIR"
    
    # Wait for API service to be ready
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker compose exec api flask db upgrade 2>/dev/null; then
            log "Database migrations completed"
            return 0
        fi
        
        info "Waiting for API service... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    warn "Database migrations may have failed or API service is not ready"
}

verify_update() {
    log "Verifying update..."
    
    cd "$DOCKER_DIR"
    
    # Check service status
    local failed_services=()
    local services=("api" "web" "dashboard" "db" "redis" "nginx")
    
    for service in "${services[@]}"; do
        if ! docker compose ps "$service" | grep -q "Up"; then
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        error "The following services failed to start: ${failed_services[*]}"
    fi
    
    # Test basic functionality
    sleep 30
    
    local domain="${DIFY_DOMAIN:-localhost}"
    local protocol="http"
    [[ "$domain" != "localhost" ]] && protocol="https"
    
    if curl -f -s "${protocol}://${domain}/api/health" > /dev/null; then
        log "API health check passed"
    else
        warn "API health check failed"
    fi
    
    if curl -f -s "${protocol}://${domain}" > /dev/null; then
        log "Web interface is accessible"
    else
        warn "Web interface may not be ready yet"
    fi
}

cleanup() {
    log "Cleaning up..."
    
    # Remove unused Docker images
    docker image prune -f
    
    # Remove unused volumes (be careful with this)
    # docker volume prune -f
    
    log "Cleanup completed"
}

rollback() {
    error "Update failed. Please check logs and consider manual rollback."
    
    # TODO: Implement automatic rollback
    # This would involve:
    # 1. Stopping services
    # 2. Restoring from backup
    # 3. Starting services
    # 4. Verifying rollback
}

print_summary() {
    echo ""
    echo -e "${GREEN}"
    echo "=================================================="
    echo "            UPDATE COMPLETED!"
    echo "=================================================="
    echo -e "${NC}"
    
    local domain="${DIFY_DOMAIN:-localhost}"
    local protocol="http"
    [[ "$domain" != "localhost" ]] && protocol="https"
    
    echo "🌐 Web Interface: ${protocol}://${domain}"
    echo "📊 Dashboard: ${protocol}://${domain}:8501"
    echo "🔧 API Docs: ${protocol}://${domain}/api/docs"
    echo ""
    echo "📋 Check logs: cd $DOCKER_DIR && docker compose logs -f"
    echo "🔍 Health check: /opt/dify/health-check.sh"
    echo ""
    
    # Show current version/commit
    cd "$DIFY_DIR"
    local current_commit=$(git rev-parse --short HEAD)
    local current_branch=$(git branch --show-current)
    echo "📝 Current version: $current_branch ($current_commit)"
    echo "📅 Updated: $(date)"
}

main() {
    print_header
    
    # Trap errors for rollback
    trap 'rollback' ERR
    
    check_prerequisites
    check_for_updates
    create_backup
    stop_services
    update_code
    update_dependencies
    update_configuration
    start_services
    run_migrations
    verify_update
    cleanup
    
    print_summary
    
    log "Update completed successfully!"
}

# Run main function
main "$@"
