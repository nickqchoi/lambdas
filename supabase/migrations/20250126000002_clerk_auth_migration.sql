-- Migration: Update RLS policies for Clerk authentication
-- Run this in Supabase Dashboard > SQL Editor after enabling Clerk third-party auth
-- Clerk user ID is in auth.jwt() ->> 'sub' (format: user_xxxxx)

-- =============================================================================
-- 1. Update profiles table - add clerk_user_id column
-- =============================================================================

-- Add clerk_user_id column for Clerk user ID mapping
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS clerk_user_id text UNIQUE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_clerk_user_id ON profiles(clerk_user_id);

-- Drop old policies that use auth.uid()
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;

-- Create new policies using Clerk JWT claims
CREATE POLICY "profiles_insert_own" ON profiles 
  FOR INSERT TO authenticated 
  WITH CHECK (clerk_user_id = (SELECT auth.jwt() ->> 'sub'));

CREATE POLICY "profiles_update_own" ON profiles 
  FOR UPDATE TO authenticated 
  USING (clerk_user_id = (SELECT auth.jwt() ->> 'sub'))
  WITH CHECK (clerk_user_id = (SELECT auth.jwt() ->> 'sub'));

-- =============================================================================
-- 2. Update bounties table
-- =============================================================================

-- Add clerk_creator_id column
ALTER TABLE bounties ADD COLUMN IF NOT EXISTS clerk_creator_id text;
CREATE INDEX IF NOT EXISTS idx_bounties_clerk_creator_id ON bounties(clerk_creator_id);

-- Drop old policies
DROP POLICY IF EXISTS "bounties_insert" ON bounties;
DROP POLICY IF EXISTS "bounties_update" ON bounties;

-- Create new policies
CREATE POLICY "bounties_insert" ON bounties 
  FOR INSERT TO authenticated 
  WITH CHECK (clerk_creator_id = (SELECT auth.jwt() ->> 'sub'));

CREATE POLICY "bounties_update" ON bounties 
  FOR UPDATE TO authenticated 
  USING (
    clerk_creator_id = (SELECT auth.jwt() ->> 'sub') 
    OR EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.clerk_user_id = (SELECT auth.jwt() ->> 'sub')
      AND profiles.id = bounties.accepted_applicant_id
    )
  );

-- =============================================================================
-- 3. Update bounty_applications table
-- =============================================================================

-- Add clerk_applicant_id column
ALTER TABLE bounty_applications ADD COLUMN IF NOT EXISTS clerk_applicant_id text;
CREATE INDEX IF NOT EXISTS idx_bounty_applications_clerk_applicant_id ON bounty_applications(clerk_applicant_id);

-- Drop old policies
DROP POLICY IF EXISTS "bounty_applications_select" ON bounty_applications;
DROP POLICY IF EXISTS "bounty_applications_insert" ON bounty_applications;
DROP POLICY IF EXISTS "bounty_applications_update" ON bounty_applications;

-- Create new policies
CREATE POLICY "bounty_applications_select" ON bounty_applications 
  FOR SELECT TO authenticated
  USING (
    clerk_applicant_id = (SELECT auth.jwt() ->> 'sub')
    OR EXISTS (
      SELECT 1 FROM bounties b 
      WHERE b.id = bounty_applications.bounty_id 
      AND b.clerk_creator_id = (SELECT auth.jwt() ->> 'sub')
    )
  );

CREATE POLICY "bounty_applications_insert" ON bounty_applications 
  FOR INSERT TO authenticated
  WITH CHECK (clerk_applicant_id = (SELECT auth.jwt() ->> 'sub'));

CREATE POLICY "bounty_applications_update" ON bounty_applications 
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM bounties b 
      WHERE b.id = bounty_applications.bounty_id 
      AND b.clerk_creator_id = (SELECT auth.jwt() ->> 'sub')
    )
  );

-- =============================================================================
-- 4. Update chat_participants table
-- =============================================================================

-- Add clerk_user_id column
ALTER TABLE chat_participants ADD COLUMN IF NOT EXISTS clerk_user_id text;
CREATE INDEX IF NOT EXISTS idx_chat_participants_clerk_user_id ON chat_participants(clerk_user_id);

-- Drop old policies
DROP POLICY IF EXISTS "chat_participants_select" ON chat_participants;
DROP POLICY IF EXISTS "chat_participants_insert" ON chat_participants;

