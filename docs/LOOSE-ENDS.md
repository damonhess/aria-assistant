# ARIA - Loose Ends & Immediate Priorities

*Last Updated: January 13, 2026 (persona switch & memory fixes)*

---

## Recent Session Accomplishments

### January 13, 2026 - Persona Switch & Memory Fixes
- **Persona Switch Bug Fixed**: ARIA now correctly switches personas without errors
  - Root cause: SQL used wrong table name (`aria_user_preferences` vs `aria_user_preferences_local`)
  - Fixed ARIA Model Router to use correct table
  - Updated both `workflow_entity` and `workflow_history` tables
- **"No Response Generated" Fixed**: Regular messages to ARIA now work correctly
  - Root cause: Save Persona Preference output `{?column?: 1}` was overwriting message data
  - Added "Prepare AI Request" Code node using `$getWorkflowStaticData('global')` for data passing
  - Fixed paired item data error by avoiding direct node references between non-connected nodes
- **Postgres Chat Memory Restored**: Personal Assistant now has persistent memory
  - Root cause: Missing database credentials on Postgres Chat Memory node
  - Added credentials `{"postgres": {"id": "aVP8htYcA8y2UOih", "name": "Supabase Postgres server"}}`
  - Verified memory persists across n8n restarts
- **n8n Workflow Caching Understood**: Documented that n8n uses `workflow_history` table (via `activeVersionId`), NOT `workflow_entity` for execution
- **Workflow Organization**:
  - Moved all ARIA-related workflows to "ARIA Frontend" folder
  - Deleted 8 inactive Personal Assistant workflows
  - Deleted 3 empty folders (Tools, Advanced, Personal Assistant)
- **Backups Created**: Working workflow versions backed up via n8n-troubleshooter MCP

### January 12, 2026 (Late Night) - Mobile UI & PWA
- **Mobile Touch Support**: Message actions (Copy, Speak, Regenerate) now accessible via tap
  - Changed from hover-only to tap-to-toggle
  - Added `stopPropagation` on action buttons
- **iOS Safe Area Insets**: Added padding for notch/home indicator devices
  - Body: top/left/right safe area padding
  - MessageInput: bottom safe area padding
- **Responsive Sidebar**: Changed from fixed `w-80` to `w-[85vw] max-w-80`
  - Prevents overflow on small phones (iPhone SE)
- **Mobile Delete Button**: Always visible on mobile, hover-only on desktop
- **Header Title**: Responsive max-width (`150px` → `xs` → `md`)
- **Input Zoom Fix**: Prevented iOS auto-zoom on input focus
  - Viewport: `maximum-scale=1.0, user-scalable=no`
  - Textarea: Added `text-base` class (16px font)
- **PWA Configuration**: Full-screen standalone app when added to home screen
  - `manifest.json` with standalone display mode
  - iOS meta tags for web app capable
  - Custom ARIA icon (luxury dark "A" design)
  - Theme color: #0a0f1a
- **Automated Daily Backups**: Cron job at 3 AM
  - Backs up Supabase ARIA tables, n8n workflows, config files
  - 7-day retention with auto-cleanup
  - Documentation: KNOWLEDGE-BASE.md Section 11

### January 12, 2026 (Night) - Conversation Deletion Fixes
- **FK Constraint Fixes**: Fixed foreign keys that would block conversation deletion
  - `aria_unified_memory.source_conversation_id` → ON DELETE SET NULL
  - `aria_unified_memory.source_message_id` → ON DELETE SET NULL
  - `aria_interface_sync.message_id` → ON DELETE CASCADE
- **Soft Delete Implementation**: Changed frontend to archive instead of hard delete
  - `deleteConversation()` now sets `is_archived: true`
  - `loadConversations()` filters out archived conversations
  - Conversations can be recovered if needed
- **Documentation**: Added KNOWLEDGE-BASE.md Section 10 (Conversation Deletion & Cleanup)
- **Technical Debt Logged**: Storage bucket cleanup and n8n memory cleanup documented

