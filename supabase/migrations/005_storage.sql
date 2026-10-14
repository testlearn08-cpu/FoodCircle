-- Migration: public recipe-image storage with user-scoped writes.
--
-- Inferred/reversible v0.2 behavior: the approved product handoff is still unavailable and this
-- migration has never been applied to a Supabase project. Revisit the bucket visibility and upload
-- limits against the handoff before any deployment.
--
-- Paths are rooted at the authenticated user's UUID (for example <user-id>/<file-name>). Public
-- reads are intentional for images attached to public recipes; writes, replacements and deletes are
-- restricted to that user's folder. The client uses only the publishable/anon key and these policies
-- are the authorization boundary.

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'recipe-images',
  'recipe-images',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS recipe_images_read_public ON storage.objects;
CREATE POLICY recipe_images_read_public
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'recipe-images');

DROP POLICY IF EXISTS recipe_images_insert_own ON storage.objects;
CREATE POLICY recipe_images_insert_own
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'recipe-images'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

DROP POLICY IF EXISTS recipe_images_update_own ON storage.objects;
CREATE POLICY recipe_images_update_own
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'recipe-images'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  )
  WITH CHECK (
    bucket_id = 'recipe-images'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

DROP POLICY IF EXISTS recipe_images_delete_own ON storage.objects;
CREATE POLICY recipe_images_delete_own
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'recipe-images'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );
