# Supabase Backend Setup for Lambdas Xi Chapter

This app uses **Supabase** as its backend when `SupabaseURL` and `SupabaseAnonKey` are set in Info.plist. Without them, it falls back to in-memory mock services.

---

## 1. Create a Supabase project

1. Go to [app.supabase.com](https://app.supabase.com) and sign in.
2. Click **New project**.
3. Choose organization, name (e.g. `lambdas-xi-chapter`), database password, and region.
4. Wait for the project to be ready.

---

## 2. Run the database migration

1. Open the file **`supabase/migrations/20250125000001_initial_schema.sql`** in your project (Cursor, Xcode, or any editor).
2. Select all (`Cmd+A`) and copy (`Cmd+C`).
3. In the Supabase Dashboard, open **SQL Editor** → **New query**.
4. Paste the SQL and click **Run** (or `Cmd+Enter`).

   This creates:
   - `invite_codes` (with `HELLOPANDA`) and RPC `validate_invite_code`
   - `profiles`, `bounties`, `bounty_applications`, `chats`, `chat_participants`, `messages`, `device_tokens`, `news_posts`
   - RLS policies and a few seed news posts.

---

## 3. Get your project URL and anon key

1. In the Dashboard, go to **Project Settings** (gear) → **API**.
2. Copy:
   - **Project URL** (e.g. `https://xxxx.supabase.co`)
   - **anon public** key (under Project API keys).

---

## 4. Configure the iOS app

1. Open `lambdas-xi-chapter/Info.plist`.
2. Set:
   - `SupabaseURL` → your Project URL.
   - `SupabaseAnonKey` → your anon key.

Replace the placeholders:

```xml
<key>SupabaseURL</key>
<string>https://YOUR_PROJECT_REF.supabase.co</string>
<key>SupabaseAnonKey</key>
<string>YOUR_ANON_KEY</string>
```

---

## 5. Deploy the auth-complete Edge Function

Magic links redirect to a small web page so users can **open in app on any device** or **copy the link and paste it in the app on another device**.

Run these in **Terminal** (macOS Terminal, iTerm, or the terminal in Cursor/VS Code). For steps 3–4, `cd` into your project folder first (e.g. `cd ~/Desktop/lambdas-xi-chapter`).

1. **Install the Supabase CLI** (one-time). On macOS with [Homebrew](https://brew.sh):
   ```bash
   brew install supabase/tap/supabase
   ```
   If you don't use Homebrew: `npm install -g supabase` or run once via `npx supabase` (see [Supabase CLI docs](https://supabase.com/docs/guides/cli)).

2. **Log in** (opens a browser to link your Supabase account):
   ```bash
   supabase login
   ```

3. **Link your project** (one-time; replace `YOUR_PROJECT_REF` with the ID from your project URL, e.g. `plubcoobeseubopkaeab`):
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```
   When prompted, enter your database password (the one you set when creating the project).

4. **Deploy the function** (from your project folder, e.g. `lambdas-xi-chapter`):
   ```bash
   supabase functions deploy auth-complete
   ```

5. The function will be at `https://YOUR_PROJECT_REF.supabase.co/functions/v1/auth-complete`.

---

## 6. Auth: Magic link and redirect URL

1. In the Dashboard, go to **Authentication** → **URL Configuration**.
2. Set **Site URL** to your Project URL, e.g. `https://YOUR_PROJECT_REF.supabase.co`.
3. Under **Redirect URLs**, add (replace `YOUR_PROJECT_REF` with your project ref):
   ```
   https://YOUR_PROJECT_REF.supabase.co/functions/v1/auth-complete
   https://YOUR_PROJECT_REF.supabase.co/functions/v1/auth-complete/**
   ```
4. Save.

   The app sends magic links with `redirectTo` set to that auth-complete URL. The auth-complete page offers **Open in app** (same device) or **Copy link** to paste in the app on another device.


---

## 7. (Optional) Email templates

Under **Authentication** → **Email Templates** you can customize the magic link email. The default is fine; keep `{{ .ConfirmationURL }}` for the link.

---

## 8. Run the app

1. Build and run in Xcode (simulator or device).
2. **Unlock:** enter invite code `HELLOPANDA`.
3. **Sign in:** enter your email; Supabase sends a magic link. Open the link in any browser, on any device. On the sign-in page: tap **Open in app** if you're on the device with the app, or **Copy link** and in the app tap **Paste link from email**.
4. **Profile:** complete the required profile fields; data is stored in `profiles`.

---

## Tables and RLS (overview)

| Table               | Purpose                          |
|---------------------|----------------------------------|
| `invite_codes`      | Valid invite codes (e.g. HELLOPANDA). |
| `profiles`          | User profiles (id = `auth.uid()`).   |
| `bounties`          | Bounty posts.                    |
| `bounty_applications` | Applications to bounties.     |
| `chats`             | One-to-one chats.                |
| `chat_participants` | Chat membership.                 |
| `messages`          | Chat messages.                   |
| `device_tokens`     | For push (APNs) later.           |
| `news_posts`        | News feed (§13).                 |

RLS is enabled so that:

- Only authenticated users can read/write as allowed (e.g. own profile, bounties they created, chats they’re in).
- `validate_invite_code` is `SECURITY DEFINER` so anon can call it for the unlock step.

---

## Troubleshooting

- **“Invalid invite code”**  
  - Ensure the migration was run and `invite_codes` contains `HELLOPANDA`.

- **Magic link: "address is invalid", "no actual link", or 404**  
  - Deploy the **auth-complete** Edge Function: `supabase functions deploy auth-complete`.
  - In **Authentication** → **URL Configuration**: set **Site URL** to your Project URL, and add **Redirect URLs** `https://YOUR_PROJECT_REF.supabase.co/functions/v1/auth-complete` and `https://YOUR_PROJECT_REF.supabase.co/functions/v1/auth-complete/**`. Save.
  - In **Authentication** → **Email Templates** → **Magic Link**: ensure the link uses `{{ .ConfirmationURL }}`.

- **"Open in app" or "Paste link" does not sign in**  
  - **Open in app:** use it on the **same device** where the app is installed. Check that Info.plist has the `lambdasxi` URL scheme.
  - **Paste link:** copy the **full** link from the sign-in page in your browser (the URL that includes `#access_token=...`), then in the app tap **Paste link from email**.

- **Profile or bounty errors**  
  - User must be logged in (`auth.uid()`).  
  - For `profiles`, `id` must equal `auth.uid()` (the app sets this on upsert).

- **No Supabase / using mocks**  
  - If `SupabaseURL` or `SupabaseAnonKey` is missing or invalid in Info.plist, the app uses in-memory mocks and does not call Supabase.
