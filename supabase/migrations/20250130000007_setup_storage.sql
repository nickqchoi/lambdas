-- Create storage buckets for the app
-- 1. profile-photos: Public reading, Authenticated uploading
-- 2. chat-images: Authenticated reading/uploading

-- Enable storage extension if not already enabled (usually standard in Supabase)
-- CREATE EXTENSION IF NOT EXISTS "storage";

-- =============================================================================
-- 1. Profile Photos Bucket
-- =============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-photos', 'profile-photos', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policies for profile-photos
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'profile-photos' );

DROP POLICY IF EXISTS "Authenticated Upload" ON storage.objects;
CREATE POLICY "Authenticated Upload"
ON storage.objects FOR INSERT 
TO authenticated
WITH CHECK ( bucket_id = 'profile-photos' );

DROP POLICY IF EXISTS "Owner Update" ON storage.objects;
CREATE POLICY "Owner Update"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id = 'profile-photos' AND auth.uid() = owner );

DROP POLICY IF EXISTS "Owner Delete" ON storage.objects;
CREATE POLICY "Owner Delete"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id = 'profile-photos' AND auth.uid() = owner );


-- =============================================================================
-- 2. Chat Images Bucket
-- =============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-images', 'chat-images', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policies for chat-images
DROP POLICY IF EXISTS "Authenticated Read" ON storage.objects;
CREATE POLICY "Authenticated Read"
ON storage.objects FOR SELECT
TO authenticated
USING ( bucket_id = 'chat-images' );

DROP POLICY IF EXISTS "Authenticated Upload Chat" ON storage.objects;
CREATE POLICY "Authenticated Upload Chat"
ON storage.objects FOR INSERT 
TO authenticated
WITH CHECK ( bucket_id = 'chat-images' );

DROP POLICY IF EXISTS "Owner Delete Chat" ON storage.objects;
CREATE POLICY "Owner Delete Chat"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id = 'chat-images' AND auth.uid() = owner );
