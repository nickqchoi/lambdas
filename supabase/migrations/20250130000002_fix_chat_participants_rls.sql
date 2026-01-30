-- Migration: Fix infinite recursion in chat_participants RLS policy
-- Date: 2026-01-30
-- Issue: PostgrestError code 42P17 - "infinite recursion detected in policy for relation chat_participants"
-- Root cause: chat_participants_select policy references itself in a subquery

-- =============================================================================
-- 1. Fix chat_participants policy - remove self-reference
-- =============================================================================

-- Drop the problematic policy
DROP POLICY IF EXISTS "chat_participants_select" ON chat_participants;

-- Create fixed policy that doesn't self-reference
-- Users can see chat_participants rows where:
-- 1. They are the participant (clerk_user_id matches)
-- 2. They are associated via user_id (for backward compatibility)
-- Note: We use a simple check - users can see their own participant records
-- The chats table policy handles visibility of chats they're in
CREATE POLICY "chat_participants_select" ON chat_participants 
  FOR SELECT TO authenticated
  USING (
    -- Can see your own participation
    clerk_user_id = (SELECT auth.jwt() ->> 'sub')
    -- Or legacy user_id matches
    OR user_id = auth.uid()
  );

-- =============================================================================
-- 2. Add policy to allow inserting participants for chats you just created
-- =============================================================================

-- Drop and recreate insert policy to be more permissive during chat creation
DROP POLICY IF EXISTS "chat_participants_insert" ON chat_participants;

-- Allow authenticated users to insert participants (needed for chat creation)
-- The app layer enforces that you can only add yourself and one other person
CREATE POLICY "chat_participants_insert" ON chat_participants 
  FOR INSERT TO authenticated 
  WITH CHECK (true);

-- =============================================================================
-- 3. Also need to fix chats_insert policy for chat creation
-- =============================================================================

-- Allow authenticated users to create chats
DROP POLICY IF EXISTS "chats_insert" ON chats;

CREATE POLICY "chats_insert" ON chats 
  FOR INSERT TO authenticated 
  WITH CHECK (true);

-- =============================================================================
-- 4. Log completion
-- =============================================================================
DO $$
BEGIN
  RAISE NOTICE 'Fixed chat_participants RLS infinite recursion issue';
END $$;
