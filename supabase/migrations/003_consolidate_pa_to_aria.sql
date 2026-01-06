-- ============================================================================
-- PA to ARIA Schema Consolidation Migration
-- Migrates Personal Assistant data to unified ARIA schema
-- Created: January 6, 2026
-- ============================================================================

-- ============================================================================
-- PHASE 1: Schema Updates
-- Add missing columns to ARIA tables for PA compatibility
-- ============================================================================

-- Add session_id to aria_conversations for backwards compatibility
ALTER TABLE aria_conversations
ADD COLUMN IF NOT EXISTS session_id VARCHAR(255);

-- Create index for session lookups
CREATE INDEX IF NOT EXISTS idx_aria_conversations_session
ON aria_conversations(session_id);

-- Add user_id for multi-user support (from previous migration)
ALTER TABLE aria_conversations
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- ============================================================================
-- PHASE 2: Data Migration
-- Migrate existing PA conversations to ARIA format
-- ============================================================================

-- Step 2.1: Create aria_conversations from unique session_ids
INSERT INTO aria_conversations (id, session_id, title, created_at, updated_at, interface_source)
SELECT
  -- Use the ID of the first message in the session as the conversation ID
  (SELECT id FROM conversations c2 WHERE c2.session_id = c.session_id ORDER BY timestamp ASC LIMIT 1),
  session_id,
  -- Generate title from first user message
  COALESCE(
    (SELECT
      CASE
        WHEN message->>'content' IS NOT NULL THEN LEFT(message->>'content', 50)
        WHEN message::text != '{}' THEN LEFT(message::text, 50)
        ELSE 'Conversation ' || session_id
      END
    FROM conversations c3
    WHERE c3.session_id = c.session_id AND c3.role = 'user'
    ORDER BY timestamp ASC
    LIMIT 1),
    'Conversation ' || session_id
  ) || CASE WHEN LENGTH(COALESCE(
    (SELECT message->>'content' FROM conversations c4 WHERE c4.session_id = c.session_id AND c4.role = 'user' ORDER BY timestamp ASC LIMIT 1),
    ''
  )) > 50 THEN '...' ELSE '' END AS title,
  MIN(timestamp) AS created_at,
  MAX(timestamp) AS updated_at,
  'cli' AS interface_source  -- Mark as CLI since this is from PA
FROM conversations c
GROUP BY session_id
ON CONFLICT (id) DO NOTHING;

-- Step 2.2: Migrate messages from PA conversations to aria_messages
INSERT INTO aria_messages (id, conversation_id, created_at, role, content, interface_source, embedding, metadata)
SELECT
  c.id,
  -- Find the conversation ID for this session
  (SELECT id FROM aria_conversations ac WHERE ac.session_id = c.session_id LIMIT 1) AS conversation_id,
  c.timestamp AS created_at,
  c.role,
  -- Extract content from JSONB message field
  CASE
    WHEN c.message->>'content' IS NOT NULL THEN c.message->>'content'
    WHEN c.message::text != '{}' THEN c.message::text
    ELSE ''
  END AS content,
  'cli' AS interface_source,
  c.embedding,
  c.metadata
FROM conversations c
WHERE EXISTS (SELECT 1 FROM aria_conversations ac WHERE ac.session_id = c.session_id)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- PHASE 3: Update Foreign Keys in PA Tables
-- Update references from conversations to aria_conversations/aria_messages
-- ============================================================================

-- First, let's check if there are any FK references to update

-- Update tasks.conversation_id to reference aria_conversations
-- Note: This requires adding a new column since the data model changed
ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS aria_conversation_id UUID REFERENCES aria_conversations(id) ON DELETE SET NULL;

-- Migrate the reference
UPDATE tasks t
SET aria_conversation_id = (
  SELECT ac.id
  FROM aria_conversations ac
  JOIN conversations c ON c.session_id = ac.session_id
  WHERE c.id = t.conversation_id
  LIMIT 1
)
WHERE t.conversation_id IS NOT NULL;

