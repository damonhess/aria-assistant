# ARIA - Personal AI Operating System

ARIA (Adaptive Responsive Intelligent Assistant) is a comprehensive personal AI operating system designed to manage daily life through intelligent automation, memory consolidation, and multi-interface access.

## Overview

ARIA serves as your personal AI assistant that:
- Processes and manages tasks, emails, and communications
- Maintains long-term memory and context across conversations
- Integrates with multiple interfaces (CLI, Web, Telegram)
- Automates workflows and file processing
- Provides intelligent insights and recommendations

## Personal Assistant Integration

ARIA shares a **unified database schema** with the Personal Assistant (PA) system, enabling:

| Feature | Description |
|---------|-------------|
| **Multi-interface access** | Same conversations accessible from CLI, Web, or Telegram |
| **Interface tracking** | Every message tagged with source (`cli`, `web`, `telegram`) |
| **Unified memory** | Cross-conversation facts and preferences |
| **Seamless sync** | Start a conversation on CLI, continue on web |

### Related Projects

- **Personal Assistant AI**: CLI-based n8n workflows at `/home/damon/personal-assistant-ai/`
- **ARIA Frontend**: React web interface at `/home/damon/aria-assistant/frontend/`

See [MIGRATION_PLAN.md](MIGRATION_PLAN.md) for schema consolidation details.

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Backend Orchestration** | n8n (self-hosted) |
| **Database** | Supabase (PostgreSQL + pgvector) |
| **Frontend** | React/Vite (via Bolt.new) |
| **LLM** | OpenAI GPT-4 / Claude |
| **Hosting** | Docker on VPS |
| **Interfaces** | CLI, Web App, Telegram Bot (future) |

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
├── frontend/              # React web interface (Bolt.new export)
│   ├── src/
│   │   ├── components/    # React components (chat, sidebar, etc.)
│   │   ├── lib/           # Supabase client and utilities
│   │   ├── store/         # Zustand state management
│   │   └── types/         # TypeScript interfaces
│   └── supabase/          # Frontend's original migration (deprecated)
├── supabase/
│   └── migrations/
│       ├── 001_aria_schema.sql              # Core ARIA tables
│       ├── 002_aria_frontend_support.sql    # Frontend compatibility views
│       ├── 003_consolidate_pa_to_aria.sql   # PA schema consolidation
│       └── 004_aria_reminders.sql           # Reminders system
├── utils/
│   ├── time_context.py    # Time awareness utilities
│   ├── reminders.py       # Reminder management class
│   └── reminder-cli.sh    # CLI wrapper for reminder ops
├── docs/                  # Documentation
└── MIGRATION_PLAN.md      # Schema consolidation guide
```

## Time Awareness & Reminders

ARIA includes a sophisticated time awareness system that provides contextual temporal information and a full-featured reminder management system.

### Time Context

The time context system automatically injects temporal awareness into ARIA's system prompt:

```python
from utils.time_context import TimeContext

tc = TimeContext()
context = tc.get_time_context()
# Returns: "Current time: Wednesday, January 15, 2026 at 2:30 PM PST
#           Week 3 of 2026 | Day 15 of 365"
```

**Features:**
- Current date/time with timezone
- Day of week, week number, day of year
- Natural language time parsing ("tomorrow at 3pm", "next Friday")

### Reminders System

ARIA can set, manage, and proactively check reminders:

| Tool | Description |
|------|-------------|
| `create_reminder` | Create a new reminder with optional recurrence |
| `list_reminders` | List all pending reminders |
| `complete_reminder` | Mark a reminder as done |
| `delete_reminder` | Remove a reminder |
| `check_due_reminders` | Get reminders due now (for proactive notifications) |

**Reminder Schema:**
```sql
aria_reminders (
  id UUID PRIMARY KEY,
  user_id TEXT DEFAULT 'damon',
  reminder_text TEXT NOT NULL,
  remind_at TIMESTAMPTZ NOT NULL,
  completed BOOLEAN DEFAULT FALSE,
  recurrence TEXT,  -- 'daily', 'weekly', 'monthly', 'yearly'
  priority TEXT,    -- 'low', 'normal', 'high', 'urgent'
  category TEXT,
  context JSONB,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
)
```

**CLI Usage:**
```bash
# Create a reminder
./utils/reminder-cli.sh create "Call dentist" "tomorrow at 9am"

# List pending reminders
./utils/reminder-cli.sh list

# Check due reminders (for n8n polling)
./utils/reminder-cli.sh check-due

# Complete a reminder
./utils/reminder-cli.sh complete <uuid>
```

**n8n Integration:**
The reminders system integrates with n8n workflows through the system prompt tools. ARIA can be prompted to check for due reminders at the start of conversations and proactively notify users.

## Database Migrations

Apply migrations in order:
```bash
# 1. Core ARIA tables
psql -f supabase/migrations/001_aria_schema.sql

# 2. Frontend compatibility (views + RLS)
psql -f supabase/migrations/002_aria_frontend_support.sql

# 3. PA consolidation (migrates conversations)
psql -f supabase/migrations/003_consolidate_pa_to_aria.sql

# 4. Reminders system
psql -f supabase/migrations/004_aria_reminders.sql
```

## Documentation

**Core Documentation:**
- [Architecture Overview](docs/ARCHITECTURE.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Backup Strategy](docs/BACKUP.md)
- [Migration Plan](MIGRATION_PLAN.md) - PA to ARIA schema consolidation

**Operations & Troubleshooting:**
- [Knowledge Base](docs/KNOWLEDGE-BASE.md) - Lessons learned, solutions to common problems
- [Loose Ends](docs/LOOSE-ENDS.md) - Current priorities and technical debt
- [Future Vision](docs/FUTURE-VISION.md) - Long-term roadmap and planned features

## License

Private - Personal Use Only
