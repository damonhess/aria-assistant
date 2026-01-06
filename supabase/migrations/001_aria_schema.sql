-- ARIA Database Schema
-- Adds new tables for ARIA without touching existing Personal Assistant tables
-- Created: January 5, 2026

-- Enable pgvector extension if not already enabled
CREATE EXTENSION IF NOT EXISTS vector;

-- Conversation threads (multiple conversations, searchable)
CREATE TABLE IF NOT EXISTS aria_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  title TEXT,
  summary TEXT,
  is_archived BOOLEAN DEFAULT FALSE,
  interface_source TEXT, -- 'web', 'telegram', 'cli'
  embedding VECTOR(1536)
);

CREATE INDEX idx_aria_conversations_updated ON aria_conversations(updated_at DESC);
CREATE INDEX idx_aria_conversations_archived ON aria_conversations(is_archived) WHERE is_archived = FALSE;
CREATE INDEX idx_aria_conversations_embedding ON aria_conversations USING ivfflat (embedding vector_cosine_ops);

-- Messages within conversations
CREATE TABLE IF NOT EXISTS aria_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES aria_conversations(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  interface_source TEXT,
  has_attachments BOOLEAN DEFAULT FALSE,
  embedding VECTOR(1536),
  metadata JSONB
);

CREATE INDEX idx_aria_messages_conversation ON aria_messages(conversation_id, created_at);
CREATE INDEX idx_aria_messages_created ON aria_messages(created_at DESC);
CREATE INDEX idx_aria_messages_embedding ON aria_messages USING ivfflat (embedding vector_cosine_ops);

-- File attachments with page-level tracking
CREATE TABLE IF NOT EXISTS aria_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID REFERENCES aria_messages(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  filename TEXT NOT NULL,
  file_type TEXT NOT NULL, -- 'pdf', 'image', 'audio', 'video', 'document'
  mime_type TEXT,
  file_size BIGINT,
  storage_path TEXT NOT NULL,
  storage_bucket TEXT DEFAULT 'attachments',
  extracted_text TEXT,
  page_count INTEGER,
  ocr_processed BOOLEAN DEFAULT FALSE,
  vision_processed BOOLEAN DEFAULT FALSE,
  pages JSONB, -- [{page: 1, text: "...", embedding: [...]}]
  embedding VECTOR(1536)
);

CREATE INDEX idx_aria_attachments_message ON aria_attachments(message_id);
CREATE INDEX idx_aria_attachments_file_type ON aria_attachments(file_type);
CREATE INDEX idx_aria_attachments_embedding ON aria_attachments USING ivfflat (embedding vector_cosine_ops);

-- Cross-conversation unified memory
CREATE TABLE IF NOT EXISTS aria_unified_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  memory_type TEXT, -- 'fact', 'preference', 'decision', 'context'
  content TEXT NOT NULL,
  source_conversation_id UUID REFERENCES aria_conversations(id),
  source_message_id UUID REFERENCES aria_messages(id),
  confidence FLOAT DEFAULT 1.0,
  is_active BOOLEAN DEFAULT TRUE,
  embedding VECTOR(1536)
);

CREATE INDEX idx_aria_memory_type ON aria_unified_memory(memory_type) WHERE is_active = TRUE;
CREATE INDEX idx_aria_memory_active ON aria_unified_memory(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_aria_memory_embedding ON aria_unified_memory USING ivfflat (embedding vector_cosine_ops);

-- User sessions & device trust
CREATE TABLE IF NOT EXISTS aria_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  device_name TEXT,
  device_type TEXT, -- 'desktop', 'mobile', 'tablet'
  ip_address TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  last_activity TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_aria_sessions_active ON aria_sessions(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_aria_sessions_expires ON aria_sessions(expires_at);

-- Interface sync for cross-platform continuity
CREATE TABLE IF NOT EXISTS aria_interface_sync (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID REFERENCES aria_messages(id),
  interface TEXT NOT NULL, -- 'web', 'telegram', 'cli'
  delivered BOOLEAN DEFAULT FALSE,
  delivered_at TIMESTAMPTZ,
  error TEXT
);

CREATE INDEX idx_aria_sync_message ON aria_interface_sync(message_id);
CREATE INDEX idx_aria_sync_pending ON aria_interface_sync(delivered) WHERE delivered = FALSE;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_aria_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE aria_conversations 
  SET updated_at = NOW() 
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update conversation timestamp when message is added
CREATE TRIGGER aria_message_update_conversation
AFTER INSERT ON aria_messages
FOR EACH ROW
EXECUTE FUNCTION update_aria_conversation_timestamp();

COMMENT ON TABLE aria_conversations IS 'Multi-conversation threads with semantic search';
COMMENT ON TABLE aria_messages IS 'Individual messages within conversations';
COMMENT ON TABLE aria_attachments IS 'File attachments with page-level extraction';
COMMENT ON TABLE aria_unified_memory IS 'Cross-conversation persistent memory';
COMMENT ON TABLE aria_sessions IS 'User session and device tracking';
COMMENT ON TABLE aria_interface_sync IS 'Multi-interface message synchronization';