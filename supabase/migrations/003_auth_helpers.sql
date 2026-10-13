-- Migration: authorization helpers
-- Status: Implemented (file). Unverified.
-- Note: Exact authorization rules from v0.2 prototype unavailable; using standard Supabase auth patterns.

-- Ensure auth.users is accessible for profile linking
-- (Supabase manages this automatically; no extra SQL required for basic auth linkage)

-- Example: create a service role helper view (optional, unverified usage)
CREATE OR REPLACE VIEW public.auth_users AS
SELECT id, email FROM auth.users;

-- Note: This view requires careful RLS. For production, restrict to service role only.
-- Since prototype rules are unavailable, this is left as a placeholder.
COMMENT ON VIEW public.auth_users IS 'Placeholder — authorization rules unverified due to missing handoff/prototype docs.';
