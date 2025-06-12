#!/bin/bash

# Dify Backup Script
# Usage: ./backup.sh [backup_name]

set -e

# Configuration
DIFY_DIR="/opt/dify/docker"
BACKUP_DIR="/opt/backups"
BACKUP_NAME=${1:-"auto_$(date +%Y%m%d_%H%M%S)"}
RETENTION_DAYS=7

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

check_prerequisites() {
    log "Checking prerequisites..."
    
    if [[ ! -d "$DIFY_DIR" ]]; then
        error "Dify directory not found: $DIFY_DIR"
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker not found"
    fi
    
    if ! docker compose -f "$DIFY_DIR/docker-compose.yaml" ps db | grep -q "Up"; then
        error "Database container is not running"
    fi
    
    mkdir -p "$BACKUP_DIR"
}

backup_database() {
    log "Backing up database..."
    
    local db_backup_file="$BACKUP_DIR/${BACKUP_NAME}_database.sql"
    
    cd "$DIFY_DIR"
    
    # Create database backup
    if docker compose exec -T db pg_dump -U postgres dify > "$db_backup_file"; then
        log "Database backup completed: $db_backup_file"
        
        # Compress the backup
        gzip "$db_backup_file"
        log "Database backup compressed: ${db_backup_file}.gz"
    else
        error "Database backup failed"
    fi
}

backup_volumes() {
    log "Backing up volumes..."
    
    local volumes_backup_file="$BACKUP_DIR/${BACKUP_NAME}_volumes.tar.gz"
    
    cd "$DIFY_DIR"
    
    # Create volumes backup
    if tar -czf "$volumes_backup_file" volumes/; then
        log "Volumes backup completed: $volumes_backup_file"
    else
        error "Volumes backup failed"
    fi
}

backup_configuration() {
    log "Backing up configuration..."
    
    local config_backup_file="$BACKUP_DIR/${BACKUP_NAME}_config.tar.gz"
    
    cd "$DIFY_DIR"
    
    # Backup configuration files
    if tar -czf "$config_backup_file" \
        .env \
        docker-compose.yaml \
        nginx/ \
        2>/dev/null; then
        log "Configuration backup completed: $config_backup_file"
    else
        warn "Some configuration files may not exist"
    fi
}

backup_custom_code() {
    log "Backing up custom code..."
    
    local code_backup_file="$BACKUP_DIR/${BACKUP_NAME}_custom_code.tar.gz"
    
    cd "/opt/dify"
    
    # Backup custom modifications (if any)
    if tar -czf "$code_backup_file" \
        --exclude='.git' \
        --exclude='docker/volumes' \
        --exclude='node_modules' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        . 2>/dev/null; then
        log "Custom code backup completed: $code_backup_file"
    else
        warn "Custom code backup may be incomplete"
    fi
}

create_backup_manifest() {
    log "Creating backup manifest..."
    
    local manifest_file="$BACKUP_DIR/${BACKUP_NAME}_manifest.txt"
    
    cat > "$manifest_file" << EOF
Dify Backup Manifest
====================
Backup Name: $BACKUP_NAME
Created: $(date)
Hostname: $(hostname)
Dify Directory: $DIFY_DIR

Files Included:
EOF
    
    # List backup files
    ls -la "$BACKUP_DIR"/${BACKUP_NAME}_* >> "$manifest_file"
    
    # Add system info
    cat >> "$manifest_file" << EOF

System Information:
==================
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Docker Version: $(docker --version)
Docker Compose Version: $(docker compose version)

Docker Services Status:
======================
EOF
    
    cd "$DIFY_DIR"
    docker compose ps >> "$manifest_file"
    
    log "Backup manifest created: $manifest_file"
}

verify_backup() {
    log "Verifying backup integrity..."
    
    local backup_files=(
        "${BACKUP_DIR}/${BACKUP_NAME}_database.sql.gz"
        "${BACKUP_DIR}/${BACKUP_NAME}_volumes.tar.gz"
        "${BACKUP_DIR}/${BACKUP_NAME}_config.tar.gz"
        "${BACKUP_DIR}/${BACKUP_NAME}_custom_code.tar.gz"
    )
    
    local verification_failed=false
    
    for file in "${backup_files[@]}"; do
        if [[ -f "$file" ]]; then
            # Test archive integrity
            case "$file" in
                *.gz)
                    if file "$file" | grep -q "gzip compressed"; then
                        if [[ "$file" == *".sql.gz" ]]; then
                            # Test SQL backup
                            if zcat "$file" | head -n 10 | grep -q "PostgreSQL database dump"; then
                                log "✓ $file - OK"
                            else
                                warn "✗ $file - Invalid SQL backup"
                                verification_failed=true
                            fi
                        elif [[ "$file" == *".tar.gz" ]]; then
                            # Test tar archive
                            if tar -tzf "$file" >/dev/null 2>&1; then
                                log "✓ $file - OK"
                            else
                                warn "✗ $file - Corrupted archive"
                                verification_failed=true
                            fi
                        fi
                    else
                        warn "✗ $file - Not a valid gzip file"
                        verification_failed=true
                    fi
                    ;;
            esac
        else
            warn "✗ $file - File not found"
            verification_failed=true
        fi
    done
    
    if [[ "$verification_failed" == "true" ]]; then
        error "Backup verification failed"
    else
        log "All backup files verified successfully"
    fi
}

cleanup_old_backups() {
    log "Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
    
    # Find and delete old backup files
    find "$BACKUP_DIR" -name "auto_*" -type f -mtime +$RETENTION_DAYS -delete
    
    # Count remaining backups
    local backup_count=$(find "$BACKUP_DIR" -name "auto_*" -type f | wc -l)
    log "Cleanup completed. $backup_count backup files remaining."
}

calculate_backup_size() {
    local total_size=$(du -sh "$BACKUP_DIR"/${BACKUP_NAME}_* 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")
    log "Total backup size: $(du -sh "$BACKUP_DIR"/${BACKUP_NAME}_* 2>/dev/null | awk '{total+=$1} END {print total "M"}' || echo "Unknown")"
}

send_notification() {
    # Optional: Send notification (Slack, email, etc.)
    local webhook_url="${SLACK_WEBHOOK_URL:-}"
    
    if [[ -n "$webhook_url" ]]; then
        local message="✅ Dify backup completed successfully: $BACKUP_NAME"
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$webhook_url" 2>/dev/null || warn "Failed to send notification"
    fi
}

main() {
    log "Starting Dify backup process..."
    log "Backup name: $BACKUP_NAME"
    
    check_prerequisites
    backup_database
    backup_volumes
    backup_configuration
    backup_custom_code
    create_backup_manifest
    verify_backup
    calculate_backup_size
    cleanup_old_backups
    send_notification
    
    log "Backup process completed successfully!"
    log "Backup location: $BACKUP_DIR"
    
    # List created files
    echo ""
    echo "Created backup files:"
    ls -la "$BACKUP_DIR"/${BACKUP_NAME}_*
}

# Handle script interruption
trap 'error "Backup interrupted"' INT TERM

# Run main function
main "$@"
