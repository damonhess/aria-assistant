# PA to ARIA Schema Consolidation Migration Plan

## Overview

This document outlines the migration from the Personal Assistant (PA) database schema to the unified ARIA schema. The goal is to consolidate conversation storage while preserving all existing PA functionality.

## Current State

### PA Tables (personal-assistant-ai)
| Table | Purpose | Status |
|-------|---------|--------|
| `conversations` | Individual messages (each row = 1 message) | **MIGRATING** |
| `tasks` | Action items with tracking | Keeping |
| `decisions` | Important choices with rationale | Keeping |
| `patterns` | Learned behaviors and insights | Keeping |
| `context` | Current state/working memory | Keeping |
| `launch_timeline` | 4-week launch milestones | Keeping |
| `mental_health_patterns` | CBT-focused tracking | Keeping |

### ARIA Tables (aria-assistant)
| Table | Purpose | Status |
|-------|---------|--------|
| `aria_conversations` | Conversation threads | **NEW - unified** |
| `aria_messages` | Individual messages within threads | **NEW - unified** |
| `aria_attachments` | File attachments with OCR/vision | NEW |
| `aria_unified_memory` | Cross-conversation persistent memory | NEW |
| `aria_sessions` | User session tracking | NEW |
| `aria_interface_sync` | Multi-interface sync | NEW |

## Key Schema Differences

### PA `conversations` Table
```sql
-- Each row = 1 message
id, session_id, message (JSONB), role, timestamp, embedding, metadata
```

### ARIA Approach
```sql
-- aria_conversations: Each row = 1 conversation thread
id, session_id, user_id, title, summary, is_archived, interface_source, embedding

-- aria_messages: Each row = 1 message
id, conversation_id, role, content, interface_source, has_attachments, embedding, metadata
```

## Migration Files Created

### 1. SQL Migration
**File**: `supabase/migrations/003_consolidate_pa_to_aria.sql`

**What it does**:
1. Adds `session_id` column to `aria_conversations` for backwards compatibility
2. Migrates PA `conversations` grouped by `session_id` into `aria_conversations`
3. Migrates individual messages into `aria_messages`
4. Updates foreign key references in PA tables (`tasks`, `decisions`, `mental_health_patterns`)
5. Creates a `conversations` **view** that maps to ARIA tables (backwards compatibility)
6. Creates `INSTEAD OF` triggers so the view supports INSERT/DELETE
7. Updates `search_similar_conversations()` function to search `aria_messages`
8. Creates new `search_aria_messages()` function with `interface_source` filtering
9. Migrates active decisions to `aria_unified_memory`

### 2. Updated n8n Workflows

| Original File | Updated File | Changes |
|---------------|--------------|---------|
| `tools/04-store-memory.json` | `tools/04-store-memory-aria.json` | - Stores to `aria_conversations` + `aria_messages`<br>- Adds `interface_source` field<br>- New `memory` type for unified memory |
| `tools/05-search-memory.json` | `tools/05-search-memory-aria.json` | - Uses `search_aria_messages()` function<br>- Searches `aria_unified_memory`<br>- Supports `interface_source` filter |
| `advanced/14-memory-consolidation.json` | `advanced/14-memory-consolidation-aria.json` | - Archives `aria_conversations`<br>- Deactivates stale unified memory<br>- Expires old sessions<br>- Enhanced statistics |

## Workflow Audit Results

### Workflows Using `conversations` Table

| Workflow | Usage | Migration Impact |
|----------|-------|------------------|
| `ai-agent-main.json` | Uses `Postgres Chat Memory` node | **No change** - n8n manages its own table |
| `tools/04-store-memory.json` | INSERT INTO conversations | **Updated** - use ARIA version |
| `tools/05-search-memory.json` | search_similar_conversations() | **Works** - function updated |
| `advanced/14-memory-consolidation.json` | DELETE/SELECT conversations | **Updated** - use ARIA version |
| `advanced/15-backup-export.json` | SELECT FROM conversations | **Works** - view provides compatibility |

### Workflows NOT Affected
- `tools/01-get-launch-status.json` - Uses `launch_timeline`
- `tools/02-manage-tasks.json` - Uses `tasks`
- `tools/03-context-manager.json` - Uses `context`
- `advanced/08-pattern-detection-agent.json` - Uses `patterns`
- `advanced/09-proactive-reminder-agent.json` - Uses `tasks`
- `advanced/10-decision-tracker.json` - Uses `decisions`
- `advanced/11-task-analytics.json` - Uses `tasks`
- `advanced/12-context-summarizer.json` - Uses `context`
- `advanced/13-launch-timeline-manager.json` - Uses `launch_timeline`
- `advanced/16-cbt-therapist-agent.json` - Uses `mental_health_patterns`

