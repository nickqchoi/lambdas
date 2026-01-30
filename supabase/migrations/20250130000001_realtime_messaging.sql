-- =============================================================================
-- Real-time Messaging Schema Updates
-- Adds image support, rate limiting, read receipts, and performance indexes
-- =============================================================================

-- =============================================================================
-- 1. Add image support to messages §12
-- =============================================================================
ALTER TABLE messages ADD COLUMN IF NOT EXISTS image_url text;

-- Debug: Log column addition
DO $$
BEGIN
    RAISE NOTICE 'Added image_url column to messages table';
END $$;

-- =============================================================================
-- 2. Message length constraint (max 2000 characters for body)
-- =============================================================================
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_body_length;
ALTER TABLE messages ADD CONSTRAINT messages_body_length CHECK (char_length(body) <= 2000);

-- =============================================================================
-- 3. Performance indexes for real-time filtering
-- =============================================================================
-- Index for fetching messages in a chat, ordered by sent_at
CREATE INDEX IF NOT EXISTS idx_messages_chat_sent ON messages(chat_id, sent_at DESC);

-- Index for fetching user's chats
CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants(user_id);

-- Index for last_message_at ordering in chat list
CREATE INDEX IF NOT EXISTS idx_chats_last_message ON chats(last_message_at DESC NULLS LAST);

-- =============================================================================
-- 4. Rate limiting function (max 30 messages per minute per user)
-- =============================================================================
CREATE OR REPLACE FUNCTION check_message_rate_limit()
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
DECLARE
    recent_count integer;
BEGIN
    -- Count messages sent by this user in the last minute
    SELECT count(*) INTO recent_count
    FROM messages
    WHERE sender_id = NEW.sender_id
      AND sent_at > now() - interval '1 minute';
    
    -- Enforce rate limit of 30 messages per minute
    IF recent_count >= 30 THEN
        RAISE EXCEPTION 'Rate limit exceeded: maximum 30 messages per minute';
    END IF;
    
    RETURN NEW;
END;
$$;

-- Apply rate limiting trigger
DROP TRIGGER IF EXISTS tr_message_rate_limit ON messages;
CREATE TRIGGER tr_message_rate_limit
    BEFORE INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION check_message_rate_limit();

-- =============================================================================
-- 5. Read receipts table (optional feature for tracking message read status)
-- =============================================================================
CREATE TABLE IF NOT EXISTS message_read_receipts (
    message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    read_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (message_id, user_id)
);

-- RLS for read receipts: only the reader can insert, participants can view
ALTER TABLE message_read_receipts ENABLE ROW LEVEL SECURITY;

-- Users can mark messages as read (insert their own read receipt)
CREATE POLICY "read_receipts_insert_own" ON message_read_receipts 
    FOR INSERT TO authenticated 
    WITH CHECK (user_id = auth.uid());

-- Users can see read receipts for messages in their chats
CREATE POLICY "read_receipts_select" ON message_read_receipts 
    FOR SELECT TO authenticated 
    USING (
        exists(
            SELECT 1 FROM messages m
            JOIN chat_participants cp ON cp.chat_id = m.chat_id
            WHERE m.id = message_read_receipts.message_id
              AND cp.user_id = auth.uid()
        )
    );

-- Index for efficient read receipt lookups
CREATE INDEX IF NOT EXISTS idx_read_receipts_message ON message_read_receipts(message_id);

-- =============================================================================
-- 6. Enable Realtime for messages table
-- Note: This needs to be done in Supabase Dashboard > Database > Replication
-- or via the following (if using supabase-js admin)
-- =============================================================================
-- The following is a placeholder comment - actual Realtime enablement is done
-- in the Supabase Dashboard under Database > Replication > Source
-- Enable: public.messages, public.chats, public.bounties, public.bounty_applications

-- =============================================================================
-- 7. Notification tracking for in-app notifications
-- Tracks which notifications have been seen by users
-- =============================================================================
CREATE TABLE IF NOT EXISTS notification_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    event_type text NOT NULL CHECK (event_type IN ('new_message', 'bounty_created', 'bounty_application', 'bounty_accepted', 'bounty_completed')),
    reference_id uuid NOT NULL,  -- ID of the related message/bounty/application
    title text NOT NULL,
    body text,
    is_read boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS: Users can only see their own notifications
ALTER TABLE notification_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own" ON notification_events 
    FOR SELECT TO authenticated 
    USING (user_id = auth.uid());

CREATE POLICY "notifications_insert" ON notification_events 
    FOR INSERT TO authenticated 
    WITH CHECK (true);  -- Service can insert for any user

CREATE POLICY "notifications_update_own" ON notification_events 
    FOR UPDATE TO authenticated 
    USING (user_id = auth.uid());

-- Index for efficient notification queries
CREATE INDEX IF NOT EXISTS idx_notification_events_user ON notification_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_events_unread ON notification_events(user_id, is_read) WHERE is_read = false;

-- =============================================================================
-- Done
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE 'Real-time messaging schema migration complete';
END $$;
