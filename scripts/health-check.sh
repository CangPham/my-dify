#!/bin/bash

# Dify Health Check Script
# Usage: ./health-check.sh [--verbose] [--alert]

set -e

# Configuration
DIFY_DIR="/opt/dify/docker"
LOG_FILE="/var/log/dify/health.log"
WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
EMAIL_TO="${ALERT_EMAIL:-}"

# Thresholds
DISK_THRESHOLD=80
MEMORY_THRESHOLD=80
CPU_THRESHOLD=80
RESPONSE_TIME_THRESHOLD=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Flags
VERBOSE=false
ALERT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --alert|-a)
            ALERT=true
            shift
            ;;
        *)
            echo "Usage: $0 [--verbose] [--alert]"
            exit 1
            ;;
    esac
done

log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

warn() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

error() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

info() {
    if [[ "$VERBOSE" == "true" ]]; then
        local message="[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
        echo -e "${BLUE}$message${NC}"
        echo "$message" >> "$LOG_FILE"
    fi
}

send_alert() {
    local message="$1"
    local severity="${2:-WARNING}"
    
    if [[ "$ALERT" != "true" ]]; then
        return
    fi
    
    # Send to Slack
    if [[ -n "$WEBHOOK_URL" ]]; then
        local emoji="⚠️"
        [[ "$severity" == "ERROR" ]] && emoji="🚨"
        [[ "$severity" == "OK" ]] && emoji="✅"
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$emoji Dify Health Check: $message\"}" \
            "$WEBHOOK_URL" 2>/dev/null || warn "Failed to send Slack notification"
    fi
    
    # Send email (requires mailutils)
    if [[ -n "$EMAIL_TO" ]] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Dify Health Check Alert" "$EMAIL_TO" 2>/dev/null || warn "Failed to send email notification"
    fi
}

check_prerequisites() {
    info "Checking prerequisites..."
    
    if [[ ! -d "$DIFY_DIR" ]]; then
        error "Dify directory not found: $DIFY_DIR"
        return 1
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker not found"
        return 1
    fi
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    return 0
}

check_docker_service() {
    info "Checking Docker service..."
    
    if ! systemctl is-active --quiet docker; then
        error "Docker service is not running"
        send_alert "Docker service is not running" "ERROR"
        return 1
    fi
    
    log "✓ Docker service is running"
    return 0
}

check_container_status() {
    local service_name="$1"
    local container_name="${2:-$service_name}"
    
    cd "$DIFY_DIR"
    
    if docker compose ps "$service_name" | grep -q "Up"; then
        log "✓ $service_name is running"
        return 0
    else
        error "$service_name is down"
        send_alert "$service_name service is down" "ERROR"
        
        # Try to restart the service
        info "Attempting to restart $service_name..."
        if docker compose restart "$service_name"; then
            sleep 10
            if docker compose ps "$service_name" | grep -q "Up"; then
                log "✓ $service_name restarted successfully"
                send_alert "$service_name service restarted successfully" "OK"
                return 0
            fi
        fi
        
        return 1
    fi
}

check_container_health() {
    local service_name="$1"
    
    cd "$DIFY_DIR"
    
    local container_id=$(docker compose ps -q "$service_name")
    if [[ -z "$container_id" ]]; then
        return 1
    fi
    
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "none")
    
    case "$health_status" in
        "healthy")
            info "✓ $service_name health check: healthy"
            return 0
            ;;
        "unhealthy")
            warn "$service_name health check: unhealthy"
            return 1
            ;;
        "starting")
            info "$service_name health check: starting"
            return 0
            ;;
        "none")
            info "$service_name: no health check configured"
            return 0
            ;;
        *)
            warn "$service_name health check: unknown status ($health_status)"
            return 1
            ;;
    esac
}

