-- ARIA Schema Consolidation - Fixed Version
-- Renames old PA table and creates compatibility view

-- 1. Add columns to aria_conversations if needed
ALTER TABLE aria_conversations ADD COLUMN IF NOT EXISTS session_id TEXT;
CREATE INDEX IF NOT EXISTS idx_aria_conversations_session ON aria_conversations(session_id);
ALTER TABLE aria_conversations ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- 2. Rename old conversations table
ALTER TABLE IF EXISTS conversations RENAME TO conversations_legacy;

-- 3. Migrate data from legacy table to ARIA
-- Group messages by session_id into conversation threads
INSERT INTO aria_conversations (session_id, interface_source, created_at, updated_at, title)
SELECT DISTINCT 
  session_id,
  'cli' as interface_source,
  MIN(timestamp) as created_at,
  MAX(timestamp) as updated_at,
  'Conversation ' || session_id as title
FROM conversations_legacy
WHERE session_id IS NOT NULL
GROUP BY session_id
ON CONFLICT DO NOTHING;

-- 4. Migrate individual messages
INSERT INTO aria_messages (conversation_id, role, content, created_at, metadata, interface_source)
SELECT 
  ac.id as conversation_id,
  cl.role,
  COALESCE(cl.message->>'content', cl.message::text) as content,
  cl.timestamp as created_at,
  cl.metadata,
  'cli' as interface_source
FROM conversations_legacy cl
JOIN aria_conversations ac ON ac.session_id = cl.session_id
ON CONFLICT DO NOTHING;

-- 5. Update foreign keys in other PA tables if they exist
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'conversation_id') THEN
    ALTER TABLE tasks RENAME COLUMN conversation_id TO legacy_conversation_id;
  END IF;
END $$;

DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'decisions' AND column_name = 'conversation_id') THEN
    ALTER TABLE decisions RENAME COLUMN conversation_id TO legacy_conversation_id;
  END IF;
END $$;

-- 6. Create compatibility VIEW
CREATE OR REPLACE VIEW conversations AS
SELECT 
  m.id,
  c.session_id,
  jsonb_build_object('content', m.content, 'role', m.role) as message,
  m.role,
  m.created_at as timestamp,
  m.embedding,
  m.metadata
FROM aria_messages m
JOIN aria_conversations c ON m.conversation_id = c.id
ORDER BY m.created_at;

-- 7. Create insert trigger for backwards compatibility
CREATE OR REPLACE FUNCTION conversations_insert_trigger()
RETURNS TRIGGER AS $$
DECLARE
  v_conversation_id UUID;
BEGIN
  -- Find or create conversation for this session
  SELECT id INTO v_conversation_id 
  FROM aria_conversations 
  WHERE session_id = NEW.session_id 
  LIMIT 1;
  
  IF v_conversation_id IS NULL THEN
    INSERT INTO aria_conversations (session_id, interface_source, title)
    VALUES (NEW.session_id, 'cli', 'Conversation ' || NEW.session_id)
    RETURNING id INTO v_conversation_id;
  END IF;
  
  -- Insert message
  INSERT INTO aria_messages (conversation_id, role, content, created_at, metadata, interface_source)
  VALUES (
    v_conversation_id,
    NEW.role,
    NEW.message->>'content',
    NEW.timestamp,
    NEW.metadata,
    'cli'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER conversations_insert
INSTEAD OF INSERT ON conversations
FOR EACH ROW
EXECUTE FUNCTION conversations_insert_trigger();

-- 8. Create delete trigger
CREATE OR REPLACE FUNCTION conversations_delete_trigger()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM aria_messages WHERE id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER conversations_delete
INSTEAD OF DELETE ON conversations
FOR EACH ROW
EXECUTE FUNCTION conversations_delete_trigger();

-- 9. Update search function
CREATE OR REPLACE FUNCTION search_similar_conversations(
  query_embedding VECTOR(1536),
  similarity_threshold FLOAT DEFAULT 0.5,
  match_count INT DEFAULT 5
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  role TEXT,
  created_at TIMESTAMPTZ,
  similarity FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id,
    m.content,
    m.role,
    m.created_at,
    1 - (m.embedding <=> query_embedding) as similarity
  FROM aria_messages m
  WHERE m.embedding IS NOT NULL
    AND 1 - (m.embedding <=> query_embedding) > similarity_threshold
  ORDER BY m.embedding <=> query_embedding
  LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- 10. Create new ARIA-specific search function
CREATE OR REPLACE FUNCTION search_aria_messages(
  query_embedding VECTOR(1536),
  similarity_threshold FLOAT DEFAULT 0.5,
  match_count INT DEFAULT 5,
  filter_interface TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  conversation_id UUID,
  content TEXT,
  role TEXT,
  interface_source TEXT,
  created_at TIMESTAMPTZ,
  similarity FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id,
    m.conversation_id,
    m.content,
    m.role,
    m.interface_source,
    m.created_at,
    1 - (m.embedding <=> query_embedding) as similarity
  FROM aria_messages m
  WHERE m.embedding IS NOT NULL
    AND 1 - (m.embedding <=> query_embedding) > similarity_threshold
    AND (filter_interface IS NULL OR m.interface_source = filter_interface)
  ORDER BY m.embedding <=> query_embedding
  LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON VIEW conversations IS 'Backwards compatibility view mapping to ARIA schema';
COMMENT ON FUNCTION search_similar_conversations IS 'Legacy search function - uses ARIA messages';