-- Update decisions.conversation_id similarly
ALTER TABLE decisions
ADD COLUMN IF NOT EXISTS aria_conversation_id UUID REFERENCES aria_conversations(id) ON DELETE SET NULL;

UPDATE decisions d
SET aria_conversation_id = (
  SELECT ac.id
  FROM aria_conversations ac
  JOIN conversations c ON c.session_id = ac.session_id
  WHERE c.id = d.conversation_id
  LIMIT 1
)
WHERE d.conversation_id IS NOT NULL;

-- Update mental_health_patterns.conversation_id
ALTER TABLE mental_health_patterns
ADD COLUMN IF NOT EXISTS aria_conversation_id UUID REFERENCES aria_conversations(id) ON DELETE SET NULL;

UPDATE mental_health_patterns mhp
SET aria_conversation_id = (
  SELECT ac.id
  FROM aria_conversations ac
  JOIN conversations c ON c.session_id = ac.session_id
  WHERE c.id = mhp.conversation_id
  LIMIT 1
)
WHERE mhp.conversation_id IS NOT NULL;

-- ============================================================================
-- PHASE 4: Create Compatibility Views and Functions
-- Allow old queries to continue working during transition
-- ============================================================================

-- Drop existing view if it exists (from migration 002)
DROP VIEW IF EXISTS conversations CASCADE;

-- Create compatibility view that maps old 'conversations' to new 'aria_messages'
CREATE OR REPLACE VIEW conversations AS
SELECT
  am.id,
  ac.session_id,
  jsonb_build_object('content', am.content) AS message,
  am.role,
  am.created_at AS timestamp,
  am.embedding,
  am.metadata
FROM aria_messages am
JOIN aria_conversations ac ON ac.id = am.conversation_id;

-- Create INSTEAD OF triggers for the compatibility view

-- INSERT trigger
CREATE OR REPLACE FUNCTION insert_legacy_conversation()
RETURNS TRIGGER AS $$
DECLARE
  conv_id UUID;
  msg_content TEXT;
