#!/bin/bash
# ARIA Automated Backup Script
# Backs up database, n8n workflows, and configuration

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/home/$(whoami)/aria-backups}"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"/{database,workflows,config}

log_info "Starting ARIA backup - $DATE"

# Backup n8n workflows (if n8n API is available)
backup_workflows() {
    log_info "Backing up n8n workflows..."

    if [ -n "$N8N_API_KEY" ] && [ -n "$N8N_URL" ]; then
        curl -s -X GET "$N8N_URL/api/v1/workflows" \
            -H "X-N8N-API-KEY: $N8N_API_KEY" \
            > "$BACKUP_DIR/workflows/n8n_workflows_$DATE.json"
        log_info "Workflows backed up successfully"
    else
        log_warn "N8N_API_KEY or N8N_URL not set, skipping workflow backup"
        # Fallback: copy local workflow files
        if [ -d "$(dirname "$0")/../n8n-workflows" ]; then
            cp -r "$(dirname "$0")/../n8n-workflows" "$BACKUP_DIR/workflows/local_$DATE"
            log_info "Local workflow files copied"
        fi
    fi
}

# Backup Supabase database
backup_database() {
    log_info "Backing up database..."

    if [ -n "$SUPABASE_DB_URL" ]; then
        pg_dump "$SUPABASE_DB_URL" > "$BACKUP_DIR/database/aria_db_$DATE.sql"
        gzip "$BACKUP_DIR/database/aria_db_$DATE.sql"
        log_info "Database backed up successfully"
    else
        log_warn "SUPABASE_DB_URL not set, skipping database backup"
    fi
}

# Backup configuration files (excluding secrets)
backup_config() {
    log_info "Backing up configuration..."

    SCRIPT_DIR="$(dirname "$0")"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

    # Backup non-secret config files
    tar -czf "$BACKUP_DIR/config/config_$DATE.tar.gz" \
        -C "$PROJECT_DIR" \
        --exclude='.env' \
        --exclude='.env.local' \
        --exclude='node_modules' \
        --exclude='dist' \
        docker-compose.yml \
        .env.example \
        2>/dev/null || true

    log_info "Configuration backed up successfully"
}

# Clean old backups
cleanup_old_backups() {
    log_info "Cleaning backups older than $RETENTION_DAYS days..."

    find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

    log_info "Cleanup complete"
}

# Main execution
main() {
    backup_workflows
    backup_database
    backup_config
    cleanup_old_backups

    log_info "Backup complete! Files saved to $BACKUP_DIR"

    # List backup sizes
    echo ""
    log_info "Backup summary:"
    du -sh "$BACKUP_DIR"/* 2>/dev/null || true
}

main "$@"
