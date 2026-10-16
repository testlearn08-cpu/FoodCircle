-- Minimal stand-in for the parts of a Supabase project that the migrations actually touch,
-- so that supabase/migrations/*.sql can be applied to a plain PostgreSQL instance and the
-- RLS policies exercised for real (see 10_rls_behaviour.sql and run.sh).
--
-- TEST INFRASTRUCTURE ONLY. Never apply this to a Supabase project: there, `auth` and the
-- anon / authenticated / service_role roles are managed by the platform.
--
-- What it reproduces, and why it matters:
--   * `auth.users`          — the table public.profiles and public.recipes point at.
--   * `auth.uid()`          — reads the `sub` claim of the request JWT, exactly like
--                             Supabase's helper. NULL for an anonymous request.
--   * the three client roles — `anon` and `authenticated` are what the anon key gets;
--                             `service_role` bypasses RLS, as it does on the platform.
--   * default privileges    — on Supabase, `anon` and `authenticated` hold ALL privileges on
--                             tables in `public`, and RLS is the *only* thing restricting
--                             them. Reproducing that here is what makes these tests
--                             meaningful: a missing grant would hide a broken policy.

create schema if not exists auth;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Supabase's own definition, minus the legacy `request.jwt.claim.sub` fallback.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Minimal test-only stand-in for the Supabase Storage tables and helper used by migration 005.
-- Supabase owns these objects in production; this stub exists only so the same policies can be
-- exercised against the PostgreSQL service used by CI.
create schema if not exists storage;

create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null references storage.buckets(id) on delete cascade,
  name text not null,
  unique (bucket_id, name)
);

create or replace function storage.foldername(object_name text)
returns text[]
language sql
immutable
as $$
  select string_to_array(object_name, '/')
$$;

alter table storage.objects enable row level security;
grant usage on schema storage to anon, authenticated, service_role;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;
grant select, insert, update, delete on storage.objects to anon, authenticated, service_role;
grant select on storage.buckets to anon, authenticated, service_role;

-- The policies call auth.uid(), and policy expressions are evaluated as the querying role.
grant usage on schema public to anon, authenticated, service_role;

alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;
