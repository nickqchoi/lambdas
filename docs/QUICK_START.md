# ⚡ Quick Start - Username/Password Auth

Your app is now ready for username/password authentication! Follow these 4 steps:

---

## ✅ Step 1: Run Database Migration

1. Go to [app.supabase.com](https://app.supabase.com)
2. Open your project
3. Click **SQL Editor** (left sidebar)
4. Click **New query**
5. Copy and paste this file's contents:
   ```
   supabase/migrations/20250126000001_add_username_auth.sql
   ```
6. Click **Run** (or Cmd+Enter)

**Expected result:** ✅ "Success. No rows returned"

---

## ✅ Step 2: Configure Supabase Auth

1. In Supabase Dashboard, go to **Authentication** → **Providers**
2. Find **Email** provider
3. Make sure it's **enabled** ✅
4. Scroll down and find "**Confirm email**" toggle
5. Set it to **OFF** (disabled) ⚠️ **IMPORTANT!**
6. Find **Anonymous sign-ins** 
7. Set it to **OFF** (disabled)
8. Click **Save**

---

## ✅ Step 3: Clean Rebuild

In Xcode:

```bash
1. Stop the app (Cmd+.)
2. Clean Build Folder (Cmd+Shift+K)
3. Delete app from simulator (long press → X)
4. Run (Cmd+R)
```

---

## ✅ Step 4: Test It!

### Create Account:
1. Launch app
2. Enter: `HELLOPANDA`
3. Enter username: `testuser1`
4. Enter password: `password123`
5. Confirm password: `password123`
6. Click **Create Account**
7. Fill out profile
8. Click **Save**

### Sign Out & Login:
1. Go to Profile tab
2. Click **Sign Out**
3. Enter: `HELLOPANDA`
4. Click "Already have an account? **Sign In**"
5. Enter: `testuser1` / `password123`
6. Click **Sign In**

**You're done! 🎉**

---

## 📖 Need More Details?

- **Full setup guide:** `USERNAME_PASSWORD_SETUP.md`
- **What changed:** `MIGRATION_SUMMARY.md`
- **Troubleshooting:** See USERNAME_PASSWORD_SETUP.md → Troubleshooting section

---

## 🐛 Something Not Working?

### "User already registered"
→ Username taken, try another

### "Invalid username or password"  
→ Check spelling, or register first

### Old test data conflicts
→ Delete profiles in Supabase:
```sql
DELETE FROM profiles;
```

### Build errors
→ Clean build folder, delete derived data, restart Xcode

---

That's it! You now have fully functional username/password authentication with Supabase! 🚀
