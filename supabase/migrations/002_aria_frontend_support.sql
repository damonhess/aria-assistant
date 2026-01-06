-- ARIA Frontend Support Migration
-- Extends existing aria_* tables to support the Bolt.new frontend
-- Created: January 6, 2026

-- ============================================================================
-- OPTION A: Views + Minimal Changes (Recommended)
-- Creates views that map frontend table names to existing aria_* tables
-- ============================================================================

-- Add user_id to aria_conversations for multi-user support
ALTER TABLE aria_conversations
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Create index for user_id lookup
CREATE INDEX IF NOT EXISTS idx_aria_conversations_user_id
ON aria_conversations(user_id);

-- ============================================================================
-- Create compatibility views for frontend
-- ============================================================================

-- View: conversations -> aria_conversations
CREATE OR REPLACE VIEW conversations AS
SELECT
  id,
  user_id,
  title,
  created_at,
  updated_at
FROM aria_conversations;

-- View: messages -> aria_messages
CREATE OR REPLACE VIEW messages AS
SELECT
  id,
  conversation_id,
  role,
  content,
  created_at
FROM aria_messages;

-- View: files -> aria_attachments
CREATE OR REPLACE VIEW files AS
SELECT
  id,
  message_id,
  filename,
  storage_path AS file_path,
  file_size,
  mime_type AS file_type,
  created_at
FROM aria_attachments;

-- ============================================================================
-- Enable RLS on underlying tables
-- ============================================================================

ALTER TABLE aria_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE aria_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE aria_attachments ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS Policies for aria_conversations
-- ============================================================================

DROP POLICY IF EXISTS "Users can view own conversations" ON aria_conversations;
CREATE POLICY "Users can view own conversations"
  ON aria_conversations FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own conversations" ON aria_conversations;
CREATE POLICY "Users can create own conversations"
  ON aria_conversations FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own conversations" ON aria_conversations;
CREATE POLICY "Users can update own conversations"
  ON aria_conversations FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own conversations" ON aria_conversations;
CREATE POLICY "Users can delete own conversations"
  ON aria_conversations FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================================================
-- RLS Policies for aria_messages
-- ============================================================================

DROP POLICY IF EXISTS "Users can view messages from own conversations" ON aria_messages;
CREATE POLICY "Users can view messages from own conversations"
  ON aria_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM aria_conversations
      WHERE aria_conversations.id = aria_messages.conversation_id
      AND aria_conversations.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create messages in own conversations" ON aria_messages;
CREATE POLICY "Users can create messages in own conversations"
  ON aria_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM aria_conversations
      WHERE aria_conversations.id = aria_messages.conversation_id
      AND aria_conversations.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update messages in own conversations" ON aria_messages;
CREATE POLICY "Users can update messages in own conversations"
  ON aria_messages FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM aria_conversations
      WHERE aria_conversations.id = aria_messages.conversation_id
      AND aria_conversations.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete messages in own conversations" ON aria_messages;
CREATE POLICY "Users can delete messages in own conversations"
  ON aria_messages FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM aria_conversations
      WHERE aria_conversations.id = aria_messages.conversation_id
      AND aria_conversations.user_id = auth.uid()
    )
  );

-- ============================================================================
-- RLS Policies for aria_attachments
-- ============================================================================

DROP POLICY IF EXISTS "Users can view attachments from own messages" ON aria_attachments;
CREATE POLICY "Users can view attachments from own messages"
  ON aria_attachments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM aria_messages
      JOIN aria_conversations ON aria_conversations.id = aria_messages.conversation_id
      WHERE aria_messages.id = aria_attachments.message_id
      AND aria_conversations.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create attachments in own messages" ON aria_attachments;
CREATE POLICY "Users can create attachments in own messages"
  ON aria_attachments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM aria_messages
      JOIN aria_conversations ON aria_conversations.id = aria_messages.conversation_id
      WHERE aria_messages.id = aria_attachments.message_id
      AND aria_conversations.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete attachments from own messages" ON aria_attachments;
CREATE POLICY "Users can delete attachments from own messages"
  ON aria_attachments FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM aria_messages
      JOIN aria_conversations ON aria_conversations.id = aria_messages.conversation_id
      WHERE aria_messages.id = aria_attachments.message_id
      AND aria_conversations.user_id = auth.uid()
    )
  );

-- ============================================================================
-- Create storage bucket for file uploads
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-files',
  'chat-files',
  false,
  52428800, -- 50MB limit
  ARRAY['image/*', 'application/pdf', 'audio/*', 'video/*', 'text/*', 'application/msword', 'application/vnd.openxmlformats-officedocument.*']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Storage RLS Policies
