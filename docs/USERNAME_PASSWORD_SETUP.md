# Username/Password Authentication Setup

Your app now uses **username and password** authentication instead of email magic links! 🎉

## What Changed

### User Flow
1. **App Unlock**: Enter invite code `HELLOPANDA`
2. **Authentication**: 
   - Register with username, password, and confirm password
   - OR login with existing username and password
3. **Profile Setup**: Complete profile (if new user)
4. **Main App**: Access bounties, messages, discovery, etc.

### Technical Changes
- Switched from email magic links to username/password auth
- Added `username` field to profiles table
- Username is stored in both auth and profile
- Usernames are unique and validated (3-20 chars, alphanumeric + underscores)
- Passwords must be at least 6 characters

---

## 🚀 Setup Steps

### Step 1: Run Database Migration

1. Go to your Supabase Dashboard: [app.supabase.com](https://app.supabase.com)
2. Open your project
3. Go to **SQL Editor** (left sidebar)
4. Click **New query**
5. Copy and paste the contents of:
   ```
   supabase/migrations/20250126000001_add_username_auth.sql
   ```
6. Click **Run** (or press Cmd/Ctrl + Enter)

**What this does:**
- Adds `username` column to `profiles` table
- Creates index for fast username lookups
- Adds `check_username_available()` function to prevent duplicate usernames

### Step 2: Enable Email/Password Authentication in Supabase

1. In Supabase Dashboard, go to **Authentication** → **Providers**
2. Find **Email** provider
3. Make sure it's **enabled** (toggle ON)
4. **IMPORTANT**: Disable **"Confirm email"** setting
   - We're using username/password, not email verification
   - Scroll down in Email settings
   - Find "Confirm email" toggle
   - Set it to **OFF** (disabled)
5. Click **Save**

### Step 3: Disable Anonymous Sign-In (if enabled)

1. Still in **Authentication** → **Providers**
2. Find **Anonymous sign-ins**
3. Toggle it **OFF** (disabled)
4. Click **Save**

### Step 4: Clean Rebuild in Xcode

1. Stop the app if it's running
2. **Clean Build Folder**: `Cmd+Shift+K`
3. **Delete app from simulator**:
   - Long press app icon in simulator
   - Click X to delete
   - This clears all cached data
4. **Rebuild and run**: `Cmd+R`

---

## ✅ Testing Your Authentication

### Test Registration:

1. Launch app
2. Enter invite code: `HELLOPANDA`
3. Click **Create Account**
4. Enter:
   - **Username**: `testuser1` (3-20 chars, alphanumeric + underscore)
   - **Password**: `password123` (min 6 chars)
   - **Confirm Password**: `password123`
5. Click **Create Account**
6. Fill out profile form
7. Click **Save**
8. You should see the main app!

### Test Login:

1. Sign out from the app
2. Enter invite code: `HELLOPANDA`
3. Click **Sign In** (at bottom)
4. Enter your username and password
5. Click **Sign In**
6. You should be logged in and see the main app!

### Test Username Uniqueness:

1. Sign out and create another account
2. Try using the same username as before
3. You should see: "Username 'testuser1' is already taken"

---

## 📊 Verify in Supabase Dashboard

After registering users, you can verify everything is working:

### Check Profiles Table:

1. Go to **Table Editor** → **profiles**
2. You should see rows with:
   - `id` (UUID)
   - `username` (e.g., "testuser1")
   - `full_name`, `chapter_class`, etc.
   - All other profile fields

### Check Auth Users:

1. Go to **Authentication** → **Users**
2. You should see users with:
   - Email: `username@lambdasxi.local` (internal format)
   - Created at timestamp
   - Last sign in timestamp

**Note**: Supabase requires an email for auth, so we use `username@lambdasxi.local` internally. Users only see/enter their username!

---

## 🔧 Troubleshooting

### "Registration failed: User already registered"
- This username is already taken
- Try a different username

### "Login failed: Invalid username or password"
- Check that username is correct (case-sensitive)
- Check that password is correct
- Make sure you've registered this account first

### "Username can only contain letters, numbers, and underscores"
- Use only: a-z, A-Z, 0-9, and _ (underscore)
- No spaces or special characters

### "Username must be at least 3 characters"
- Choose a longer username (3-20 characters)

### Compilation errors after update
1. Clean build folder: `Cmd+Shift+K`
2. Delete derived data:
   - Xcode → Settings → Locations
   - Click arrow next to Derived Data path
   - Delete the folder
3. Restart Xcode
4. Rebuild: `Cmd+R`

### Can't see my old profiles
- Old profiles from anonymous/email auth won't have usernames
- You'll need to delete old test data:
  ```sql
  DELETE FROM profiles;
  ```
- Then create fresh accounts with usernames

---

## 🎯 What's Next?

Your authentication is now fully functional! Here's what you can do:

✅ **User registration and login** work with real Supabase backend  
✅ **Usernames are unique** and validated  
✅ **Profiles persist** in the database  
✅ **All app features** (bounties, messages, discovery) work with real data  

You can now focus on:
- Adding profile photos
- Implementing real-time messaging
- Adding bounty notifications
- Building out more features!

---

## 📝 Technical Details

### How Username Auth Works:

1. **Registration**:
   - User enters username and password
   - App checks if username is available via Supabase RPC
   - Converts username to `username@lambdasxi.local` for Supabase Auth
   - Creates auth user with Supabase `signUp()`
   - Username is stored in `profiles` table for display

2. **Login**:
   - User enters username and password
   - Converts username to `username@lambdasxi.local`
   - Calls Supabase `signIn()` with constructed email
   - Extracts username from email for display

3. **Storage**:
   - **Auth table**: Stores `username@lambdasxi.local` as email
   - **Profiles table**: Stores actual `username` for display
   - **App UI**: Only shows username, never the internal email

This approach lets us use Supabase's email/password auth (which is battle-tested and secure) while providing a username-based UX!
