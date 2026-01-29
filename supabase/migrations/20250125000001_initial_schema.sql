-- Lambdas Xi Chapter – Initial schema for Supabase backend
-- Run this in Supabase Dashboard > SQL Editor, or via: supabase db push
-- §16.3 Data Models: User (auth.users), Profile, Skill (in profiles), Bounty, Application, Chat, Message, DeviceToken, NewsPost

-- =============================================================================
-- 1. Invite codes §4.1 – server-side validation. RPC for anon-safe check.
-- =============================================================================
CREATE TABLE IF NOT EXISTS invite_codes (
  code text PRIMARY KEY
);

-- Seed the canonical invite code §4.1
INSERT INTO invite_codes (code) VALUES ('HELLOPANDA') ON CONFLICT (code) DO NOTHING;

-- RPC: validate invite code (callable by anon for unlock flow). §4.1 server-side.
CREATE OR REPLACE FUNCTION validate_invite_code(p_code text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT exists(SELECT 1 FROM invite_codes WHERE code = trim(both from p_code));
$$;

-- =============================================================================
-- 2. Profiles §6 – id = auth.uid(); skills stored as jsonb.
-- =============================================================================
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY,
  full_name text NOT NULL DEFAULT '',
  chapter_class text NOT NULL DEFAULT '',
  role_tag text NOT NULL DEFAULT 'Active' CHECK (role_tag IN ('Alumni', 'Active')),
  graduation_year text NOT NULL DEFAULT '',
  major_or_industry text NOT NULL DEFAULT '',
  skills jsonb NOT NULL DEFAULT '[]',
  short_bio text NOT NULL DEFAULT '',
  profile_photo_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS: own row for insert/update; all authenticated can read (Discovery §8.1)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select" ON profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- =============================================================================
-- 3. Bounties §9
-- =============================================================================
CREATE TABLE IF NOT EXISTS bounties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  skill_tags jsonb NOT NULL DEFAULT '[]',
  estimated_effort text,
  deadline timestamptz,
  creator_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'In Progress', 'Completed')),
  accepted_applicant_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bounties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bounties_select" ON bounties FOR SELECT TO authenticated USING (true);
CREATE POLICY "bounties_insert" ON bounties FOR INSERT TO authenticated WITH CHECK (creator_id = auth.uid());
CREATE POLICY "bounties_update" ON bounties FOR UPDATE TO authenticated USING (creator_id = auth.uid() OR accepted_applicant_id = auth.uid());

-- =============================================================================
-- 4. Bounty applications §10
-- =============================================================================
CREATE TABLE IF NOT EXISTS bounty_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bounty_id uuid NOT NULL REFERENCES bounties(id) ON DELETE CASCADE,
  applicant_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  message text,
  status text NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Accepted', 'Rejected')),
  applied_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(bounty_id, applicant_id)
);

ALTER TABLE bounty_applications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bounty_applications_select" ON bounty_applications FOR SELECT TO authenticated
  USING (
    applicant_id = auth.uid()
    OR exists(SELECT 1 FROM bounties b WHERE b.id = bounty_applications.bounty_id AND b.creator_id = auth.uid())
  );
CREATE POLICY "bounty_applications_insert" ON bounty_applications FOR INSERT TO authenticated
  WITH CHECK (applicant_id = auth.uid());
CREATE POLICY "bounty_applications_update" ON bounty_applications FOR UPDATE TO authenticated
  USING (exists(SELECT 1 FROM bounties b WHERE b.id = bounty_applications.bounty_id AND b.creator_id = auth.uid()));

-- =============================================================================
-- 5. Chats §12 – one-to-one; chat_participants for the two users.
-- =============================================================================
CREATE TABLE IF NOT EXISTS chats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bounty_id uuid REFERENCES bounties(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz
);

CREATE TABLE IF NOT EXISTS chat_participants (
  chat_id uuid NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (chat_id, user_id)
);

ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chats_select" ON chats FOR SELECT TO authenticated
  USING (exists(SELECT 1 FROM chat_participants cp WHERE cp.chat_id = chats.id AND cp.user_id = auth.uid()));
CREATE POLICY "chats_insert" ON chats FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "chats_update" ON chats FOR UPDATE TO authenticated
  USING (exists(SELECT 1 FROM chat_participants cp WHERE cp.chat_id = chats.id AND cp.user_id = auth.uid()));

CREATE POLICY "chat_participants_select" ON chat_participants FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR exists(SELECT 1 FROM chat_participants cp2 WHERE cp2.chat_id = chat_participants.chat_id AND cp2.user_id = auth.uid()));
CREATE POLICY "chat_participants_insert" ON chat_participants FOR INSERT TO authenticated WITH CHECK (true);

-- =============================================================================
-- 6. Messages §12
-- =============================================================================
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id uuid NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  body text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messages_select" ON messages FOR SELECT TO authenticated
  USING (exists(SELECT 1 FROM chat_participants cp WHERE cp.chat_id = messages.chat_id AND cp.user_id = auth.uid()));
CREATE POLICY "messages_insert" ON messages FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid() AND exists(SELECT 1 FROM chat_participants cp WHERE cp.chat_id = messages.chat_id AND cp.user_id = auth.uid()));

-- Trigger: update chats.last_message_at when a message is inserted
CREATE OR REPLACE FUNCTION set_chat_last_message_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE chats SET last_message_at = NEW.sent_at, updated_at = NEW.sent_at WHERE id = NEW.chat_id;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS tr_messages_set_last ON messages;
CREATE TRIGGER tr_messages_set_last AFTER INSERT ON messages FOR EACH ROW EXECUTE FUNCTION set_chat_last_message_at();

-- =============================================================================
-- 7. Device tokens §14.2 – for push notifications
-- =============================================================================
CREATE TABLE IF NOT EXISTS device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, token)
);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_tokens_select" ON device_tokens FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "device_tokens_insert" ON device_tokens FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "device_tokens_update" ON device_tokens FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "device_tokens_delete" ON device_tokens FOR DELETE TO authenticated USING (user_id = auth.uid());

-- =============================================================================
-- 8. News posts §13 – read-only for users; admin posts via dashboard/backend
-- =============================================================================
CREATE TABLE IF NOT EXISTS news_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  image_url text,
  pdf_url text,
  author_name text,
  published_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE news_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "news_posts_select" ON news_posts FOR SELECT TO authenticated USING (true);
-- Insert/update/delete: only service role (admin). No policy = only service_role can modify.

-- Seed a few news posts for demo (run once on fresh DB)
INSERT INTO news_posts (title, body, author_name, published_at) VALUES
  ('Spring 2025 Rush Recap', 'Another great rush season. Thanks to all actives and alumni who helped make it happen.', 'Chapter Leadership', now() - interval '5 days'),
  ('Alumni Networking Night', 'Join us March 15 at the chapter house for an evening of networking and updates. RSVP by March 10.', 'Programming Chair', now() - interval '2 days'),
  ('Welcome New Officers', 'Congratulations to the new exec board. We''re excited for the year ahead.', 'President', now() - interval '10 days');
