# Supabase Database

## Status

Migrations `001`–`004` have been applied from empty and behavior-tested in CI against a disposable
`postgres:17`. Migration `005` and its Storage policy cases have also been exercised locally in
PGlite and are awaiting the next CI run. **Nothing has been applied to a Supabase project**; no such
project exists. Once a migration is deployed, it becomes append-only and future changes require a
new numbered file.

## Migrations
- `001_initial_schema.sql` — Profiles, Recipes, RLS policies for both tables.
- `002_indexes_and_triggers.sql` — Indexes, `updated_at` triggers.
- `003_auth_helpers.sql` — Signup trigger that provisions profile rows.
- `004_recipe_metadata.sql` — Recipe images URL and structured metadata; converts ingredient and step lists.
- `005_storage.sql` — Inferred public `recipe-images` bucket; reads are public and writes are confined to the authenticated user's UUID folder. The current 10 MiB limit and JPEG/PNG/WebP allowlist are provisional and must be checked against the missing handoff before deployment.

Migration `005` is still rewritable: no Supabase project exists, and the CI-only PostgreSQL test stub is not a deployment target. It deliberately adds no location, notification, or offline schema; those product requirements remain unresolved.

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
| Behavioural | `supabase/tests/10_rls_behaviour.sql` | What the policies *do* when `anon`, `authenticated` and `service_role` run the queries: public/private recipe reads, owner-only writes, signup provisioning, account cascades, and public recipe-image reads with owner-folder writes. |

The behavioural layer needs a PostgreSQL. To run it locally:

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres supabase/tests/run.sh
```

That applies, in order: the auth stub, every migration, then the suite. Each failing
expectation raises, so `psql -v ON_ERROR_STOP=1` makes it a pass/fail suite; each pass emits a
`NOTICE`, so the log shows what was verified.

### `supabase/tests/00_auth_stub.sql` is test infrastructure

It creates test-only stand-ins for the Supabase-managed objects the migrations touch — `auth.users`, `auth.uid()`, `storage.buckets`, `storage.objects`, `storage.foldername()`, and the `anon` / `authenticated` / `service_role` roles — so the migrations can be applied to plain PostgreSQL. **Never apply it to a Supabase project**, where all of that is managed by the platform.

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
- `storage.objects` allows public reads only in `recipe-images`; authenticated inserts, updates and deletes must stay under the caller's UUID folder.
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
