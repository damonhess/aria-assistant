# ARIA Knowledge Base - Lessons Learned & Solutions

*Last Updated: January 12, 2026 (Added Section 10: Conversation Deletion & Cleanup)*

This document captures hard-won knowledge from debugging sessions. Use it to avoid repeating mistakes and to quickly solve recurring issues.

---

## Table of Contents

1. [n8n Workflow Versioning](#1-n8n-workflow-versioning)
2. [Cloudflare Access OAuth Callback Issues](#2-cloudflare-access-oauth-callback-issues)
3. [Google OAuth2 Manual Token Injection](#3-google-oauth2-manual-token-injection)
4. [n8n Credential Encryption](#4-n8n-credential-encryption)
5. [HTTP Request Node Authentication](#5-http-request-node-authentication)
6. [Batch Deletion of Same-Named Events](#6-batch-deletion-of-same-named-events)
7. [pairedItem Errors in Code Nodes](#7-paireditem-errors-in-code-nodes)
8. [n8n AI Agent Tool Registration](#8-n8n-ai-agent-tool-registration)
9. [ARIA Database Schema Conventions](#9-aria-database-schema-conventions)
10. [Conversation Deletion & Cleanup](#10-conversation-deletion--cleanup)

---

## 1. n8n Workflow Versioning

### The Problem
Updating `workflow_entity.nodes` via SQL does NOT update what n8n actually executes. Changes appear in the n8n UI but don't take effect during execution.

### Root Cause
n8n uses TWO tables for workflow storage:
- `workflow_entity` - The "source of truth" displayed in the UI
- `workflow_history` - Versioned snapshots that n8n actually EXECUTES

When you save a workflow in the n8n UI, it updates BOTH tables. When you update via SQL, you only update one.

### The Fix
**Always update BOTH tables:**

```sql
-- Step 1: Update workflow_entity
UPDATE workflow_entity
SET nodes = '[...new nodes JSON...]',
    connections = '[...new connections JSON...]',
    "updatedAt" = NOW()
WHERE id = 'YOUR_WORKFLOW_ID';

-- Step 2: Find the active version
SELECT "activeVersionId" FROM workflow_entity WHERE id = 'YOUR_WORKFLOW_ID';

-- Step 3: Update workflow_history with the active version
UPDATE workflow_history h
SET nodes = w.nodes,
    connections = w.connections,
    "updatedAt" = NOW()
FROM workflow_entity w
WHERE h."versionId" = 'YOUR_ACTIVE_VERSION_ID'
AND w.id = 'YOUR_WORKFLOW_ID';

-- Step 4: Restart n8n to pick up changes
-- docker restart n8n
```

### Verification
```sql
-- Verify both tables have matching nodes
SELECT
    'entity' as source,
    nodes::text LIKE '%YOUR_UNIQUE_STRING%' as has_change
FROM workflow_entity WHERE id = 'YOUR_WORKFLOW_ID'
UNION ALL
SELECT
    'history' as source,
    nodes::text LIKE '%YOUR_UNIQUE_STRING%' as has_change
FROM workflow_history WHERE "versionId" = 'YOUR_ACTIVE_VERSION_ID';
```

### Symptoms of This Issue
- Changes appear in n8n UI but don't work during execution
- Old behavior persists after SQL updates
- Errors reference code/nodes you've already "fixed"

---

## 2. Cloudflare Access OAuth Callback Issues

### The Problem
Google OAuth authorization fails with `{"status":"error","message":"Unauthorized"}` after clicking "Allow" in Google's OAuth consent screen.

### Root Cause
Cloudflare Access (Zero Trust) intercepts the OAuth callback URL (`/rest/oauth2-credential/callback`) and blocks it because:
1. The callback comes from Google's servers, not the user's browser
2. No Cloudflare Access JWT token is present in the callback request

### The Fix
Create a bypass rule in Cloudflare Access for the OAuth callback path:

1. Go to Cloudflare Zero Trust Dashboard → Access → Applications
2. Create a new application with these settings:
   - **Name:** n8n OAuth Callback Bypass
   - **Type:** Self-hosted
   - **Application domain:** `your-n8n-domain.com`
   - **Path:** `/rest/oauth2-credential/callback`
   - **Policy:** Create a policy that allows everyone (Bypass)

**Policy Configuration:**
- Policy name: Allow OAuth Callbacks
- Action: Bypass
- Include: Everyone

### Alternative: Use OAuth Playground
If you can't modify Cloudflare Access, use Google's OAuth Playground to obtain tokens manually (see Section 3).

### Symptoms of This Issue
- OAuth flow works up until the final callback
- User sees "Account Connected" flash briefly, then error
- n8n logs show no incoming callback request
- Cloudflare Access logs show blocked request to callback URL

---

## 3. Google OAuth2 Manual Token Injection

### When to Use
When n8n's built-in OAuth flow doesn't work (Cloudflare Access, corporate proxies, etc.), you can manually obtain and inject OAuth tokens.

### Step 1: Get Tokens via OAuth Playground

1. Go to https://developers.google.com/oauthplayground/
2. Click the gear icon (Settings) in top right
3. Check "Use your own OAuth credentials"
4. Enter your Client ID and Client Secret
5. In the left panel, find "Google Calendar API v3" and select the scopes you need:
   - `https://www.googleapis.com/auth/calendar`
   - `https://www.googleapis.com/auth/calendar.events`
6. Click "Authorize APIs"
7. Complete Google sign-in
8. Click "Exchange authorization code for tokens"
9. Copy the Access Token and Refresh Token

### Step 2: Encrypt and Store Credentials

Use this SQL to store the credentials (you'll need to encrypt them first - see Section 4):

```sql
-- Check if credential exists
SELECT id, name, type FROM credentials_entity WHERE id = 'YOUR_CREDENTIAL_ID';

-- Update existing credential
UPDATE credentials_entity
SET data = 'ENCRYPTED_DATA_HERE',
    "updatedAt" = NOW()
WHERE id = 'YOUR_CREDENTIAL_ID';

-- Or insert new credential
INSERT INTO credentials_entity (id, name, type, data, "createdAt", "updatedAt")
VALUES (
    'YOUR_CREDENTIAL_ID',
    'Google Calendar OAuth2',
    'googleCalendarOAuth2Api',
    'ENCRYPTED_DATA_HERE',
    NOW(),
    NOW()
);
```

### Required JSON Structure Before Encryption
```json
{
  "clientId": "your-client-id.apps.googleusercontent.com",
  "clientSecret": "GOCSPX-xxxxxxxxxxxxx",
  "accessToken": "ya29.xxxxxxxxxxxxx",
  "refreshToken": "1//04xxxxxxxxxxxxxxx",
  "tokenType": "Bearer",
  "expiresIn": 3599,
  "scope": "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events",
  "oauthTokenData": {
    "access_token": "ya29.xxxxxxxxxxxxx",
    "refresh_token": "1//04xxxxxxxxxxxxxxx",
    "token_type": "Bearer",
    "expires_in": 3599,
    "scope": "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events"
  }
}
```

---

## 4. n8n Credential Encryption

### How n8n Encrypts Credentials
n8n uses AES-256-CBC encryption with a key derived from `N8N_ENCRYPTION_KEY` environment variable using OpenSSL's EVP_BytesToKey algorithm.

### Finding Your Encryption Key
```bash
docker exec n8n env | grep N8N_ENCRYPTION_KEY
# Or check your docker-compose.yml / .env file
```

### Encryption Algorithm (Node.js/CryptoJS)
```javascript
const CryptoJS = require('crypto-js');

function encryptCredential(data, encryptionKey) {
    const jsonString = JSON.stringify(data);
    const encrypted = CryptoJS.AES.encrypt(jsonString, encryptionKey);
    return encrypted.toString();
}

function decryptCredential(encryptedString, encryptionKey) {
    const decrypted = CryptoJS.AES.decrypt(encryptedString, encryptionKey);
    return JSON.parse(decrypted.toString(CryptoJS.enc.Utf8));
}

// Example usage:
const encryptionKey = 'JpY5iQpm6CWaAlEOfkr+gZz1ezAvR6aW';
const credentialData = {
    clientId: 'xxx.apps.googleusercontent.com',
    clientSecret: 'GOCSPX-xxx',
    accessToken: 'ya29.xxx',
    refreshToken: '1//04xxx'
};

const encrypted = encryptCredential(credentialData, encryptionKey);
console.log(encrypted);
```

### Important Notes
- The encryption key is typically a 32-character base64 string
- Encrypted credentials are stored as base64 strings in `credentials_entity.data`
- If you change the encryption key, ALL existing credentials become unreadable

---

## 5. HTTP Request Node Authentication

### The Problem
HTTP Request node fails with "Credentials not found" even though the API key is in headers.

### Root Cause
The node has `authentication: "genericCredentialType"` set, but no credential is actually assigned. n8n looks for a credential that doesn't exist.

### The Fix
If you're putting authentication directly in headers, set authentication to "none":

```json
{
  "parameters": {
    "url": "http://your-api.com/endpoint",
    "authentication": "none",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "apikey",
          "value": "your-api-key-here"
        },
        {
          "name": "Authorization",
          "value": "Bearer your-token-here"
        }
      ]
    }
  }
}
```

### Valid Authentication Options
- `"none"` - No credential lookup, use headers directly
- `"genericCredentialType"` - Requires a credential to be selected
- `"predefinedCredentialType"` - Uses a built-in credential type

### Symptoms of This Issue
- Error: "Credentials not found" or "Credential with ID X does not exist"
- Node config shows `genericCredentialType` but credential dropdown is empty
- API key is correctly in headers but node fails before making request

---

## 6. Batch Deletion of Same-Named Events

### The Problem
When deleting multiple events with the same name (e.g., 12 "Test Event" entries), only one gets deleted. Subsequent delete attempts return HTTP 410 (Gone) errors.

### Root Cause
The event selection logic always returns the SAME event for matching names because:
1. Events are scored and sorted by match quality
2. The first/best match is always returned
3. When called repeatedly, it keeps returning the same (now-deleted) event ID

### The Fix: Random Selection from Duplicates
When multiple events have the exact same name, randomly select one:

```javascript
// Find events with EXACT SAME name and similar score
const exactNameMatches = scoredEvents.filter(e =>
    e.summary.toLowerCase() === bestMatch.summary.toLowerCase() &&
    e.score >= bestMatch.score - 10
);

// If multiple events with same name, randomly select one
if (exactNameMatches.length > 1) {
    const randomIndex = Date.now() % exactNameMatches.length;
    const selectedMatch = exactNameMatches[randomIndex];

    return [{
        json: {
            ...selectedMatch.event.json,
            _source: 'random_from_duplicates',
            _duplicate_count: exactNameMatches.length
        }
    }];
}
```

### Behavior After Fix
- First call: Randomly selects one of the duplicates
- Second call: Different event (different timestamp = different random index)
- Iteratively deletes all duplicates over multiple calls

### Future Improvement: True Batch Mode
A proper fix would have the AI agent set `batch_mode: true` to get ALL matching events in a single call, then delete them in one operation. This requires:
1. Update tool definition to include `batch_mode` parameter
2. Modify workflow to return array of all matches
3. Loop node to delete each event

**Priority:** Medium - Current workaround works, just takes 2-3 iterations for large batches.

---

## 7. pairedItem Errors in Code Nodes

### The Problem
```
ExpressionError: Paired item data for item from node 'X' is unavailable
```

### Root Cause
n8n's Code nodes must return items with `pairedItem` metadata linking output items to input items. Without this, expressions like `$('Previous Node').item.json.field` fail.

### The Fix
Always include `pairedItem` in Code node returns:

```javascript
// WRONG - no pairedItem
return [{
    json: { result: 'value' }
}];

// CORRECT - with pairedItem
return [{
    json: { result: 'value' },
    pairedItem: { item: 0 }  // Links to input item index 0
}];

// For multiple items
return items.map((item, index) => ({
    json: { ...item.json, processed: true },
    pairedItem: { item: index }
}));
```

### When pairedItem is Required
- When subsequent nodes use expressions referencing earlier nodes
- When using `$('NodeName').item` syntax
- When using `$input.item` or `$input.first()`
- Essentially: almost always

### Symptoms of This Issue
- Error appears in nodes AFTER the Code node, not in the Code node itself
- Error mentions a node earlier in the workflow
- Error only occurs during execution, not in test runs

---

## 8. n8n AI Agent Tool Registration

### The Problem
A tool workflow exists and has an Execute Workflow Trigger, but the AI Agent doesn't see or use it. The tool doesn't appear in testing and never gets called.

### Root Cause
n8n AI Agent requires tools to be registered in **TWO separate places**:

1. **Tool: X Node** - A `@n8n/n8n-nodes-langchain.toolWorkflow` node connected to the AI Agent's `ai_tool` input
2. **Tools Array Entry** - An entry in the AI Agent's `parameters.tools` object with the tool's name and description

If EITHER is missing, the tool won't work:
- Missing toolWorkflow node = No physical connection to call the workflow
- Missing tools array entry = AI doesn't know the tool exists

### The Fix

**Step 1: Create the toolWorkflow Node**

```json
{
  "id": "tool-your-tool-name",
  "name": "Tool: Your Tool Name",
  "type": "@n8n/n8n-nodes-langchain.toolWorkflow",
  "position": [1350, 800],
  "parameters": {
    "name": "your_tool_name",
    "description": "Description of what this tool does",
    "workflowId": "YOUR_WORKFLOW_ID"
  },
  "typeVersion": 1.1
}
```

**Step 2: Add Connection to AI Agent**

```json
{
  "Tool: Your Tool Name": {
    "ai_tool": [[{"node": "AI Agent", "type": "ai_tool", "index": 0}]]
  }
}
```

**Step 3: Add Entry to AI Agent's tools Array**

In the AI Agent node's parameters:
```json
{
  "parameters": {
    "tools": {
      "values": [
        {
          "type": "tool",
          "value": {
            "name": "your_tool_name",
            "description": "Description of what this tool does and when to use it"
          }
        }
      ]
    }
  }
}
```

### Additional Requirements

**Project Membership**: Tool workflows must either:
- Be in the same project as the AI Agent workflow
- Have `callerPolicy: "any"` to allow cross-project calls

**workflow_history Sync**: After adding via SQL, ensure workflow_history is updated (see Section 1)

```sql
-- Add to workflow_history with required columns
INSERT INTO workflow_history (
    "workflowId", "versionId", nodes, connections, settings,
    "createdAt", "updatedAt", authors, autosaved
)
VALUES (
    'WORKFLOW_ID',
    gen_random_uuid()::text,
    'NODES_JSON',
    'CONNECTIONS_JSON',
    '{"executionOrder":"v1"}'::jsonb,
    NOW(), NOW(),
    'Claude Code',  -- authors column required
    false           -- autosaved column required
);
```

### Verification Checklist

```sql
-- 1. Check AI Agent has the tool in its nodes (toolWorkflow exists)
SELECT nodes::text LIKE '%Tool: Your Tool Name%' as has_tool_node
FROM workflow_entity WHERE id = 'AI_AGENT_WORKFLOW_ID';

-- 2. Check AI Agent has the tool in its parameters.tools
SELECT nodes::text LIKE '%"your_tool_name"%' as has_tools_entry
FROM workflow_entity WHERE id = 'AI_AGENT_WORKFLOW_ID';

-- 3. Check tool workflow exists
SELECT id, name, active FROM workflow_entity
WHERE name LIKE '%Your Tool%';

-- 4. Check tool workflow has execute trigger
SELECT nodes::text LIKE '%executeWorkflowTrigger%' as has_trigger
FROM workflow_entity WHERE id = 'TOOL_WORKFLOW_ID';
```

### Symptoms of This Issue
- Tool workflow exists but AI never calls it
- AI says "I don't have a tool for that" for functionality that exists
- Tool appears in n8n UI but not in AI Agent's tool list
- Adding Execute Workflow Trigger alone doesn't make tool available

---

## 9. ARIA Database Schema Conventions

### The Problem
Workflows query wrong tables or use wrong column names, causing SQL errors or empty results.

### ARIA Table Naming Convention
All ARIA-specific tables use the `aria_` prefix:

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `aria_conversations` | Chat conversations | `id`, `title`, `created_at`, `updated_at` |
| `aria_messages` | Individual messages | `id`, `conversation_id`, `role`, `content`, `created_at` |
| `aria_attachments` | File attachments | `id`, `message_id`, `filename`, `file_path`, `mime_type` |
| `aria_unified_memory` | Persistent memory | `id`, `memory_type`, `content`, `source_conversation_id`, `confidence`, `is_active` |

### Common Mistakes

**Wrong:** Using legacy table names
```sql
-- DON'T: Old schema
SELECT * FROM conversations WHERE session_id = '...';
SELECT * FROM memory WHERE type = 'summary';
```

**Right:** Using ARIA tables
```sql
-- DO: ARIA schema
SELECT * FROM aria_conversations WHERE id = '...';
SELECT * FROM aria_unified_memory WHERE memory_type = 'summary';
```

### Message Role Values
The `aria_messages.role` column uses standard values:
- `user` - Human user messages
- `assistant` - AI responses
- `system` - System prompts/context

### Joining Conversations and Messages
```sql
SELECT
    c.id as conversation_id,
    c.title,
    COUNT(m.id) as message_count,
    MIN(m.created_at) as started,
    MAX(m.created_at) as last_activity
FROM aria_conversations c
JOIN aria_messages m ON m.conversation_id = c.id
GROUP BY c.id, c.title
ORDER BY MAX(m.created_at) DESC;
```

### Storing Memory/Summaries
```sql
INSERT INTO aria_unified_memory (
    memory_type,
    content,
    source_conversation_id,
    confidence,
    is_active
)
VALUES (
    'summary',
    '{"title": "...", "summary": "...", "key_points": [...]}',
    'CONVERSATION_UUID',
    1.0,
    true
);
```

### Verification Query
```sql
-- Check ARIA tables exist with correct schema
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name LIKE 'aria_%'
ORDER BY table_name, ordinal_position;
```

### Frontend-Database Alignment
The ARIA frontend (`/home/damon/aria-assistant/frontend`) uses these tables directly. When modifying schemas:
1. Check frontend TypeScript types in `lib/supabase/types.ts`
2. Ensure migrations match frontend expectations
3. Test both frontend and n8n workflows after changes

### Symptoms of This Issue
- SQL queries return empty results when data exists
- "Column does not exist" errors
- Workflows that worked before fail after "fixes"
- Frontend and backend see different data

---

## 10. Conversation Deletion & Cleanup

### How Conversation Deletion Works (as of Jan 12, 2026)

ARIA uses **soft delete** for conversations:
- Frontend sets `is_archived = true` instead of deleting
- Archived conversations are filtered from the UI
- Data remains in database for potential recovery

### Database Cascade Behavior

| Table | On Conversation Delete | On Message Delete |
|-------|----------------------|-------------------|
| `aria_messages` | CASCADE | N/A |
| `aria_attachments` | CASCADE (via message) | CASCADE |
| `aria_interface_sync` | CASCADE (via message) | CASCADE |
| `aria_unified_memory` | SET NULL | SET NULL |
| `tasks` | SET NULL | N/A |
| `decisions` | SET NULL | N/A |

### n8n Chat Memory Cleanup

The n8n AI Agent uses Postgres Chat Memory which stores messages in `n8n_chat_histories` table. When a conversation is archived/deleted in ARIA, this table is NOT automatically cleaned.

**Session ID Format:** The `session_id` in n8n matches the `conversation_id` from ARIA.

**Manual Cleanup Query:**
```sql
-- Run in n8n-postgres container
-- Find orphaned chat histories
SELECT DISTINCT "sessionId"
FROM n8n_chat_histories
WHERE "sessionId" NOT IN (
  SELECT id::text FROM aria_conversations WHERE is_archived = false
);

-- Delete orphaned chat histories
DELETE FROM n8n_chat_histories
WHERE "sessionId" NOT IN (
  SELECT id::text FROM aria_conversations WHERE is_archived = false
);
```

**Note:** This requires cross-database access. The n8n database is separate from Supabase. Consider creating a scheduled n8n workflow for automated cleanup.

### Storage Bucket Cleanup

Attachment files in Supabase Storage (`chat-files` bucket) are NOT automatically deleted when conversations are archived. This requires:
1. Supabase Edge Function to delete files, OR
2. n8n workflow to clean orphaned files

**Find orphaned files:**
```sql
-- Files in storage but not in aria_attachments
-- Requires Supabase Storage API access
```

### Recovery Process

To recover a soft-deleted conversation:
```sql
-- In Supabase
UPDATE aria_conversations
SET is_archived = false, updated_at = NOW()
WHERE id = 'CONVERSATION_UUID';
```

### Hard Delete (Permanent)

If permanent deletion is required:
```sql
-- WARNING: This is irreversible
DELETE FROM aria_conversations WHERE id = 'CONVERSATION_UUID';
-- Messages and attachments cascade automatically
-- unified_memory references become NULL
```

---

## Quick Reference: Common Commands

### Restart n8n and check logs
```bash
docker restart n8n && sleep 5 && docker logs n8n --tail 50
```

### Find active workflow version
```sql
SELECT id, name, "activeVersionId"
FROM workflow_entity
WHERE id = 'WORKFLOW_ID';
```

### Check workflow_history vs workflow_entity match
```sql
SELECT
    'entity' as source,
    LENGTH(nodes::text) as node_length
FROM workflow_entity WHERE id = 'WORKFLOW_ID'
UNION ALL
SELECT
    'history' as source,
    LENGTH(nodes::text) as node_length
FROM workflow_history WHERE "versionId" = 'ACTIVE_VERSION_ID';
```

### Test Calendar API connectivity
```bash
curl -s "https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Check Supabase connectivity
```bash
curl -s "http://supabase-kong:8000/rest/v1/your_table?select=*&limit=1" \
  -H "apikey: YOUR_SERVICE_ROLE_KEY"
```

---

## Contributing to This Document

When you solve a tricky problem:
1. Add a new section following the existing format
2. Include: Problem, Root Cause, Fix, Symptoms
3. Add code examples where helpful
4. Update the Table of Contents
5. Update the "Last Updated" date

This knowledge base saves hours of debugging. Keep it current!
