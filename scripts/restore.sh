#!/bin/bash
# ARIA Disaster Recovery Script
# Restores database, workflows, and configuration from backups

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "ARIA Restore Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --database FILE     Restore database from SQL file"
    echo "  --workflows FILE    Restore n8n workflows from JSON file"
    echo "  --config FILE       Restore configuration from tar.gz"
    echo "  --full DIR          Full restore from backup directory"
    echo "  --list              List available backups"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --database /path/to/backup.sql.gz"
    echo "  $0 --workflows /path/to/workflows.json"
    echo "  $0 --full /path/to/backup/dir"
}

list_backups() {
    BACKUP_DIR="${BACKUP_DIR:-/home/$(whoami)/aria-backups}"

    log_info "Available backups in $BACKUP_DIR:"
    echo ""

    echo "Database backups:"
    ls -la "$BACKUP_DIR/database/" 2>/dev/null || echo "  (none found)"
    echo ""

    echo "Workflow backups:"
    ls -la "$BACKUP_DIR/workflows/" 2>/dev/null || echo "  (none found)"
    echo ""

    echo "Config backups:"
    ls -la "$BACKUP_DIR/config/" 2>/dev/null || echo "  (none found)"
}

restore_database() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "Database backup file not found: $file"
        exit 1
    fi

    log_warn "This will OVERWRITE the current database!"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi

    log_info "Restoring database from $file..."

    if [ -z "$SUPABASE_DB_URL" ]; then
        log_error "SUPABASE_DB_URL not set"
        exit 1
    fi

    # Handle gzipped files
    if [[ "$file" == *.gz ]]; then
        gunzip -c "$file" | psql "$SUPABASE_DB_URL"
    else
        psql "$SUPABASE_DB_URL" < "$file"
    fi

    log_info "Database restored successfully"
}

restore_workflows() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "Workflow backup file not found: $file"
        exit 1
    fi

    log_info "Restoring n8n workflows from $file..."

    if [ -z "$N8N_API_KEY" ] || [ -z "$N8N_URL" ]; then
        log_error "N8N_API_KEY or N8N_URL not set"
        exit 1
    fi

    # Import workflows via n8n API
    curl -X POST "$N8N_URL/api/v1/workflows" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        -H "Content-Type: application/json" \
        -d @"$file"

    log_info "Workflows restored successfully"
}

restore_config() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "Config backup file not found: $file"
        exit 1
    fi

    SCRIPT_DIR="$(dirname "$0")"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

    log_info "Restoring configuration from $file..."

    tar -xzf "$file" -C "$PROJECT_DIR"

    log_info "Configuration restored successfully"
    log_warn "Remember to restore your .env file manually!"
}

full_restore() {
    local dir="$1"

    if [ ! -d "$dir" ]; then
        log_error "Backup directory not found: $dir"
        exit 1
    fi

    log_warn "This will perform a FULL RESTORE!"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi

    # Find latest backups in directory
    local latest_db=$(ls -t "$dir/database/"*.sql* 2>/dev/null | head -1)
    local latest_wf=$(ls -t "$dir/workflows/"*.json 2>/dev/null | head -1)
    local latest_cfg=$(ls -t "$dir/config/"*.tar.gz 2>/dev/null | head -1)

    if [ -n "$latest_db" ]; then
        restore_database "$latest_db"
    fi

    if [ -n "$latest_wf" ]; then
        restore_workflows "$latest_wf"
    fi

    if [ -n "$latest_cfg" ]; then
        restore_config "$latest_cfg"
    fi

    log_info "Full restore complete!"
}

# Parse arguments
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --database)
            restore_database "$2"
            shift 2
            ;;
        --workflows)
            restore_workflows "$2"
            shift 2
            ;;
        --config)
            restore_config "$2"
            shift 2
            ;;
        --full)
            full_restore "$2"
            shift 2
            ;;
        --list)
            list_backups
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done
