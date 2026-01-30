-- Migration: Fix auth.uid() type mismatch in RLS policy
-- Date: 2026-01-30
-- Issue: auth.uid() with Clerk returns text (user_xxx), not UUID
-- This causes "invalid input syntax for type uuid" error

-- =============================================================================
-- 1. Fix chat_participants policy - remove auth.uid() comparison
-- =============================================================================

DROP POLICY IF EXISTS "chat_participants_select" ON chat_participants;

-- Only check clerk_user_id (text), don't try to compare user_id (UUID) with auth.uid()
CREATE POLICY "chat_participants_select" ON chat_participants 
  FOR SELECT TO authenticated
  USING (
    clerk_user_id = (SELECT auth.jwt() ->> 'sub')
  );

-- =============================================================================
-- 2. Also fix chats_select policy if needed
-- =============================================================================

DROP POLICY IF EXISTS "chats_select" ON chats;

CREATE POLICY "chats_select" ON chats 
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants cp 
      WHERE cp.chat_id = chats.id 
      AND cp.clerk_user_id = (SELECT auth.jwt() ->> 'sub')
    )
  );

-- =============================================================================
-- 3. Fix messages policies
-- =============================================================================

DROP POLICY IF EXISTS "messages_select" ON messages;
DROP POLICY IF EXISTS "messages_insert" ON messages;

CREATE POLICY "messages_select" ON messages 
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants cp 
      WHERE cp.chat_id = messages.chat_id 
      AND cp.clerk_user_id = (SELECT auth.jwt() ->> 'sub')
    )
  );

CREATE POLICY "messages_insert" ON messages 
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_participants cp 
      WHERE cp.chat_id = messages.chat_id 
      AND cp.clerk_user_id = (SELECT auth.jwt() ->> 'sub')
    )
  );

-- =============================================================================
-- 4. Log completion
-- =============================================================================
DO $$
BEGIN
  RAISE NOTICE 'Fixed auth.uid() type mismatch - now using only clerk_user_id';
END $$;
