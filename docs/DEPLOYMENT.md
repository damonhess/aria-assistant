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

## Health Checks

Run the health check script:
```bash
./scripts/health-check.sh
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