### January 12, 2026 (Late Evening) - Tool Registration & Schema Fixes
- **Pattern Detection Tool**: Rebuilt with real analysis logic
  - Now queries `tasks` and `decisions` tables
  - Calculates completion rates, procrastination scores, overdue analysis
  - Returns formatted markdown with actionable insights
- **Context Summarizer Tool**: Fixed database schema
  - Changed from legacy `conversations` table to `aria_conversations` + `aria_messages`
  - Now correctly joins ARIA tables for summarization
- **find_test_events Tool**: Removed (user confirmed not needed)
  - Calendar delete functionality to be upgraded in future sessions
- **KNOWLEDGE-BASE.md**: Added two new sections
  - Section 8: n8n AI Agent Tool Registration (TWO places requirement)
  - Section 9: ARIA Database Schema Conventions (aria_* tables)
- **Key Lesson Documented**: Tools require BOTH:
  1. Tool: X node with ai_tool connection to AI Agent
  2. Entry in AI Agent's parameters.tools array

### January 12, 2026 (Evening)
- **n8n-troubleshooter MCP Server**: Expanded from 45 → 61 tools
  - Phase 1: Execution control (5 tools)
  - Phase 2: Workflow CRUD (5 tools)
  - Phase 3: Version control + node operations (6 tools)
- **Security Decision**: Removed `n8n_troubleshooter` from ARIA's tools (AI with direct n8n management = risk)
- **Tool Schemas**: 100% coverage achieved (14/14 ARIA tools)
- **Analytics Tools**: Pattern Detection & Context Summarizer now on-demand callable

---

## HIGH PRIORITY (Next Session - Week 1)

### 1. ~~UI Formatting Fixes~~ ✅ COMPLETED (January 12, 2026)
**Status:** Fixed in MarkdownRenderer.tsx
- Changed `pl-6` to `ml-5` with `list-outside` for proper list rendering
- Numbers now appear inline with content

### 2. ~~Add Tool Schemas~~ ✅ COMPLETED (January 12, 2026)
**Status:** 13/13 ARIA tools now have schemas (100% coverage)

**Note:** `n8n_troubleshooter` was removed from ARIA's tool access (security decision - direct n8n management by AI poses risks). The tool remains available via MCP server for Claude Code.

**Note 2:** `find_test_events` was removed (user confirmed not needed - calendar delete functionality to be upgraded in future).

**Tools with schemas:**
- `search_memory` - query, limit, min_confidence, types[]
- `context_manager` - operation (get/set/update/clear), context_data, key
- `task_analytics` - time_range, metric_type, include_details
- `get_launch_status` - show_details, include_risks, format
- `cbt_therapist` - message, mode (analysis/support/challenge/reframe), context
- `pattern_detection` - time_range, focus_area (tasks/decisions/procrastination/all) - **Now functional with real analysis**
- `context_summarizer` - session_id, max_age_hours, min_messages - **Fixed to use ARIA schema**

**Also added:**
- Execute Workflow Triggers to Pattern Detection and Context Summarizer (now callable on-demand)
- "Analytics Tools" sticky note in AI Agent Main

**Location:** Updated in `workflow_entity` and `workflow_history` for workflow ID `aX8d9zWniCYaIDwc`

### 3. Dev/Prod Environment Separation ⭐ NEW
**Issue:** Development and production environments not clearly separated
**Risk:** Testing on production, accidental data corruption, unclear deployment path
**Need:**
- Separate development n8n instance or workflow staging area
- Clear deployment process from dev → prod
- Environment-specific configurations
- Database migration workflow
**Impact:** Prevents accidental production issues during development

### 4. n8n workflow_history vs workflow_entity ✅ DOCUMENTED
**Status:** Root cause understood and documented (January 13, 2026)

**Key Discovery:** n8n loads workflows from `workflow_history` table (via `activeVersionId`), NOT from `workflow_entity` table for execution.

