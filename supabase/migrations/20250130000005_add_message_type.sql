-- Add message_type column to messages table
-- Default to 'text' for existing messages
-- Types: 'text', 'image', 'system'

ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS message_type text NOT NULL DEFAULT 'text';

-- Improve performance for filtering/sorting by type if needed
CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(message_type);