## Migration Steps

### Step 1: Backup Current Data
```bash
# Export existing data before migration
pg_dump -t conversations -t tasks -t decisions > pa_backup.sql
```

### Step 2: Apply ARIA Schema (if not already done)
```bash
# Apply the ARIA tables
psql -f supabase/migrations/001_aria_schema.sql
psql -f supabase/migrations/002_aria_frontend_support.sql
```

### Step 3: Run Consolidation Migration
```bash
# Apply the consolidation migration
psql -f supabase/migrations/003_consolidate_pa_to_aria.sql
```

### Step 4: Verify Migration
```sql
-- Check row counts match
SELECT 'aria_conversations' as table_name, COUNT(*) FROM aria_conversations
UNION ALL SELECT 'aria_messages', COUNT(*) FROM aria_messages
UNION ALL SELECT 'original PA conversations', COUNT(*) FROM public.conversations;

-- Test compatibility view
SELECT * FROM conversations LIMIT 5;

-- Test search function
SELECT * FROM search_similar_conversations(
  (SELECT embedding FROM aria_messages WHERE embedding IS NOT NULL LIMIT 1),
  0.5, 5
);
```

### Step 5: Update n8n Workflows

**Option A: Gradual Migration (Recommended)**
1. Keep original workflows running
2. Import ARIA versions alongside:
   - `04-store-memory-aria.json`
   - `05-search-memory-aria.json`
   - `14-memory-consolidation-aria.json`
3. Update `ai-agent-main.json` to use ARIA tool workflows
4. Disable original workflows after testing

**Option B: Direct Replacement**
1. Rename original workflows with `-legacy` suffix
2. Remove `-aria` suffix from new workflows
3. Restart n8n

### Step 6: Update Main Agent (ai-agent-main.json)

Update tool workflow IDs to point to ARIA versions:
```json
{
  "workflowId": "NEW_ARIA_STORE_MEMORY_ID",
  "name": "store_memory",
  "description": "Save to ARIA unified schema with interface_source tracking"
},
{
  "workflowId": "NEW_ARIA_SEARCH_MEMORY_ID",
  "name": "search_memory",
  "description": "Search across ARIA messages, tasks, decisions, and unified memory"
}
```

## New Features Available After Migration

### 1. Interface Source Tracking
All messages now track where they came from:
- `'cli'` - Personal Assistant CLI
- `'web'` - ARIA web frontend
- `'telegram'` - Future Telegram bot

### 2. Unified Memory
Store cross-conversation facts, preferences, and insights:
```javascript
// Example: Store a preference
{
  "type": "memory",
  "memory_type": "preference",
  "content": "User prefers dark mode"
}
```

### 3. Multi-User Support
With `user_id` on `aria_conversations`, supports multiple users via Supabase Auth.

### 4. Better Search
- Filter messages by interface source
- Search unified memory
- Cross-platform conversation continuity

## Rollback Plan

If issues occur, rollback by:

### 1. Restore Compatibility View
```sql
DROP VIEW IF EXISTS conversations CASCADE;
-- Recreate original conversations table from backup
CREATE TABLE conversations AS SELECT * FROM conversations_backup;
```

### 2. Revert n8n Workflows
1. Disable ARIA workflow versions
2. Re-enable original workflow versions
3. Restart n8n

### 3. Keep ARIA Tables
ARIA tables can remain for the web frontend while PA uses original tables.

## Testing Checklist

- [ ] Run migration SQL without errors
- [ ] Verify `conversations` view returns data
- [ ] Test `search_similar_conversations()` function
- [ ] Import ARIA n8n workflows
- [ ] Test store_memory with type='conversation'
- [ ] Test store_memory with type='memory'
- [ ] Test search_memory with interface_source filter
- [ ] Verify ARIA web frontend still works
- [ ] Test PA CLI assistant end-to-end
- [ ] Run memory consolidation workflow

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Phase 1 | Day 1 | Backup, apply migration SQL, verify |
| Phase 2 | Day 2 | Import ARIA workflows, test tools |
| Phase 3 | Day 3 | Update main agent, integration testing |
| Phase 4 | Week 2 | Monitor, collect feedback, iterate |

## Contact

Created: January 6, 2026
Author: Claude (assisted migration planning)
