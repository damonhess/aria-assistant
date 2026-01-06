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
- **Telegram Bot**: Primary mobile interface for quick interactions
- **Web App**: Full-featured dashboard for complex tasks
- **Voice Interface**: Hands-free interaction (future)
- **Email Integration**: Automated email processing (future)

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

## Security Considerations

- All API keys stored in environment variables
- Supabase RLS for data isolation
- HTTPS for all external communications
- Input sanitization on all user inputs
