-- Migration: Add username field for username/password authentication
-- Run this in Supabase Dashboard > SQL Editor

-- Add username column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS username text UNIQUE;

-- Add index for faster username lookups
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- Update RLS policies to ensure username is set
-- (existing policies already cover insert/update, this just documents the requirement)

-- Optional: Create a function to check if username is available
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

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_username_available(text) TO authenticated;