BEGIN
  -- Extract content from message JSONB
  msg_content := COALESCE(NEW.message->>'content', NEW.message::text, '');

  -- Find or create the conversation
  SELECT id INTO conv_id FROM aria_conversations WHERE session_id = NEW.session_id;

  IF conv_id IS NULL THEN
    -- Create new conversation
    INSERT INTO aria_conversations (session_id, title, interface_source, created_at, updated_at)
    VALUES (
      NEW.session_id,
      LEFT(msg_content, 50) || CASE WHEN LENGTH(msg_content) > 50 THEN '...' ELSE '' END,
      'cli',
      COALESCE(NEW.timestamp, NOW()),
      COALESCE(NEW.timestamp, NOW())
    )
    RETURNING id INTO conv_id;
  ELSE
    -- Update existing conversation timestamp
    UPDATE aria_conversations
    SET updated_at = COALESCE(NEW.timestamp, NOW())
    WHERE id = conv_id;
  END IF;

  -- Insert the message
  INSERT INTO aria_messages (id, conversation_id, role, content, interface_source, embedding, metadata, created_at)
  VALUES (
    COALESCE(NEW.id, gen_random_uuid()),
    conv_id,
    NEW.role,
    msg_content,
    'cli',
    NEW.embedding,
    NEW.metadata,
    COALESCE(NEW.timestamp, NOW())
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS conversations_insert ON conversations;
CREATE TRIGGER conversations_insert
INSTEAD OF INSERT ON conversations
FOR EACH ROW EXECUTE FUNCTION insert_legacy_conversation();

-- DELETE trigger
CREATE OR REPLACE FUNCTION delete_legacy_conversation()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM aria_messages WHERE id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS conversations_delete ON conversations;
CREATE TRIGGER conversations_delete
INSTEAD OF DELETE ON conversations
FOR EACH ROW EXECUTE FUNCTION delete_legacy_conversation();

-- ============================================================================
-- PHASE 5: Update Search Functions
-- Create new search functions that work with ARIA tables
-- ============================================================================

-- Drop old function if exists
DROP FUNCTION IF EXISTS search_similar_conversations(vector(1536), float, int);

-- Create new function that searches aria_messages
CREATE OR REPLACE FUNCTION search_similar_conversations(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  session_id VARCHAR,
  message JSONB,
  role TEXT,
  msg_timestamp TIMESTAMPTZ,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    am.id,
    ac.session_id,
    jsonb_build_object('content', am.content) AS message,
    am.role,
    am.created_at AS msg_timestamp,
    1 - (am.embedding <=> query_embedding) as similarity
  FROM aria_messages am
  JOIN aria_conversations ac ON ac.id = am.conversation_id
  WHERE am.embedding IS NOT NULL
    AND 1 - (am.embedding <=> query_embedding) > match_threshold
  ORDER BY am.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- Create new function for searching aria_messages directly
CREATE OR REPLACE FUNCTION search_aria_messages(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 10,
  p_interface_source TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  conversation_id UUID,
  role TEXT,
  content TEXT,
  interface_source TEXT,
  created_at TIMESTAMPTZ,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    am.id,
    am.conversation_id,
    am.role,
    am.content,
    am.interface_source,
    am.created_at,
    1 - (am.embedding <=> query_embedding) as similarity
  FROM aria_messages am
  WHERE am.embedding IS NOT NULL
    AND 1 - (am.embedding <=> query_embedding) > match_threshold
    AND (p_interface_source IS NULL OR am.interface_source = p_interface_source)
  ORDER BY am.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ============================================================================
-- PHASE 6: Unified Memory Integration
-- Link PA patterns/decisions to ARIA unified memory
-- ============================================================================

-- Migrate important decisions to aria_unified_memory
INSERT INTO aria_unified_memory (
  memory_type,
  content,
  source_conversation_id,
  confidence,
  embedding,
  created_at
)
SELECT
  'decision' AS memory_type,
  title || ': ' || decision || ' (Rationale: ' || COALESCE(rationale, 'none') || ')' AS content,
  aria_conversation_id AS source_conversation_id,
  1.0 AS confidence,
  embedding,
  made_at AS created_at
FROM decisions
WHERE status = 'active'
  AND aria_conversation_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- ============================================================================
-- PHASE 7: Comments and Documentation
-- ============================================================================

COMMENT ON VIEW conversations IS 'Compatibility view mapping legacy PA conversations to ARIA tables';
COMMENT ON FUNCTION search_similar_conversations IS 'Search messages with backwards-compatible signature for PA workflows';
COMMENT ON FUNCTION search_aria_messages IS 'Native ARIA message search with interface_source filtering';

-- ============================================================================
-- PHASE 8: Verification Queries (run manually to verify)
-- ============================================================================

/*
-- Verify migration counts
SELECT 'aria_conversations' as table_name, COUNT(*) as count FROM aria_conversations
UNION ALL
SELECT 'aria_messages', COUNT(*) FROM aria_messages
UNION ALL
SELECT 'original_conversations', COUNT(*) FROM conversations;

-- Verify session mapping
SELECT
  ac.session_id,
  ac.title,
  COUNT(am.id) as message_count
FROM aria_conversations ac
LEFT JOIN aria_messages am ON am.conversation_id = ac.id
GROUP BY ac.id, ac.session_id, ac.title
ORDER BY message_count DESC
LIMIT 10;

-- Test compatibility view
SELECT * FROM conversations LIMIT 5;

-- Test search function
SELECT * FROM search_similar_conversations(
  (SELECT embedding FROM aria_messages WHERE embedding IS NOT NULL LIMIT 1),
  0.5,
  5
);
*/
