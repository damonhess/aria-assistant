# ARIA Backup Strategy

## Overview

ARIA requires regular backups of:
1. **Supabase Database**: All user data, conversations, memories
2. **n8n Workflows**: Workflow definitions and credentials
3. **Configuration Files**: Environment and Docker configs
4. **Frontend Assets**: Built application (if self-hosted)

## Backup Schedule

| Component | Frequency | Retention |
|-----------|-----------|-----------|
| Database (full) | Daily | 30 days |
| Database (incremental) | Hourly | 7 days |
| n8n Workflows | On change | 10 versions |
| Config files | On change | Git history |

## Database Backup

### Supabase Cloud

Supabase provides automatic daily backups. For additional safety:

```bash
# Manual backup via pg_dump
pg_dump -h db.xxx.supabase.co -U postgres -d postgres > backup_$(date +%Y%m%d).sql
```

### Self-Hosted Supabase

```bash
# Full backup
docker exec supabase-db pg_dumpall -U postgres > backup_full_$(date +%Y%m%d).sql

# Compressed backup
docker exec supabase-db pg_dump -U postgres -Fc postgres > backup_$(date +%Y%m%d).dump
```

## n8n Workflow Backup

### Export Workflows

```bash
# Export all workflows via API
curl -X GET "http://localhost:5678/api/v1/workflows" \
  -H "X-N8N-API-KEY: your-api-key" \
  > n8n_workflows_backup_$(date +%Y%m%d).json
```

### Automated Export

The `scripts/backup.sh` script handles automated workflow export.

## Configuration Backup

Configuration files are tracked in Git:
- `.env.example` (template only, never actual secrets)
- `docker-compose.yml`
- `n8n-workflows/*.json`

**IMPORTANT**: Never commit `.env` files with actual secrets!

## Automated Backup Script

Use the provided backup script:

```bash
# Run backup
./scripts/backup.sh

# Schedule via cron (daily at 2 AM)
0 2 * * * /home/user/aria-assistant/scripts/backup.sh
```

## Disaster Recovery

### Full Restore

1. Provision new server with Docker
2. Clone repository
3. Restore `.env` from secure storage
4. Restore database:
   ```bash
   psql -h hostname -U postgres -d postgres < backup.sql
   ```
5. Import n8n workflows
6. Start services:
   ```bash
   docker-compose up -d
   ```

### Partial Restore

For specific components, use `scripts/restore.sh`:

```bash
# Restore database only
./scripts/restore.sh --database backup_20240101.sql

# Restore workflows only
./scripts/restore.sh --workflows n8n_backup.json
```

## Offsite Storage

Recommended offsite backup destinations:
- **B2/S3**: For automated daily uploads
- **Git**: For configuration and workflow versions
- **Local NAS**: For quick recovery

## Testing Backups

Monthly backup verification:
1. Spin up test environment
2. Restore from backup
3. Verify data integrity
4. Test core functionality
5. Document results

## Security Notes

- Encrypt backups before offsite transfer
- Use separate credentials for backup access
- Rotate backup encryption keys quarterly
- Store recovery keys in multiple secure locations
