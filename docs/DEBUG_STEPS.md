# Debug Steps: Duplicate Profiles Issue

## The Problem
Seeing duplicate "Nicholas Choi" entries in Discovery, but "Marcus Kim" shows correctly in Profile tab.

## Root Causes Fixed
1. ✅ Mock seed data was being added even with Supabase enabled - FIXED
2. ✅ Profile cache wasn't being cleared on sign out - FIXED

## Next Steps

### 1. Check Your Supabase Database

Go to your Supabase Dashboard:
1. Open **Table Editor** → **profiles**
2. Check how many rows exist
3. Look for duplicate entries with the same name but different IDs

**What you should see:**
- One row for Nicholas Choi
- One row for Marcus Kim
- Each with a unique `id` (UUID)

**If you see duplicates:** Delete them in Supabase Dashboard (click the row → Delete)

### 2. Clean Restart

1. **Delete the app from simulator:**
   - Stop the app in Xcode
   - In Simulator: Long press the app icon → Delete App
   - This clears all UserDefaults and cached data

2. **Rebuild:**
   ```
   Xcode: Cmd+Shift+K (Clean Build Folder)
   Xcode: Cmd+R (Run)
   ```

3. **Test Fresh:**
   - Enter HELLOPANDA
   - Create ONLY ONE profile (e.g., "Test User 1")
   - Sign out
   - Enter HELLOPANDA
   - Create another profile (e.g., "Test User 2")
   - Go to Discovery
   - You should see ONLY "Test User 1" (not Test User 2, since that's you)

### 3. If Still Seeing Duplicates

Check the console logs when loading Discovery:
- Look for `ProfileService: discovery failed` or similar errors
- The logs will show what's being fetched from Supabase

### 4. Nuclear Option: Reset Database

If you want to start completely fresh:

1. In Supabase Dashboard → **SQL Editor**
2. Run this query:
   ```sql
   DELETE FROM profiles;
   ```
3. This clears all profiles
4. Then recreate fresh profiles in the app

---

## Expected Behavior After Fixes

✅ **Discovery Tab:**
- Shows OTHER users' profiles only
- No duplicates
- Excludes your own profile

✅ **Profile Tab:**
- Shows YOUR profile correctly
- All your information

✅ **After Sign Out:**
- Returns to HELLOPANDA screen
- All caches cleared
- Fresh state for new user
