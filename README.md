# ARIA - Personal AI Operating System

ARIA (Adaptive Responsive Intelligent Assistant) is a comprehensive personal AI operating system designed to manage daily life through intelligent automation, memory consolidation, and multi-interface access.

## Overview

ARIA serves as your personal AI assistant that:
- Processes and manages tasks, emails, and communications
- Maintains long-term memory and context across conversations
- Integrates with multiple interfaces (Telegram, Web, Voice)
- Automates workflows and file processing
- Provides intelligent insights and recommendations

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Backend Orchestration** | n8n (self-hosted) |
| **Database** | Supabase (PostgreSQL + pgvector) |
| **Frontend** | React/Vite (via Bolt.new) |
| **LLM** | OpenAI GPT-4 / Claude |
| **Hosting** | Docker on VPS |
| **Interfaces** | Telegram Bot, Web App |

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Node.js 18+ (for frontend development)
- Supabase account or self-hosted instance
- OpenAI API key

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/aria-assistant.git
   cd aria-assistant
   ```

2. Copy environment template:
   ```bash
   cp .env.example .env
   ```

3. Configure your environment variables in `.env`

4. Start services:
   ```bash
   docker-compose up -d
   ```

5. Import n8n workflows from `n8n-workflows/`

6. Run database migrations:
   ```bash
   # Apply Supabase migrations
   ```

## Project Structure

```
aria-assistant/
├── frontend/          # React web interface (Bolt.new export)
├── n8n-workflows/     # n8n workflow JSON exports
├── supabase/          # Database migrations and schema
├── docs/              # Documentation
└── scripts/           # Utility scripts
```

## Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Backup Strategy](docs/BACKUP.md)

## License

Private - Personal Use Only
