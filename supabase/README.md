# Supabase Database

Status: Implemented (files). Unverified (Supabase CLI not installed; SQL has
never been executed against an instance).

## Migrations
- `001_initial_schema.sql` — Profiles, Recipes, RLS policies for both tables.
- `002_indexes_and_triggers.sql` — Indexes, `updated_at` triggers.
- `003_auth_helpers.sql` — Signup trigger that provisions profile rows.

No migration has ever been applied: there is no Supabase CLI and no running
instance in this environment. Because there is no deployed history to preserve,
the hardening below was applied in place rather than as a follow-up migration; if
these migrations ever reach a shared database, they must become immutable and
further changes must be added as new numbered files.

## Privacy Rules (Implemented but Unverified)
- Profiles: readable by anyone; insert / update / delete own only
  (`auth.uid() = id`).
- Recipes: read when public or own; insert / update / delete own only
  (`auth.uid() = author_id`).
- `recipes.author_id` is `NOT NULL`, matching what the insert policy enforces.
- Each `CREATE POLICY` is preceded by `DROP POLICY IF EXISTS`, so a partially
  applied migration can be re-run without error.

## Security Fix: `public.auth_users` removed
`003_auth_helpers.sql` previously created:

```sql
CREATE OR REPLACE VIEW public.auth_users AS
SELECT id, email FROM auth.users;
```

A PostgreSQL view runs with its owner's privileges unless `security_invoker` is
set, so it bypassed the RLS policies on `auth.users`. Supabase exposes the
`public` schema to the `anon` key, which means any client could have read every
user's id and email address. The migration now drops that view and, instead of
exposing auth data, provisions a `public.profiles` row for each new user through
a `SECURITY DEFINER` trigger function that declares an empty `search_path`,
schema-qualifies every identifier, and has `EXECUTE` revoked from `PUBLIC`.

`test/privacy_test.dart` asserts that no migration creates a view.

> Note: Exact privacy rules from the approved v0.2 prototype / development
> handoff are still unavailable in the workspace and the repo. These rules follow
> standard Flutter/Supabase patterns and must be validated against the actual
> prototype spec once the handoff document is located.