check_url_response() {
    local url="$1"
    local service_name="$2"
    local expected_code="${3:-200}"
    local timeout="${4:-10}"
    
    info "Checking URL: $url"
    
    local start_time=$(date +%s.%N)
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" -k "$url" --max-time "$timeout" 2>/dev/null || echo "000")
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    if [[ "$response_code" == "$expected_code" ]]; then
        log "✓ $service_name URL check passed ($response_code) - ${response_time}s"
        
        # Check response time
        if (( $(echo "$response_time > $RESPONSE_TIME_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
            warn "$service_name response time is slow: ${response_time}s (threshold: ${RESPONSE_TIME_THRESHOLD}s)"
            send_alert "$service_name response time is slow: ${response_time}s" "WARNING"
        fi
        
        return 0
    else
        error "$service_name URL check failed ($response_code)"
        send_alert "$service_name URL check failed with code $response_code" "ERROR"
        return 1
    fi
}

check_disk_space() {
    info "Checking disk space..."
    
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    local available=$(df -h / | awk 'NR==2 {print $4}')
    
    if [[ "$usage" -lt "$DISK_THRESHOLD" ]]; then
        log "✓ Disk usage: ${usage}% (${available} available)"
        return 0
    else
        error "High disk usage: ${usage}% (threshold: ${DISK_THRESHOLD}%)"
        send_alert "High disk usage: ${usage}% (only ${available} available)" "ERROR"
        return 1
    fi
}

check_memory_usage() {
    info "Checking memory usage..."
    
    local usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    local available=$(free -h | awk 'NR==2{print $7}')
    
    if [[ "$usage" -lt "$MEMORY_THRESHOLD" ]]; then
        log "✓ Memory usage: ${usage}% (${available} available)"
        return 0
    else
        warn "High memory usage: ${usage}% (threshold: ${MEMORY_THRESHOLD}%)"
        send_alert "High memory usage: ${usage}% (only ${available} available)" "WARNING"
        return 1
    fi
}

check_cpu_usage() {
    info "Checking CPU usage..."
    
    local usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    
    if (( $(echo "$usage < $CPU_THRESHOLD" | bc -l 2>/dev/null || echo 1) )); then
        log "✓ CPU usage: ${usage}%"
        return 0
    else
        warn "High CPU usage: ${usage}% (threshold: ${CPU_THRESHOLD}%)"
        send_alert "High CPU usage: ${usage}%" "WARNING"
        return 1
    fi
}

check_database_connections() {
    info "Checking database connections..."
    
    cd "$DIFY_DIR"
    
    local connections=$(docker compose exec -T db psql -U postgres -d dify -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | grep -E "^\s*[0-9]+\s*$" | tr -d ' ' || echo "0")
    local max_connections=$(docker compose exec -T db psql -U postgres -d dify -c "SHOW max_connections;" 2>/dev/null | grep -E "^\s*[0-9]+\s*$" | tr -d ' ' || echo "100")
    
    if [[ "$connections" -gt 0 ]] && [[ "$max_connections" -gt 0 ]]; then
        local usage_percent=$(( connections * 100 / max_connections ))
        
        if [[ "$usage_percent" -lt 80 ]]; then
            log "✓ Database connections: $connections/$max_connections (${usage_percent}%)"
            return 0
        else
            warn "High database connection usage: $connections/$max_connections (${usage_percent}%)"
            send_alert "High database connection usage: $connections/$max_connections" "WARNING"
            return 1
        fi
    else
        warn "Could not check database connections"
        return 1
    fi
}

check_redis_memory() {
    info "Checking Redis memory usage..."
    
    cd "$DIFY_DIR"
    
    local redis_info=$(docker compose exec -T redis redis-cli info memory 2>/dev/null || echo "")
    
    if [[ -n "$redis_info" ]]; then
        local used_memory=$(echo "$redis_info" | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r')
        local max_memory=$(echo "$redis_info" | grep "maxmemory_human:" | cut -d: -f2 | tr -d '\r')
        
        log "✓ Redis memory usage: $used_memory"
        [[ -n "$max_memory" ]] && info "Redis max memory: $max_memory"
        return 0
    else
        warn "Could not check Redis memory usage"
        return 1
    fi
}

generate_report() {
    local failed_checks="$1"
    local total_checks="$2"
    
    echo ""
    echo "=================================="
    echo "     HEALTH CHECK SUMMARY"
    echo "=================================="
    echo "Timestamp: $(date)"
    echo "Total Checks: $total_checks"
    echo "Failed Checks: $failed_checks"
    echo "Success Rate: $(( (total_checks - failed_checks) * 100 / total_checks ))%"
    echo ""
    
    if [[ "$failed_checks" -eq 0 ]]; then
        echo -e "${GREEN}✅ All health checks passed!${NC}"
    else
        echo -e "${RED}❌ $failed_checks health check(s) failed!${NC}"
    fi
    
    echo ""
    echo "Log file: $LOG_FILE"
    echo "=================================="
}

main() {
    log "Starting Dify health check..."
    
    local failed_checks=0
    local total_checks=0
    
    # Prerequisites
    check_prerequisites || ((failed_checks++))
    ((total_checks++))
    
    # Docker service
    check_docker_service || ((failed_checks++))
    ((total_checks++))
    
    # Container status checks
    local services=("api" "web" "dashboard" "db" "redis" "nginx")
    for service in "${services[@]}"; do
        check_container_status "$service" || ((failed_checks++))
        check_container_health "$service" || ((failed_checks++))
        ((total_checks += 2))
    done
    
    # URL checks (replace with your actual domain)
    local domain="${DIFY_DOMAIN:-localhost}"
    local protocol="http"
    [[ "$domain" != "localhost" ]] && protocol="https"
    
    local urls=(
        "${protocol}://${domain}|Web Interface"
        "${protocol}://${domain}/api/health|API Health"
        "${protocol}://${domain}:8501|Dashboard"
    )
    
    for url_info in "${urls[@]}"; do
        IFS='|' read -r url name <<< "$url_info"
        check_url_response "$url" "$name" || ((failed_checks++))
        ((total_checks++))
    done
    
    # System resource checks
    check_disk_space || ((failed_checks++))
    ((total_checks++))
    
    check_memory_usage || ((failed_checks++))
    ((total_checks++))
    
    check_cpu_usage || ((failed_checks++))
    ((total_checks++))
    
    # Service-specific checks
    check_database_connections || ((failed_checks++))
    ((total_checks++))
    
    check_redis_memory || ((failed_checks++))
    ((total_checks++))
    
    # Generate report
    generate_report "$failed_checks" "$total_checks"
    
    # Send summary alert if there are failures
    if [[ "$failed_checks" -gt 0 ]]; then
        send_alert "$failed_checks out of $total_checks health checks failed" "ERROR"
        exit 1
    else
        log "All health checks completed successfully"
        exit 0
    fi
}

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Run main function
main "$@"
