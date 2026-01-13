# Dev/Prod Workflow Guide

## Environments

| Environment | URL | Purpose |
|-------------|-----|---------|
| Production | n8n.leveredgeai.com | Stable, user-facing |
| Development | dev.n8n.leveredgeai.com | Experimentation, new features |

## Architecture

```
YOUR LAPTOP                          CONTABO VPS (Remote Server)
├── Claude Desktop (coach)           ├── n8n (PROD) → n8n.leveredgeai.com
├── VS Code + Claude Code ──SSH──────┼── n8n-dev (DEV) → dev.n8n.leveredgeai.com
├── Browser                          ├── Supabase (shared)
└── Terminal                         ├── Caddy (reverse proxy)
                                     └── Postgres
                                         ├── n8n (prod database)
                                         └── n8n_dev (dev database)
```

## Development Workflow

### 1. Always develop on DEV

- **Never modify production workflows directly**
- All new features start on dev.n8n.leveredgeai.com

### 2. Test thoroughly on DEV

- Test all scenarios before promoting
- Verify memory, persona switching, routing all work

### 3. Promote to PROD

#### Option A: Manual (UI)

1. Open dev.n8n.leveredgeai.com
2. Open workflow → ... menu → Export
3. Download as JSON
4. Open n8n.leveredgeai.com (prod)
5. Import workflow JSON
6. Activate

#### Option B: CLI/API

```bash
# Export from dev
curl -X GET "https://dev.n8n.leveredgeai.com/api/v1/workflows/[WORKFLOW_ID]" \
  -H "X-N8N-API-KEY: $DEV_API_KEY" > workflow.json

# Import to prod
curl -X POST "https://n8n.leveredgeai.com/api/v1/workflows" \
  -H "X-N8N-API-KEY: $PROD_API_KEY" \
  -H "Content-Type: application/json" \
  -d @workflow.json
```

### 4. Rollback if needed

Backups stored in: `/home/damon/aria-assistant/backups/`

```bash
# List backups
ls -la /home/damon/aria-assistant/backups/

# List available backups via MCP
# Use n8n-troubleshooter list_backups tool

# Restore using n8n-troubleshooter
# Use n8n-troubleshooter restore_workflow --backup_id [ID]
```

## Golden Rules

1. **If ARIA is working on prod, DON'T TOUCH PROD**
2. **All development happens on dev.n8n.leveredgeai.com**
3. **Test thoroughly before promoting**
4. **Always backup before major changes**

## Webhook URLs

| Environment | Webhook Base |
|-------------|--------------|
| Production | https://hooks.leveredgeai.com/ |
| Development | https://dev.n8n.leveredgeai.com/ |

## Shared Resources

Both environments share:
- Supabase database (same data)
- Caddy reverse proxy
- SSL certificates (auto via Caddy)
- OpenAI API key (via env var)

They do NOT share:
- n8n workflows
- n8n credentials (must be set up separately in dev)
- Execution history

## Container Management

```bash
# Check container status
docker ps | grep n8n

# View dev logs
docker logs n8n-dev --tail 100 -f

# Restart dev (safe - doesn't affect prod)
docker restart n8n-dev

# Stop dev temporarily
docker stop n8n-dev

# Start dev
docker start n8n-dev
```

## Database Access

```bash
# Connect to prod database
docker exec -it n8n-postgres psql -U n8n -d n8n

# Connect to dev database
docker exec -it n8n-postgres psql -U n8n -d n8n_dev

# List databases
docker exec n8n-postgres psql -U n8n -d postgres -c "\l"
```

## Backup Strategy

### Automated Backups Location
- `/home/damon/aria-assistant/backups/stable-2026-01-13/` - Stable baseline

### Creating Manual Backups
Use the n8n-troubleshooter MCP tool:
```
backup_workflow(workflow_id="...", reason="description")
```

### Backup Naming Convention
- `{workflow_id}_{YYYYMMDD}_{HHMMSS}.json`

## Troubleshooting

### Dev instance not accessible
1. Check container is running: `docker ps | grep n8n-dev`
2. Check logs: `docker logs n8n-dev --tail 50`
3. Verify Caddy config: `docker exec caddy cat /etc/caddy/Caddyfile | grep -A5 dev.n8n`
4. Reload Caddy: `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`

### Dev database issues
1. Check postgres health: `docker exec n8n-postgres pg_isready -U n8n`
2. Verify dev database exists: `docker exec n8n-postgres psql -U n8n -d postgres -c "\l" | grep n8n_dev`

### Production is down (emergency)
1. Check prod container: `docker ps | grep -E "^n8n "`
2. Restart if needed: `docker restart n8n`
3. Check logs: `docker logs n8n --tail 100`
4. **Do NOT modify workflows** - focus on container/infrastructure

## ARIA-Specific Notes

### Production Workflows (DO NOT MODIFY DIRECTLY)
- ARIA Web Interface Handler v2
- ARIA Model Router
- ARIA Cost Reporter
- Personal Assistant - AI Agent Main

### Testing ARIA Changes
1. Clone relevant workflow to dev
2. Modify webhook URLs to use dev.n8n.leveredgeai.com
3. Test via direct webhook calls (not through aria.leveredgeai.com)
4. Once verified, export and import to prod
5. Update aria.leveredgeai.com webhook targets if needed

## Quick Reference

| Task | Command |
|------|---------|
| Check prod | `curl -s https://n8n.leveredgeai.com` |
| Check dev | `curl -s https://dev.n8n.leveredgeai.com` |
| Check ARIA | `curl -s https://aria.leveredgeai.com` |
| View containers | `docker ps \| grep n8n` |
| Dev logs | `docker logs n8n-dev -f` |
| Prod logs | `docker logs n8n -f` |
| Restart dev | `docker restart n8n-dev` |
| Reload Caddy | `docker exec caddy caddy reload --config /etc/caddy/Caddyfile` |
