# ARIA - Loose Ends & Immediate Priorities

*Last Updated: January 12, 2026*

---

## HIGH PRIORITY (Next Session - Week 1)

### 1. UI Formatting Fixes
**Issue:** Numbered lists in ARIA responses show numbers on separate lines from content
- Numbers appear on one line, content on next line
- Should be: `1. Memory Management: I can store...`
- Currently: `1.` on one line, `Memory Management: I can store...` on next
**Fix:** CSS adjustment in message display component
**Location:** `/home/damon/aria-assistant/frontend/src/components/`
**Time:** 15-30 minutes

### 2. Add Tool Schemas (5 remaining tools)
Currently 5/11 tools have schemas (45% coverage). Need schemas for:

**search_memory:**
- Search unified memory with vector similarity
- Parameters: query (string), limit (number), min_confidence (number)
- Returns: matching memories with confidence scores

**context_manager:**
- Track current state/context
- Parameters: operation (get/set/update/clear), context_data (object)
- Returns: current context state

**task_analytics:**
- Task performance metrics
- Parameters: time_range (string), metric_type (completion_rate/time_spent/patterns)
- Returns: analytics data and visualizations

**get_launch_status:**
- 4-week launch timeline status
- Parameters: show_details (boolean)
- Returns: current phase, completed milestones, risks

**cbt_therapist:**
- Mental health support and cognitive distortion detection
- Parameters: message (string), mode (analysis/support/challenge)
- Returns: assessment and supportive response

**Why:** Without schemas, AI doesn't know what parameters to send
**Time:** 1-2 hours total
**Impact:** Better AI tool usage accuracy

### 3. Separate ARIA vs PA Tool Routing
**Issue:** Both ARIA and Personal Assistant share same tool workflows
**Better:** Create ARIA-specific versions
- 04-store-memory-aria.json (routes to aria_unified_memory)
- 05-search-memory-aria.json (searches aria_unified_memory)
- Allows different schemas and behavior per interface
**Time:** 1-2 hours

### 4. Build Operations Agent ⭐ CRITICAL
**Problem:** Claude Code requires constant permissions for operations
**Solution:** Python orchestrator that makes decisions via Claude API, executes directly

**Architecture:**
```
User Request → ARIA → Operations Agent
                          ↓
        ┌─────────────────┼─────────────────┐
        ↓                 ↓                 ↓
    Decision Layer    Execution Layer   Safety Layer
    (Claude API)      (Direct)          (Validation)
```

**Capabilities:**
- Autonomous bash/SQL/API execution
- No permission prompts (pre-authorized actions)
- Service interruption detection
- Smart confirmation (only when risky)
- Comprehensive logging
- Rollback capability

**Safety Protocol:**

Auto-execute: Read operations, non-destructive ops, restartable services
Require confirmation: DELETE operations, DROP/TRUNCATE, service shutdowns, credential changes

**Time:** 1 week to build
**Value:** Future automation becomes trivial

---

## MEDIUM PRIORITY (Week 2)

### 5. Email Configuration
**Issue:** Supabase Auth pointing to non-existent mail server
**Current:** Using autoconfirm workaround
**Need:** Set up SMTP (Gmail, SendGrid, or AWS SES)
**Impact:** Production auth requires real emails

### 6. Storage Buckets for File Uploads
Need Supabase Storage buckets:
- `chat-files` - General file uploads
- `attachments` - Document attachments
- `audio` - Voice recordings

**Status:** Phase 2 feature (file uploads not implemented yet)

### 7. GitHub Repo Management
**Issue:** Multiple repos, unclear remotes, tracking difficulties
**Need:**
- Audit all repos on server
- Ensure all have GitHub remotes
- Document what's where
- Proper SSH key management for damonhess-dev account

### 8. Credential Manager Agent
**Problem:** API keys, OAuth tokens, expiration dates scattered everywhere
**Need:** Central tracking system
- Inventory of all credentials
- Expiration tracking
- Rotation reminders
- Scope documentation

**Priority:** High for security, medium for functionality

---

## LOW PRIORITY (Week 2-3)

### 9. Backup Automation
**Status:** Scripts created but not scheduled
**Need:**
- Cron job for daily backups
- Test restore procedures
- Verify backup integrity

**Time:** 30 minutes

### 10. Replace Code Nodes with Native Nodes
**Issue:** Using JavaScript Code nodes where native n8n nodes would be more stable
**Where:** Input normalization, date parsing, output formatting
**Why:** Native nodes = more stable, better error messages
**Impact:** Long-term maintenance easier
**Time:** 2-3 hours to rebuild all workflows

### 11. Two-Way Google Tasks Sync
**Current:** One-way (n8n → Google Tasks)
**Need:** Bidirectional sync
**Use case:** Updates in Google Tasks reflect in ARIA

---

## TECHNICAL DEBT

### 12. n8n Workflow Versioning (DOCUMENTED)
**Discovery:** n8n uses `workflow_history` for execution, not `workflow_entity`
**Root Cause:** SQL updates to `workflow_entity` don't update what n8n runs
**Fix:** Must update BOTH `workflow_entity` AND `workflow_history` tables
**Document:** See KNOWLEDGE-BASE.md Section 1 for complete fix

### 13. Credential Resolution in Sub-Workflows
**Issue:** Credentials sometimes fail to resolve in Execute Workflow Trigger scenarios
**Workaround:** Use direct Postgres/HTTP nodes instead
**Need:** Document pattern for future workflow building

### 14. Batch Deletion of Same-Named Events (WORKAROUND IN PLACE)
**Issue:** Deleting multiple events with same name (e.g., 12 "Test Event") fails
**Root Cause:** Event selection always returns same event ID for matching names
**Current Fix:** Random selection from duplicates using `Date.now() % length`
**Behavior:** Works iteratively (takes 2-3 calls for large batches)
**Better Fix:** Implement true `batch_mode` parameter in AI agent tool definition
**Priority:** Medium - workaround works, proper fix improves efficiency
**Document:** See KNOWLEDGE-BASE.md Section 6 for details

### 15. Google OAuth Token Refresh
**Issue:** OAuth tokens expire and n8n's built-in refresh sometimes fails with Cloudflare Access
**Current Fix:** Manual token injection via OAuth Playground
**Better Fix:** Create bypass rule in Cloudflare Access for OAuth callback
**Document:** See KNOWLEDGE-BASE.md Sections 2-4 for complete procedures

---

## PHASE 2 FEATURES (Week 2-3)

### 14. File Upload System
From ARIA-Comprehensive-Plan.md:
- PDF processing with page-level citations
- Image processing with vision API
- Audio transcription (Whisper)
- Video processing (extract audio + frames)
- Workflow: 18-file-processor

### 15. Telegram Interface
- Bot creation and token
- Webhook setup
- Cross-interface continuity
- Workflow: 17-telegram-interface

### 16. Unified Memory Consolidation
- Extract facts/preferences from conversations
- Store in aria_unified_memory
- Semantic search across all conversations
- Workflow: 20-memory-consolidator

---