-- ============================================================================

DROP POLICY IF EXISTS "Users can upload files" ON storage.objects;
CREATE POLICY "Users can upload files"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'chat-files'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "Users can view own files" ON storage.objects;
CREATE POLICY "Users can view own files"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'chat-files'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "Users can delete own files" ON storage.objects;
CREATE POLICY "Users can delete own files"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'chat-files'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ============================================================================
-- INSTEAD OF triggers to make views insertable/updatable
-- ============================================================================

-- Trigger function for conversations view INSERT
CREATE OR REPLACE FUNCTION insert_conversation()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO aria_conversations (id, user_id, title, created_at, updated_at)
  VALUES (
    COALESCE(NEW.id, gen_random_uuid()),
    NEW.user_id,
    COALESCE(NEW.title, 'New Conversation'),
    COALESCE(NEW.created_at, NOW()),
    COALESCE(NEW.updated_at, NOW())
  )
  RETURNING id, user_id, title, created_at, updated_at INTO NEW;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER conversations_insert
INSTEAD OF INSERT ON conversations
FOR EACH ROW EXECUTE FUNCTION insert_conversation();

-- Trigger function for conversations view UPDATE
CREATE OR REPLACE FUNCTION update_conversation()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE aria_conversations
  SET
    title = COALESCE(NEW.title, OLD.title),
    updated_at = COALESCE(NEW.updated_at, NOW())
  WHERE id = OLD.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER conversations_update
INSTEAD OF UPDATE ON conversations
FOR EACH ROW EXECUTE FUNCTION update_conversation();

-- Trigger function for conversations view DELETE
CREATE OR REPLACE FUNCTION delete_conversation()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM aria_conversations WHERE id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER conversations_delete
INSTEAD OF DELETE ON conversations
FOR EACH ROW EXECUTE FUNCTION delete_conversation();

-- Trigger function for messages view INSERT
CREATE OR REPLACE FUNCTION insert_message()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO aria_messages (id, conversation_id, role, content, created_at)
  VALUES (
    COALESCE(NEW.id, gen_random_uuid()),
    NEW.conversation_id,
    NEW.role,
    NEW.content,
    COALESCE(NEW.created_at, NOW())
  )
  RETURNING id, conversation_id, role, content, created_at INTO NEW;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER messages_insert
INSTEAD OF INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION insert_message();

-- Trigger function for messages view UPDATE
CREATE OR REPLACE FUNCTION update_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE aria_messages
  SET
    content = COALESCE(NEW.content, OLD.content)
  WHERE id = OLD.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER messages_update
INSTEAD OF UPDATE ON messages
FOR EACH ROW EXECUTE FUNCTION update_message();

-- Trigger function for messages view DELETE
CREATE OR REPLACE FUNCTION delete_message()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM aria_messages WHERE id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER messages_delete
INSTEAD OF DELETE ON messages
FOR EACH ROW EXECUTE FUNCTION delete_message();

-- Trigger function for files view INSERT
CREATE OR REPLACE FUNCTION insert_file()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO aria_attachments (id, message_id, filename, storage_path, file_size, mime_type, file_type, created_at)
  VALUES (
    COALESCE(NEW.id, gen_random_uuid()),
    NEW.message_id,
    NEW.filename,
    NEW.file_path,
    COALESCE(NEW.file_size, 0),
    COALESCE(NEW.file_type, 'application/octet-stream'),
    CASE
      WHEN NEW.file_type LIKE 'image/%' THEN 'image'
      WHEN NEW.file_type LIKE 'video/%' THEN 'video'
      WHEN NEW.file_type LIKE 'audio/%' THEN 'audio'
      WHEN NEW.file_type = 'application/pdf' THEN 'pdf'
      ELSE 'document'
    END,
    COALESCE(NEW.created_at, NOW())
  )
  RETURNING id, message_id, filename, storage_path, file_size, mime_type, created_at
  INTO NEW.id, NEW.message_id, NEW.filename, NEW.file_path, NEW.file_size, NEW.file_type, NEW.created_at;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER files_insert
INSTEAD OF INSERT ON files
FOR EACH ROW EXECUTE FUNCTION insert_file();

-- Trigger function for files view DELETE
CREATE OR REPLACE FUNCTION delete_file()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM aria_attachments WHERE id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER files_delete
INSTEAD OF DELETE ON files
FOR EACH ROW EXECUTE FUNCTION delete_file();

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON VIEW conversations IS 'Frontend compatibility view for aria_conversations';
COMMENT ON VIEW messages IS 'Frontend compatibility view for aria_messages';
COMMENT ON VIEW files IS 'Frontend compatibility view for aria_attachments';
