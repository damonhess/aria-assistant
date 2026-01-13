# ARIA Architecture

## System Overview

ARIA (Adaptive Responsive Intelligent Assistant) is built as a modular, event-driven system with the following core components:

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERFACES                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ Telegram │  │   Web    │  │  Voice   │  │  Email   │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
└───────┼─────────────┼─────────────┼─────────────┼───────────────┘
        │             │             │             │
        └─────────────┴──────┬──────┴─────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    INTERFACE ROUTER (n8n)                        │
│              Request normalization & routing                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Conversation  │  │ File Processor  │  │ Task Manager    │
│ Manager       │  │                 │  │                 │
└───────┬───────┘  └────────┬────────┘  └────────┬────────┘
        │                   │                    │
        └───────────────────┼────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│                      MEMORY LAYER                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ Short-term  │  │ Long-term   │  │ Embeddings  │              │
│  │ (Context)   │  │ (Facts)     │  │ (Vectors)   │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│                    SUPABASE (PostgreSQL)                         │
│              + pgvector for semantic search                      │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Interface Layer
- **CLI (Personal Assistant)**: Command-line interface via n8n workflows
- **Web App**: Full-featured React dashboard for complex tasks
- **Telegram Bot**: Mobile interface for quick interactions (future)
- **Voice Interface**: Hands-free interaction (future)
- **Email Integration**: Automated email processing (future)

All interfaces share the unified ARIA schema with `interface_source` tracking.

### 2. Orchestration Layer (n8n)
Workflow-based orchestration handling:
- Request routing and normalization
- Multi-step task execution
- External API integrations
- Scheduled jobs and maintenance

### 3. Memory System
Three-tier memory architecture:
- **Short-term**: Active conversation context (last N messages)
- **Long-term**: Extracted facts, preferences, relationships
- **Semantic**: Vector embeddings for similarity search

### 4. Data Layer (Supabase)
- PostgreSQL for structured data
- pgvector extension for embeddings
- Row-level security for multi-user support
- Real-time subscriptions for live updates

## Key Workflows

| ID | Workflow | Purpose |
|----|----------|---------|
| 17 | Telegram Interface | Handle Telegram messages |
| 18 | File Processor | Extract and embed file content |
| 19 | Interface Router | Route requests to handlers |
| 20 | Memory Consolidator | Consolidate and prune memories |
| 21 | Conversation Manager | Manage dialogue and context |

## Data Flow

1. User sends message via interface
2. Interface Router normalizes request
3. Conversation Manager retrieves context
4. LLM generates response with context
5. Response sent back to user
6. Memory Consolidator updates long-term memory

## Unified Database Schema

ARIA uses a unified schema that consolidates the Personal Assistant's `conversations` table into a more structured format:

### Core Tables

| Table | Purpose | Interface Source |
|-------|---------|------------------|
| `aria_conversations` | Conversation threads | All |
| `aria_messages` | Individual messages | Tagged per message |
| `aria_attachments` | File uploads with OCR/vision | All |
| `aria_unified_memory` | Cross-conversation facts/preferences | All |
| `aria_sessions` | User session tracking | All |
| `aria_interface_sync` | Multi-interface synchronization | All |

### PA Integration Tables (Preserved)

| Table | Purpose |
|-------|---------|
| `tasks` | Task management with deadlines |
| `decisions` | Decision tracking with rationale |
| `patterns` | Detected behavior patterns |
| `context` | Working context/state |
| `launch_timeline` | 4-week milestone tracking |
| `mental_health_patterns` | CBT-focused tracking |

### Interface Source Values

- `'cli'` - Personal Assistant CLI
- `'web'` - ARIA web frontend
- `'telegram'` - Telegram bot (future)

### Compatibility

A `conversations` view provides backwards compatibility for existing PA workflows:
```sql
-- This view maps to aria_messages
SELECT * FROM conversations WHERE session_id = 'xxx';
```

See [MIGRATION_PLAN.md](../MIGRATION_PLAN.md) for migration details.

## Environment Separation (Added Jan 13, 2026)

ARIA uses separate development and production environments to prevent accidental breakage:

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRODUCTION ENVIRONMENT                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ n8n (PROD)  │  │ aria-web    │  │ Supabase (shared)       │  │
│  │ :5678       │  │ :80         │  │ PostgreSQL + pgvector   │  │
│  └──────┬──────┘  └──────┬──────┘  └────────────┬────────────┘  │
│         │                │                      │                │
│         └────────────────┼──────────────────────┘                │
│                          │                                       │
│  URLs: n8n.leveredgeai.com, aria.leveredgeai.com                │
└──────────────────────────┼───────────────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │   Caddy     │
                    │  (reverse   │
                    │   proxy)    │
                    └──────┬──────┘
                           │
┌──────────────────────────┼───────────────────────────────────────┐
│                     DEVELOPMENT ENVIRONMENT                       │
│  ┌─────────────┐                                                 │
│  │ n8n-dev     │  Database: n8n_dev (separate from prod)        │
│  │ :5678       │  Credentials: Must be configured separately    │
│  └─────────────┘                                                 │
│                                                                  │
│  URL: dev.n8n.leveredgeai.com                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Environment Details

| Component | Production | Development |
|-----------|------------|-------------|
| n8n URL | n8n.leveredgeai.com | dev.n8n.leveredgeai.com |
| n8n Database | `n8n` | `n8n_dev` |
| Webhook Base | hooks.leveredgeai.com | dev.n8n.leveredgeai.com |
| Container | `n8n` | `n8n-dev` |
| Supabase | Shared | Shared |
| Credentials | Configured | Must setup separately |

### Development Workflow

1. **Develop** on dev.n8n.leveredgeai.com
2. **Test** thoroughly in dev environment
3. **Export** working workflow as JSON
4. **Import** to production n8n.leveredgeai.com
5. **Activate** and verify on production

See [DEV-PROD-WORKFLOW.md](./DEV-PROD-WORKFLOW.md) for detailed procedures.

## Security Considerations

- All API keys stored in environment variables
- Supabase RLS for data isolation
- HTTPS for all external communications
- Input sanitization on all user inputs
- User-scoped storage bucket policies
- Separate dev/prod environments prevent accidental production changes
