-- Migration: authorization helpers
-- Status: Implemented (file). Unverified (Supabase CLI not installed; SQL not executed).
-- Note: Exact authorization rules from the v0.2 prototype are still unavailable;
-- these helpers follow documented Supabase patterns.
--
-- Security fix: the previous revision of this migration created
-- `public.auth_users`, a plain view over `auth.users`. Views are not subject to
-- the RLS policies of their underlying tables when they run with their owner's
-- privileges (the default in PostgreSQL 15 and earlier), so that view exposed
-- every user's id and email address to any client holding the anon key. The
-- view is dropped here and replaced with an auth helper that grants nothing.

-- Remove the over-permissive view, in case an earlier revision was applied.
DROP VIEW IF EXISTS public.auth_users;

-- Provision a profile row for every new auth user, so the app never has to
-- create `public.profiles` rows on the client.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
-- Empty search_path: every identifier in the body is schema-qualified, so a
-- caller cannot shadow `profiles` (or any other object) via search_path.
SET search_path = ''
AS $$
DECLARE
  requested_username TEXT;
BEGIN
  requested_username := NULLIF(NEW.raw_user_meta_data->>'username', '');

  IF requested_username IS NULL
     OR EXISTS (
       SELECT 1 FROM public.profiles WHERE username = requested_username
     ) THEN
    requested_username := 'user_' || replace(NEW.id::text, '-', '');
  END IF;

  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    requested_username,
    COALESCE(
      NULLIF(NEW.raw_user_meta_data->>'display_name', ''),
      split_part(NEW.email, '@', 1)
    )
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  -- Two concurrent signups can race for the same requested username. Profile
  -- provisioning must never abort the signup transaction, so fall back to a
  -- username derived from the (unique) user id.
  WHEN unique_violation THEN
    INSERT INTO public.profiles (id, username, display_name)
    VALUES (
      NEW.id,
      'user_' || replace(NEW.id::text, '-', ''),
      split_part(NEW.email, '@', 1)
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Clients trigger this function by signing up, never by calling it directly;
-- remove the EXECUTE privilege that functions get for PUBLIC by default.
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
