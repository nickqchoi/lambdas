# Clerk iOS Authentication Setup Guide

This guide walks you through setting up Clerk authentication for the Lambdas Xi Chapter iOS app with Supabase integration.

## Apple Developer Account Requirements

| Feature | Without Apple Developer Account | With Apple Developer Account |
|---------|--------------------------------|------------------------------|
| Email/password auth | Yes | Yes |
| Username/password auth | Yes | Yes |
| Email verification (OTP) | Yes | Yes |
| Password reset | Yes | Yes |
| Sign in with Apple | No | Yes |
| Associated Domains | No | Yes |
| App Store submission | No | Yes |

**Bottom line**: You can develop and test the app without an Apple Developer Account using email/password authentication. You'll need the paid account ($99/year) when you're ready to submit to the App Store.

## Prerequisites

- Apple Developer Account (optional for development, required for App Store)
- Supabase project (already configured)
- Xcode 15+ with iOS 17+ target

---

## Phase 1: Clerk Dashboard Setup

### Step 1: Create Clerk Application

1. Go to [dashboard.clerk.com](https://dashboard.clerk.com)
2. Click **"Create application"**
3. Enter application name: `Lambdas Xi Chapter`
4. Select **iOS** as platform
5. Click **Create application**

### Step 2: Get Your Publishable Key

1. In your Clerk Dashboard, go to **API Keys**
2. Copy your **Publishable Key** (starts with `pk_`)
3. Save it - you'll add this to `Info.plist` later

Example format: `pk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### Step 3: Enable Native API

1. Navigate to **Native Applications** in the left sidebar
2. Click **Enable Native API** toggle (must be ON)

**If you have an Apple Developer Account ($99/year):**
3. Click **Add Native Application**
4. Enter your iOS app details:
   - **App Name**: `Lambdas Xi Chapter`
   - **App ID Prefix**: Found in Apple Developer Portal → Certificates, Identifiers & Profiles → App IDs (10-character string like `ABC123XYZ9`)
   - **Bundle ID**: Your Xcode Bundle Identifier (see below)
5. Click **Save**

**If you DON'T have an Apple Developer Account (development only):**
- Skip adding the Native Application for now
- Email/password authentication will still work
- Sign in with Apple will NOT work (requires paid account)
- You can add this later when you get an Apple Developer Account

**How to find your Bundle ID in Xcode:**
1. Open project in Xcode
2. Click project name in left sidebar
3. Select target `lambdas-xi-chapter`
4. Go to **General** tab
5. Find **Bundle Identifier** (e.g., `com.nickchoi.lambdas-xi-chapter`)

### Step 4: Configure Authentication Methods

1. Go to **User & Authentication** → **Email, Phone, Username**

2. **Email Tab**:
   - Enable **Sign-up with email** ✓
   - Enable **Sign-in with email** ✓
   - **Email verification**: Keep "Email verification code" selected (OTP)

3. **Username Tab**:
   - Enable **Sign-up with username** ✓
   - Enable **Sign-in with username** ✓

4. **Password Tab**:
   - Enable **Sign-up with password** ✓
   - Keep **Require a password at sign-up** ON
   - Set minimum password length to **8 characters** (recommended)

5. Click **Save changes**

### Step 5: Enable Sign in with Apple (OPTIONAL - Requires Apple Developer Account)

**Skip this step if you don't have an Apple Developer Account.** You can still use email/password authentication.

**If you have an Apple Developer Account:**
1. Go to **SSO connections** in the left sidebar
2. Click **Add connection**
3. Select **For all users**
4. Choose **Apple** from the provider list
5. Toggle **Enable for sign-up and sign-in** ON
6. Click **Save**

**Note**: Apple provides a privacy feature called "Hide My Email". To send emails properly to users with hidden addresses, configure your domain in Apple Developer Portal → Certificates, Identifiers & Profiles → Services → Sign in with Apple for Email Communication.

**Important for App Store**: If you plan to submit to the App Store and offer any third-party login (Google, Facebook, etc.), Apple **requires** you to also offer Sign in with Apple. This means you'll eventually need an Apple Developer Account ($99/year).

### Step 6: Connect Clerk to Supabase

1. Go to [dashboard.clerk.com/setup/supabase](https://dashboard.clerk.com/setup/supabase)
2. Click **Configure** next to Supabase
3. Select your configuration options
4. Click **Activate Supabase integration**
5. Copy the **Clerk domain** shown (e.g., `your-app.clerk.accounts.dev`)
6. Save this domain - you'll need it for Supabase setup

---

## Phase 2: Supabase Dashboard Setup

### Step 1: Add Clerk as Third-Party Auth Provider

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Authentication** → **Sign In / Up** (in left sidebar)
4. Scroll down to **Third-party providers**
5. Click **Add provider**
6. Select **Clerk** from the list
7. Paste the **Clerk domain** you copied earlier
8. Click **Save**

### Step 2: Run Database Migration

Run this SQL migration in **SQL Editor** to update RLS policies for Clerk:

```sql
-- Migration: Update RLS policies for Clerk authentication
-- Clerk user ID is in auth.jwt() ->> 'sub'

-- =============================================================================
-- 1. Update profiles table policies
-- =============================================================================
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;

-- Note: profiles.id is UUID, but Clerk sub is text (user_xxxxx format)
-- We need to store Clerk user IDs as text, OR use a mapping table
-- For simplicity, we'll update the id column to text type

-- First, let's create new policies that work with Clerk's text-based user IDs
-- We'll use a user_id text column approach

-- Add user_id column if not exists (for Clerk user ID mapping)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS clerk_user_id text UNIQUE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_clerk_user_id ON profiles(clerk_user_id);

-- Update policies to use clerk_user_id
CREATE POLICY "profiles_insert_own" ON profiles 
  FOR INSERT TO authenticated 
  WITH CHECK (clerk_user_id = (SELECT auth.jwt() ->> 'sub'));

CREATE POLICY "profiles_update_own" ON profiles 
  FOR UPDATE TO authenticated 
  USING (clerk_user_id = (SELECT auth.jwt() ->> 'sub'))
  WITH CHECK (clerk_user_id = (SELECT auth.jwt() ->> 'sub'));

-- =============================================================================
-- 2. Update bounties table policies
-- =============================================================================
DROP POLICY IF EXISTS "bounties_insert" ON bounties;
DROP POLICY IF EXISTS "bounties_update" ON bounties;

-- Add clerk_user_id column to bounties for creator tracking
ALTER TABLE bounties ADD COLUMN IF NOT EXISTS clerk_creator_id text;
CREATE INDEX IF NOT EXISTS idx_bounties_clerk_creator_id ON bounties(clerk_creator_id);

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
-- 3. Update bounty_applications policies
-- =============================================================================
DROP POLICY IF EXISTS "bounty_applications_select" ON bounty_applications;
DROP POLICY IF EXISTS "bounty_applications_insert" ON bounty_applications;
DROP POLICY IF EXISTS "bounty_applications_update" ON bounty_applications;

ALTER TABLE bounty_applications ADD COLUMN IF NOT EXISTS clerk_applicant_id text;
CREATE INDEX IF NOT EXISTS idx_bounty_applications_clerk_applicant_id ON bounty_applications(clerk_applicant_id);

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
-- 4. Update chat_participants policies
-- =============================================================================
DROP POLICY IF EXISTS "chat_participants_select" ON chat_participants;
DROP POLICY IF EXISTS "chat_participants_insert" ON chat_participants;

ALTER TABLE chat_participants ADD COLUMN IF NOT EXISTS clerk_user_id text;
CREATE INDEX IF NOT EXISTS idx_chat_participants_clerk_user_id ON chat_participants(clerk_user_id);

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
-- 5. Update messages policies
-- =============================================================================
DROP POLICY IF EXISTS "messages_select" ON messages;
DROP POLICY IF EXISTS "messages_insert" ON messages;

ALTER TABLE messages ADD COLUMN IF NOT EXISTS clerk_sender_id text;
CREATE INDEX IF NOT EXISTS idx_messages_clerk_sender_id ON messages(clerk_sender_id);

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
-- 6. Update device_tokens policies
-- =============================================================================
DROP POLICY IF EXISTS "device_tokens_select" ON device_tokens;
DROP POLICY IF EXISTS "device_tokens_insert" ON device_tokens;
DROP POLICY IF EXISTS "device_tokens_update" ON device_tokens;
DROP POLICY IF EXISTS "device_tokens_delete" ON device_tokens;

ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS clerk_user_id text;
CREATE INDEX IF NOT EXISTS idx_device_tokens_clerk_user_id ON device_tokens(clerk_user_id);

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
-- 7. Update chats policies
-- =============================================================================
DROP POLICY IF EXISTS "chats_select" ON chats;
DROP POLICY IF EXISTS "chats_update" ON chats;

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
AS $$
  SELECT auth.jwt() ->> 'sub';
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_clerk_user_id() TO authenticated;
```

---

## Phase 3: Xcode Project Setup

### Step 1: Add Clerk iOS SDK

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter the package URL: `https://github.com/clerk/clerk-ios`
3. Select version rule: **Up to Next Major Version**
4. Click **Add Package**
5. Select **Clerk** and add to target `lambdas-xi-chapter`

### Step 2: Add Associated Domains Capability (Requires Apple Developer Account)

**Skip this if you don't have an Apple Developer Account.** The app will still work for basic auth.

1. Select your project in Xcode
2. Select your app target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search and add **Associated Domains**
6. Add entry: `webcredentials:your-app.clerk.accounts.dev`
   - Replace `your-app.clerk.accounts.dev` with your actual Clerk Frontend API URL

**Note**: Without Apple Developer Account, you'll see a signing error. This is expected.

### Step 3: Add Sign in with Apple Capability (Requires Apple Developer Account)

**Skip this if you don't have an Apple Developer Account.**

1. Still in **Signing & Capabilities** tab
2. Click **+ Capability**
3. Search and add **Sign in with Apple**

**Note**: This capability requires a paid Apple Developer Account. Without it, Sign in with Apple button will not work.

### Step 4: Update Info.plist

Add the Clerk publishable key to your `Info.plist`:

```xml
<key>ClerkPublishableKey</key>
<string>pk_test_your_publishable_key_here</string>
```

Also update the URL schemes for Clerk:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>lambdasxi</string>
            <string>clerk.your-app</string>
        </array>
        <key>CFBundleURLName</key>
        <string>auth</string>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
    </dict>
</array>
```

---

## Phase 4: Testing Your Setup

### Test Sign Up Flow

1. Build and run the app
2. Tap "Create Account"
3. Enter email, username, and password
4. Check your email for verification code
5. Enter the code
6. Complete profile setup
7. Verify you can access the main app

### Test Sign In Flow

1. Sign out from the app
2. Tap "Sign In"
3. Enter your email/username and password
4. Verify you're logged in

### Test Sign in with Apple

1. Sign out from the app
2. Tap "Sign in with Apple"
3. Authenticate with Face ID / Touch ID
4. Verify account is created and you're logged in

### Test Password Reset

1. Sign out from the app
2. Tap "Forgot Password"
3. Enter your email
4. Check email for reset link
5. Click link and set new password
6. Verify you can sign in with new password

---

## Troubleshooting

### "Native API not enabled"
- Go to Clerk Dashboard → Native Applications → Enable Native API

### "Invalid publishable key"
- Double-check the key in Info.plist matches your Clerk Dashboard

### "Associated domain not configured"
- Verify the domain matches your Clerk Frontend API URL exactly
- Check the webcredentials prefix is correct
- **If you don't have Apple Developer Account**: This error is expected, ignore it for now

### "Sign in with Apple not working" or "Apple Sign In cancelled"
- Ensure the capability is added in Xcode (requires Apple Developer Account)
- Verify Apple provider is enabled in Clerk Dashboard
- Test on a real device (simulators have limited Apple Sign In support)
- **If you don't have Apple Developer Account**: This is expected. Use email/password instead.

### "Supabase RLS errors"
- Verify the Clerk-Supabase integration is activated
- Check that the migration was run successfully
- Ensure clerk_user_id columns exist in all tables

### "Signing error" or "Provisioning profile" errors in Xcode
- Without Apple Developer Account, you can only run on Simulator
- To run on a real device, you need Apple Developer Account
- For Simulator testing, these errors can often be ignored

---

## Security Notes

- **Never commit your Clerk Publishable Key** to public repositories
- Use environment-specific keys (test vs production)
- Enable Clerk's bot protection for sign-up
- Monitor your Clerk Dashboard for suspicious activity
- Regularly rotate your Supabase anon key if compromised

---

## Next Steps

After completing this setup:

1. ✅ Clerk Dashboard configured
2. ✅ Supabase third-party auth enabled
3. ✅ Database migration applied
4. ✅ Xcode capabilities added
5. ✅ Info.plist updated

The app code has been updated to use Clerk for authentication. Test all flows before deploying to production.
