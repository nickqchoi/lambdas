# Temporary Testing Setup (No Email Required)

## Quick Setup to Test Supabase Functionality

### 1. Enable Anonymous Sign-In in Supabase

1. Go to your Supabase Dashboard: [app.supabase.com](https://app.supabase.com)
2. Open your project
3. Go to **Authentication** → **Providers**
4. Find **Anonymous sign-ins** and toggle it **ON**
5. Click **Save**

### 2. Rebuild and Run

In Xcode:
- `Cmd+Shift+K` (Clean Build Folder)
- `Cmd+R` (Run)

---

## How It Works Now

**Flow:**
1. ✅ **HELLOPANDA** unlock screen (required every time you restart)
2. ✅ Enter any email → Click "Sign In" → Instant login (no email verification!)
3. ✅ Complete your profile → **Saves to Supabase** ✅
4. ✅ Create bounties → **Saves to Supabase** ✅
5. ✅ Apply to bounties → **Saves to Supabase** ✅
6. ✅ All data persists in your database!

**What's happening behind the scenes:**
- Uses Supabase **anonymous sign-in** (creates a real authenticated session)
- You get a real UUID from Supabase auth
- All RLS policies work correctly
- All data persists to your Supabase database
- **No email verification required!**

---

## Testing Checklist

### Test 1: Profile Persistence
1. Create profile "User A" with email `usera@test.com`
2. Sign out
3. Enter HELLOPANDA again
4. Create profile "User B" with email `userb@test.com`
5. Go to **Discovery** tab
6. ✅ You should see "User A" in the discovery list!

### Test 2: Bounty Creation
1. Go to **Bounties** tab
2. Click `+` to create a bounty
3. Fill in details and save
4. Sign out and sign in as a different user
5. ✅ You should see the bounty you created!

### Test 3: Applications
1. As "User B", apply to a bounty created by "User A"
2. Sign out and sign in as "User A"
3. Open the bounty
4. ✅ You should see the application from "User B"!

---

## To Restore Email Authentication Later

Just uncomment the code in:
- `AuthService.swift` (lines marked with `/* COMMENTED OUT - Original email magic link code */`)
- `AuthView.swift` (restore the "Check your email" message)

Then disable anonymous sign-in in Supabase Dashboard.

---

## Verifying Data in Supabase

Check your Supabase Dashboard:
1. Go to **Table Editor**
2. Check these tables:
   - **profiles** → Should show all created profiles
   - **bounties** → Should show all bounties
   - **bounty_applications** → Should show applications
   - **chats** → Will populate when you message someone or accept a bounty
   - **messages** → Will populate when you send messages

All data should persist and be visible!
