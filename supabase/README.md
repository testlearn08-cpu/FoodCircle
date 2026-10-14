# Supabase Database

## Status

**Applied and behaviourally tested.** The migrations are applied from empty on every run of
the `Database behaviour (RLS)` CI job against a real `postgres:17`, and the policies are then
exercised as the roles a client actually gets. They have still never been applied to a real
Supabase project — when that happens, they become immutable and every further change must be
a new numbered file.

## Migrations
- `001_initial_schema.sql` — Profiles, Recipes, RLS policies for both tables.
- `002_indexes_and_triggers.sql` — Indexes, `updated_at` triggers.
- `003_auth_helpers.sql` — Signup trigger that provisions profile rows.

Each `CREATE POLICY` is preceded by `DROP POLICY IF EXISTS`, so a partially applied migration
can be re-run.

`001` no longer creates the **`uuid-ossp`** extension: `recipes.id` uses `gen_random_uuid()`,
which has been in core PostgreSQL since 13. The extension bought nothing and made the schema
depend on something a stock PostgreSQL does not ship — which the test suite below needs.

## How the policies are verified

Two layers, deliberately:

| Layer | File | Proves |
|---|---|---|
| Static | `test/privacy_test.dart` (+ `tool/check_sql_expectations.py`) | The policy text still says what it should. Fast, runs locally, catches an edit that weakens a policy in review. |
| Behavioural | `supabase/tests/10_rls_behaviour.sql` | What the policies *do* when `anon`, `authenticated` and `service_role` run the queries: who can read a private recipe, who can insert on someone else's behalf, whether the signup trigger provisions exactly one profile, whether deleting an account cascades. |

The behavioural layer needs a PostgreSQL. To run it locally:

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres supabase/tests/run.sh
```

That applies, in order: the auth stub, every migration, then the suite. Each failing
expectation raises, so `psql -v ON_ERROR_STOP=1` makes it a pass/fail suite; each pass emits a
`NOTICE`, so the log shows what was verified.

### `supabase/tests/00_auth_stub.sql` is test infrastructure

It creates the parts of a Supabase project the migrations touch — `auth.users`, `auth.uid()`,
the `anon` / `authenticated` / `service_role` roles — so the migrations can be applied to a
plain PostgreSQL. **Never apply it to a Supabase project**, where all of that is managed by the
platform.

It grants `anon` and `authenticated` **all** privileges on tables in `public`, exactly as
Supabase does. That is what makes the tests meaningful: on a project like this, RLS is the only
thing standing between an anonymous client and your data, and a policy that is merely absent
looks identical to a policy that is present and wrong.

## Privacy Rules (verified behaviourally)

- Profiles: readable by anyone; insert / update / delete own only (`auth.uid() = id`).
- Recipes: read when public or own; insert / update / delete own only
  (`auth.uid() = author_id`).
- `recipes.author_id` is `NOT NULL`, matching what the insert policy enforces.
- An anonymous client sees public recipes and nothing else, and cannot insert at all.
- `service_role` bypasses RLS — it must never reach a client bundle.

## Security fix: `public.auth_users` (kept out)

`003_auth_helpers.sql` previously created:

```sql
CREATE OR REPLACE VIEW public.auth_users AS
SELECT id, email FROM auth.users;
```

A PostgreSQL view runs with its owner's privileges unless `security_invoker` is set, so it
bypassed the RLS policies on `auth.users`. Supabase exposes the `public` schema to the `anon`
key, which means any client could have read every user's id and email address. The migration
drops that view and, instead, provisions a `public.profiles` row for each new user through a
`SECURITY DEFINER` trigger function that declares an empty `search_path`, schema-qualifies
every identifier, and has `EXECUTE` revoked from `PUBLIC`.

Two independent checks keep it that way: `test/privacy_test.dart` asserts no migration creates
a view, and test 2 of the behavioural suite asserts the `public` schema contains no views at all.
