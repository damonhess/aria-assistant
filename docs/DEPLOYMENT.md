# ARIA Deployment Guide

## Prerequisites

- VPS with Docker and Docker Compose installed
- Domain name (optional, for HTTPS)
- Supabase project (cloud or self-hosted)
- OpenAI API key
- Telegram Bot token (from @BotFather)

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/aria-assistant.git
cd aria-assistant
```

### 2. Configure Environment

```bash
cp .env.example .env
nano .env
```

Fill in all required values:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Public anon key
- `SUPABASE_SERVICE_KEY`: Service role key (keep secret!)
- `OPENAI_API_KEY`: Your OpenAI API key
- `TELEGRAM_BOT_TOKEN`: From @BotFather

### 3. Database Setup

Apply migrations to your Supabase instance:

```bash
# Using Supabase CLI
supabase db push

# Or manually via SQL editor in Supabase dashboard
```

### 4. n8n Workflow Import

1. Access your n8n instance
2. Import workflows from `n8n-workflows/` directory
3. Configure credentials in n8n for:
   - Supabase
   - OpenAI
   - Telegram

### 5. Start Services

```bash
docker-compose up -d
```

## Service Configuration

### n8n Integration

Ensure n8n has access to:
- Supabase database (via credentials)
- OpenAI API
- Telegram Bot API

Configure webhook URLs in Telegram using:
```bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -d "url=https://your-n8n-domain/webhook/telegram"
```

### Frontend Deployment

Once Bolt.new export is ready:

```bash
cd frontend
npm install
npm run build
```

Deploy `dist/` to your preferred hosting (Vercel, Netlify, or Docker).

## Development Environment (Added Jan 13, 2026)

ARIA now uses a separate development n8n instance for safe experimentation.

### Dev Environment Setup

The dev environment was created with:

1. **Separate database:**
   ```bash
   docker exec n8n-postgres psql -U n8n -d postgres -c "CREATE DATABASE n8n_dev;"
   ```

2. **Docker container added to `/home/damon/stack/docker-compose.yml`:**
   - Service: `n8n-dev`
   - Database: `n8n_dev`
   - Volume: `n8n_dev_data`

3. **Caddy route added to `/home/damon/stack/Caddyfile`:**
   ```
   dev.n8n.leveredgeai.com {
       reverse_proxy n8n-dev:5678
   }
   ```

4. **DNS record required (Cloudflare):**
   - Type: CNAME
   - Name: `dev.n8n`
   - Content: `n8n.leveredgeai.com`

### Managing Dev Environment

```bash
# Start dev n8n
docker compose up -d n8n-dev

# Check status
docker ps | grep n8n-dev

# View logs
docker logs n8n-dev --tail 50 -f

# Restart
docker restart n8n-dev

# Reload Caddy after config changes
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### Setting Up Dev Credentials

After dev n8n is accessible, add credentials via UI at dev.n8n.leveredgeai.com:

| Priority | Credential Type | Name |
|----------|-----------------|------|
| Critical | OpenAI API | OpenAi account |
| Critical | Postgres | Supabase Postgres server |
| High | Google Calendar OAuth | Google Calendar account |
| High | Supabase API | Self-hosted Supabase account |

### Dev vs Prod

| Aspect | Production | Development |
|--------|------------|-------------|
| URL | n8n.leveredgeai.com | dev.n8n.leveredgeai.com |
| Database | `n8n` | `n8n_dev` |
| Container | `n8n` | `n8n-dev` |
| Credentials | Configured | Must setup manually |
| Workflows | Stable | Experimental |

See [DEV-PROD-WORKFLOW.md](./DEV-PROD-WORKFLOW.md) for complete workflow procedures.

## Health Checks

Run the health check script:
```bash
./scripts/health-check.sh
```

### Quick Environment Checks

```bash
# Check production
curl -s -o /dev/null -w "%{http_code}" https://n8n.leveredgeai.com
# Expected: 302 (redirect to login)

# Check development
curl -s -o /dev/null -w "%{http_code}" https://dev.n8n.leveredgeai.com
# Expected: 302 (redirect to login)

# Check ARIA frontend
curl -s -o /dev/null -w "%{http_code}" https://aria.leveredgeai.com
# Expected: 200
```

## Updating

```bash
git pull origin main
docker-compose down
docker-compose up -d --build
```

## Troubleshooting

### Common Issues

1. **n8n workflows not triggering**
   - Check webhook URLs are correct
   - Verify n8n is running and accessible

2. **Database connection errors**
   - Verify Supabase credentials
   - Check network connectivity

3. **LLM responses failing**
   - Verify OpenAI API key is valid
   - Check API rate limits

### Logs

```bash
# Docker logs
docker-compose logs -f

# n8n specific
docker-compose logs -f n8n
```
