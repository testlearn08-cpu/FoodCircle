-- Rows shaped the way migrations 001-003 left them, inserted before 004 runs.
--
-- This exists so 20_migration_upgrade.sql can prove that 004 converts an *existing* database
-- without losing data. A migration that only works against an empty database is a migration
-- that has never been tested.
--
-- Run between 003 and 004 by supabase/tests/run.sh.

insert into auth.users (id, email, raw_user_meta_data) values
  ('66666666-6666-6666-6666-666666666666', 'legacy@example.com',
   '{"username": "legacy_cook"}'::jsonb);

-- The jsonb shape 001 defined, including the two cases that break naive conversions: an empty
-- list, and a list containing a value with a comma and a quote in it.
insert into public.recipes (id, author_id, title, description, ingredients, steps, is_public) values
  ('cccccccc-0000-0000-0000-000000000001', '66666666-6666-6666-6666-666666666666',
   'Legacy pie', 'Written before 004 existed.',
   '["flour", "butter", "salt, to taste", "the \"good\" vanilla"]'::jsonb,
   '["mix", "bake"]'::jsonb,
   true),
  ('cccccccc-0000-0000-0000-000000000002', '66666666-6666-6666-6666-666666666666',
   'Legacy water', null, '[]'::jsonb, '[]'::jsonb, false);