-- Create new policies
CREATE POLICY "chat_participants_select" ON chat_participants 
  FOR SELECT TO authenticated
  USING (
    clerk_user_id = (SELECT auth.jwt() ->> 'sub') 
    OR EXISTS (
      SELECT 1 FROM chat_participants cp2 
      WHERE cp2.chat_id = chat_participants.chat_id 
      AND cp2.clerk_user_id = (SELECT auth.jwt() ->> 'sub')
    )
  );

CREATE POLICY "chat_participants_insert" ON chat_participants 
  FOR INSERT TO authenticated 
  WITH CHECK (true);

-- =============================================================================
-- 5. Update messages table
-- =============================================================================

-- Add clerk_sender_id column
ALTER TABLE messages ADD COLUMN IF NOT EXISTS clerk_sender_id text;
CREATE INDEX IF NOT EXISTS idx_messages_clerk_sender_id ON messages(clerk_sender_id);

-- Drop old policies
DROP POLICY IF EXISTS "messages_select" ON messages;
DROP POLICY IF EXISTS "messages_insert" ON messages;

-- Create new policies
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
    clerk_sender_id = (SELECT auth.jwt() ->> 'sub') 
    AND EXISTS (
      SELECT 1 FROM chat_participants cp 
      WHERE cp.chat_id = messages.chat_id 
      AND cp.clerk_user_id = (SELECT auth.jwt() ->> 'sub')
    )
  );

-- =============================================================================
-- 6. Update device_tokens table
-- =============================================================================

-- Add clerk_user_id column
ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS clerk_user_id text;
CREATE INDEX IF NOT EXISTS idx_device_tokens_clerk_user_id ON device_tokens(clerk_user_id);

-- Drop old policies
DROP POLICY IF EXISTS "device_tokens_select" ON device_tokens;
DROP POLICY IF EXISTS "device_tokens_insert" ON device_tokens;
DROP POLICY IF EXISTS "device_tokens_update" ON device_tokens;
DROP POLICY IF EXISTS "device_tokens_delete" ON device_tokens;

-- Create new policies
CREATE POLICY "device_tokens_select" ON device_tokens 
  FOR SELECT TO authenticated 
  USING (clerk_user_id = (SELECT auth.jwt() ->> 'sub'));

CREATE POLICY "device_tokens_insert" ON device_tokens 
  FOR INSERT TO authenticated 
  WITH CHECK (clerk_user_id = (SELECT auth.jwt() ->> 'sub'));

CREATE POLICY "device_tokens_update" ON device_tokens 
  FOR UPDATE TO authenticated 
  USING (clerk_user_id = (SELECT auth.jwt() ->> 'sub'));

CREATE POLICY "device_tokens_delete" ON device_tokens 
  FOR DELETE TO authenticated 
  USING (clerk_user_id = (SELECT auth.jwt() ->> 'sub'));

-- =============================================================================
-- 7. Update chats table policies
-- =============================================================================

-- Drop old policies
DROP POLICY IF EXISTS "chats_select" ON chats;
DROP POLICY IF EXISTS "chats_update" ON chats;

-- Create new policies
CREATE POLICY "chats_select" ON chats 
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants cp 
      WHERE cp.chat_id = chats.id 
      AND cp.clerk_user_id = (SELECT auth.jwt() ->> 'sub')
    )
  );

CREATE POLICY "chats_update" ON chats 
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants cp 
      WHERE cp.chat_id = chats.id 
      AND cp.clerk_user_id = (SELECT auth.jwt() ->> 'sub')
    )
  );

-- =============================================================================
-- 8. Helper function to get current Clerk user ID
-- =============================================================================

CREATE OR REPLACE FUNCTION get_clerk_user_id()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.jwt() ->> 'sub';
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_clerk_user_id() TO authenticated;

-- =============================================================================
-- 9. Update check_username_available function for Clerk
-- =============================================================================

CREATE OR REPLACE FUNCTION check_username_available(p_username text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT exists(
    SELECT 1 FROM profiles 
    WHERE lower(username) = lower(trim(both from p_username))
  );
$$;

-- Grant to authenticated (Clerk users can check username availability)
GRANT EXECUTE ON FUNCTION check_username_available(text) TO authenticated;