**Implications:**
- Direct SQL updates to `workflow_entity` alone do NOT affect running workflows
- Must update BOTH tables OR use n8n CLI/API for changes to take effect
- This explains why "changes aren't working" after database updates

**Document:** See KNOWLEDGE-BASE.md Section 1 for complete procedure

### 5. Build Operations Agent ⭐ CRITICAL
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

**NEW: n8n-troubleshooter MCP Server (61 tools available)**
The MCP server now provides comprehensive n8n control:
- Execution Control: execute_workflow, activate/deactivate, cancel, get_running
- Workflow CRUD: create, update, clone, delete, import workflows
- Version Control: get_versions, compare_versions, rollback_to_version
- Node Operations: add_node, remove_node, update_node
- 45+ diagnostic tools for troubleshooting

Operations Agent can leverage these MCP tools for n8n automation without direct DB access.

**Safety Protocol:**

Auto-execute: Read operations, non-destructive ops, restartable services
Require confirmation: DELETE operations, DROP/TRUNCATE, service shutdowns, credential changes

**Value:** Future automation becomes trivial

---

## MEDIUM PRIORITY (Week 2)

### 6. Google Tasks Credential ⭐ NEW
**Issue:** Google Tasks API credential may need refresh or reconfiguration
**Status:** Needs verification
**Tasks:**
- Test Google Tasks credential connectivity
- Verify OAuth token refresh is working through Cloudflare Access bypass
- Document credential expiration/rotation procedure
**Related:** See Google OAuth Token Refresh item in Technical Debt (resolved)

### 7. Separate ARIA vs PA Tool Routing
**Issue:** Both ARIA and Personal Assistant share same tool workflows
**Better:** Create ARIA-specific versions
- 04-store-memory-aria.json (routes to aria_unified_memory)
- 05-search-memory-aria.json (searches aria_unified_memory)
- Allows different schemas and behavior per interface

### 8. Email Configuration
**Issue:** Supabase Auth pointing to non-existent mail server
**Current:** Using autoconfirm workaround
**Need:** Set up SMTP (Gmail, SendGrid, or AWS SES)
**Impact:** Production auth requires real emails

### 9. Storage Buckets for File Uploads
Need Supabase Storage buckets:
- `chat-files` - General file uploads
- `attachments` - Document attachments
- `audio` - Voice recordings

**Status:** Phase 2 feature (file uploads not implemented yet)

### 10. GitHub Repo Management
**Issue:** Multiple repos, unclear remotes, tracking difficulties
**Need:**
- Audit all repos on server
- Ensure all have GitHub remotes
- Document what's where
- Proper SSH key management for damonhess-dev account

### 11. Credential Manager Agent
**Problem:** API keys, OAuth tokens, expiration dates scattered everywhere
**Need:** Central tracking system
- Inventory of all credentials
- Expiration tracking
- Rotation reminders
- Scope documentation

**Priority:** High for security, medium for functionality

---

## LOW PRIORITY (Week 2-3)

### 12. Backup Automation ✅ RESOLVED
**Status:** COMPLETED - January 12, 2026

**Implemented:**
- Daily backup script: `/home/damon/backup-daily.sh`
- Cron job: `0 3 * * *` (3 AM daily)
- Backup location: `/home/damon/backups/daily/`
- Retention: 7 days (auto-cleanup)
- Includes: Supabase ARIA tables, n8n workflows, credentials, config files

**Documentation:** See KNOWLEDGE-BASE.md Section 11

### 13. Replace Code Nodes with Native Nodes
**Issue:** Using JavaScript Code nodes where native n8n nodes would be more stable
**Where:** Input normalization, date parsing, output formatting
**Why:** Native nodes = more stable, better error messages
**Impact:** Long-term maintenance easier

### 14. Two-Way Google Tasks Sync
**Current:** One-way (n8n → Google Tasks)
**Need:** Bidirectional sync
**Use case:** Updates in Google Tasks reflect in ARIA

---

## TECHNICAL DEBT

### 15. n8n Workflow Versioning (DOCUMENTED)
**Discovery:** n8n uses `workflow_history` for execution, not `workflow_entity`
**Root Cause:** SQL updates to `workflow_entity` don't update what n8n runs
**Fix:** Must update BOTH `workflow_entity` AND `workflow_history` tables
**Document:** See KNOWLEDGE-BASE.md Section 1 for complete fix

### 16. Credential Resolution in Sub-Workflows
**Issue:** Credentials sometimes fail to resolve in Execute Workflow Trigger scenarios
**Workaround:** Use direct Postgres/HTTP nodes instead
**Need:** Document pattern for future workflow building

### 17. Batch Deletion of Same-Named Events (WORKAROUND IN PLACE)
**Issue:** Deleting multiple events with same name (e.g., 12 "Test Event") fails
**Root Cause:** Event selection always returns same event ID for matching names
**Current Fix:** Random selection from duplicates using `Date.now() % length`
**Behavior:** Works iteratively (takes 2-3 calls for large batches)
**Better Fix:** Implement true `batch_mode` parameter in AI agent tool definition
**Priority:** Medium - workaround works, proper fix improves efficiency
**Document:** See KNOWLEDGE-BASE.md Section 6 for details

### 18. Google OAuth Token Refresh ✅ RESOLVED
**Issue:** OAuth tokens expire and n8n's built-in refresh sometimes fails with Cloudflare Access
**Status:** FIXED - Cloudflare Access bypass rule configured (Jan 12, 2026)

**Current Setup (Correct):**
| Application | Domain/Path | Purpose |
|-------------|-------------|---------|
| `n8n` | `n8n.leveredgeai.com` | Protects n8n (requires login) |
| `n8n OAuth Callback` | `n8n.leveredgeai.com/rest/oauth2-credential/callback` | Bypasses auth for OAuth |

**Next Steps:** Test n8n's built-in OAuth "Connect" button next time credentials expire instead of using OAuth Playground workaround.

**Document:** See KNOWLEDGE-BASE.md Sections 2-4 for complete procedures

### 19. Storage Bucket Cleanup on Conversation Delete
**Issue:** When conversations are archived/deleted, attachment files remain in Supabase Storage
**Tables Affected:** `aria_attachments` records are deleted, but actual files in `chat-files` bucket persist
**Current State:** No cleanup mechanism exists
**Solution Options:**
1. Supabase Edge Function triggered on `aria_attachments` delete
2. n8n scheduled workflow to find and delete orphaned files
3. Manual cleanup script run periodically

**Implementation Notes:**
```sql
-- Find orphaned files (files in storage not in aria_attachments)
-- Requires comparing storage bucket contents vs aria_attachments.storage_path
```
**Priority:** Low - not urgent until file uploads are heavily used
**Document:** See KNOWLEDGE-BASE.md Section 10 for context

### 20. n8n Chat Memory Cleanup
**Issue:** n8n's `n8n_chat_histories` table not cleaned when ARIA conversations archived
**Current State:** Orphaned session data accumulates
**Solution:** Scheduled n8n workflow or manual periodic cleanup
**Document:** See KNOWLEDGE-BASE.md Section 10 for cleanup queries

---

## PHASE 2 FEATURES (Week 2-3)

### 21. File Upload System
From ARIA-Comprehensive-Plan.md:
- PDF processing with page-level citations
- Image processing with vision API
- Audio transcription (Whisper)
- Video processing (extract audio + frames)
- Workflow: 18-file-processor

### 22. Telegram Interface
- Bot creation and token
- Webhook setup
- Cross-interface continuity
- Workflow: 17-telegram-interface

### 23. Unified Memory Consolidation
- Extract facts/preferences from conversations
- Store in aria_unified_memory
- Semantic search across all conversations
- Workflow: 20-memory-consolidator

---
