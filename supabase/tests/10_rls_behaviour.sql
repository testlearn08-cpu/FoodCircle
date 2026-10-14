-- Behavioural tests for the privacy rules in supabase/migrations.
--
-- test/privacy_test.dart asserts that the policy SQL is still *written* the way it should be.
-- This file asserts that the policies *behave*: it runs every statement as the role a real
-- client would use (`anon`, `authenticated`, `service_role`), with a JWT claim set, and checks
-- what each role can actually see and change.
--
-- Each failing expectation raises, so `psql -v ON_ERROR_STOP=1` (see run.sh) turns this into a
-- pass/fail suite. Every pass emits a NOTICE, so the log shows what was verified.
--
-- Every block sets the `role` and `request.jwt.claims` it needs with set_config(..., true),
-- i.e. SET LOCAL, and never inherits them: psql runs one transaction per statement (so SET
-- LOCAL evaporates between blocks) whereas a client that sends this file as a single query
-- does not, and a suite that behaves differently depending on its runner is worthless.

-- ---------------------------------------------------------------------------------------------
-- Fixtures, created as the owner (a superuser here, which bypasses RLS — that is deliberate,
-- so the fixture data is identical no matter what the policies do).
-- ---------------------------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com',
   '{"username": "alice_cooks", "display_name": "Alice"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com',
   '{"username": "bob_bakes"}'::jsonb);

insert into public.recipes (id, author_id, title, is_public) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'Public soup', true),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'Secret sauce', false),
  ('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   'Bob''s private pie', false);

-- ---------------------------------------------------------------------------------------------
-- 1-8: schema-level guarantees
-- ---------------------------------------------------------------------------------------------

do $$
declare
  n int;
begin
  perform set_config('role', 'none', true);
  select count(*) into n
  from pg_class c
  join pg_namespace s on s.oid = c.relnamespace
  where s.nspname = 'public'
    and c.relname in ('profiles', 'recipes')
    and c.relrowsecurity;

  if n <> 2 then
    raise exception 'expected RLS to be enabled on both public tables, found % of 2', n;
  end if;
  raise notice 'ok  1. RLS is enabled on public.profiles and public.recipes';
end
$$;

do $$
declare
  n int;
begin
  perform set_config('role', 'none', true);
  select count(*) into n from pg_views where schemaname = 'public';
  if n <> 0 then
    raise exception 'public exposes % view(s); a view runs with its owner''s privileges and can bypass RLS', n;
  end if;
  raise notice 'ok  2. the public schema contains no views (no auth.users leak)';
end
$$;

do $$
declare
  n int;
  v_username text;
  v_display_name text;
begin
  perform set_config('role', 'none', true);
  select count(*) into n from public.profiles
  where id in ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
  if n <> 2 then
    raise exception 'the signup trigger provisioned % profiles, expected 2', n;
  end if;

  select p.username, p.display_name into v_username, v_display_name
  from public.profiles p where p.id = '11111111-1111-1111-1111-111111111111';

  if v_username <> 'alice_cooks' then
    raise exception 'expected the requested username to be honoured, got %', v_username;
  end if;
  if v_display_name <> 'Alice' then
    raise exception 'expected display_name from signup metadata, got %', v_display_name;
  end if;
  raise notice 'ok  3. signup provisions a profile with the requested username and display name';
end
$$;

do $$
declare
  v_username text;
begin
  perform set_config('role', 'none', true);
  insert into auth.users (id, email, raw_user_meta_data) values
    ('33333333-3333-3333-3333-333333333333', 'carol@example.com',
     '{"username": "alice_cooks"}'::jsonb);

  select p.username into v_username
  from public.profiles p where p.id = '33333333-3333-3333-3333-333333333333';
  if v_username <> 'user_33333333333333333333333333333333' then
    raise exception 'a duplicate username must fall back to user_<id>, got %', v_username;
  end if;
  raise notice 'ok  4. a duplicate username does not abort signup (% was taken)', v_username;
end
$$;

do $$
declare
  v_username text;
  v_display_name text;
begin
  perform set_config('role', 'none', true);
  insert into auth.users (id, email) values
    ('44444444-4444-4444-4444-444444444444', 'dave@example.com');

  select p.username, p.display_name into v_username, v_display_name
  from public.profiles p where p.id = '44444444-4444-4444-4444-444444444444';

  if v_username <> 'user_44444444444444444444444444444444' then
    raise exception 'expected a derived username, got %', v_username;
  end if;
  if v_display_name <> 'dave' then
    raise exception 'expected display_name to default to the email local part, got %', v_display_name;
  end if;
  raise notice 'ok  5. signup without metadata derives a username and display name';
end
$$;

do $$
declare
  t0 timestamptz := timestamptz '2000-01-01 00:00:00+00';
  after_ts timestamptz;
begin
  perform set_config('role', 'none', true);
  -- Supplying an ancient updated_at is the point: the trigger must overwrite whatever the
  -- client sends, including a value the client is not allowed to choose.
  update public.profiles
     set bio = 'bakes on Sundays', updated_at = t0
   where id = '22222222-2222-2222-2222-222222222222';

  select p.updated_at into after_ts from public.profiles p
  where p.id = '22222222-2222-2222-2222-222222222222';

  if after_ts <= t0 then
    raise exception 'the trigger did not overwrite the supplied updated_at (still %)', after_ts;
  end if;
  raise notice 'ok  6. the updated_at trigger overwrites a client-supplied timestamp';
end
$$;

do $$
declare
  denied boolean := false;
  detail text;
begin
  perform set_config('role', 'none', true);
  begin
    insert into public.recipes (author_id, title) values (null, 'no author');
  exception when others then
    denied := true;
    detail := sqlerrm;
  end;

  if not denied then
    raise exception 'a recipe without an author was accepted';
  end if;
  if detail not like '%not-null%' then
    raise exception 'expected a not-null violation, got: %', detail;
  end if;
  raise notice 'ok  7. a recipe always has an author';
end
$$;

do $$
declare
  denied boolean := false;
  detail text;
begin
  perform set_config('role', 'none', true);
  begin
    insert into public.recipes (author_id, title) values
      ('99999999-9999-9999-9999-999999999999', 'orphan');
  exception when others then
    denied := true;
    detail := sqlerrm;
  end;

  if not denied or detail not like '%foreign key%' then
    raise exception 'expected a foreign key violation for an unknown author, got: %', detail;
  end if;
  raise notice 'ok  8. a recipe cannot be authored by a user that does not exist';
end
$$;

-- ---------------------------------------------------------------------------------------------
-- 9-14: what each role can READ
-- ---------------------------------------------------------------------------------------------

do $$
declare
  n int;
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);

  select count(*) into n from public.recipes;
  if n <> 1 then
    raise exception 'an anonymous client should see exactly the 1 public recipe, saw %', n;
  end if;
  raise notice 'ok  9. anon sees public recipes and nothing else';
end
$$;

do $$
declare
  n int;
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);

  select count(*) into n from public.recipes
  where id = 'aaaaaaaa-0000-0000-0000-000000000002';
  if n <> 0 then
    raise exception 'a private recipe was visible to an anonymous client';
  end if;
  raise notice 'ok 10. anon cannot reach a private recipe, even by id';
end
$$;

do $$
declare
  n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

  select count(*) into n from public.recipes
  where id = 'aaaaaaaa-0000-0000-0000-000000000002';
  if n <> 1 then
    raise exception 'an author could not read their own private recipe';
  end if;
  raise notice 'ok 11. an author reads their own private recipe';
end
$$;

do $$
declare
  n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

  select count(*) into n from public.recipes
  where id = 'aaaaaaaa-0000-0000-0000-000000000002';
  if n <> 0 then
    raise exception 'another user could read a private recipe';
  end if;

  select count(*) into n from public.recipes
  where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if n <> 1 then
    raise exception 'a signed-in user could not read a public recipe';
  end if;
  raise notice 'ok 12. another signed-in user sees public recipes but not private ones';
end
$$;

do $$
declare
  n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

  select count(*) into n from public.profiles
  where id = '11111111-1111-1111-1111-111111111111';
  if n <> 1 then
    raise exception 'profiles are supposed to be readable by any signed-in user';
  end if;
  raise notice 'ok 13. any signed-in user can read a profile';
end
$$;

do $$
declare
  n int;
begin
  perform set_config('role', 'service_role', true);

  select count(*) into n from public.recipes;
  if n <> 3 then
    raise exception 'service_role should bypass RLS and see all 3 recipes, saw %', n;
  end if;
  raise notice 'ok 14. service_role bypasses RLS';
end
$$;

-- ---------------------------------------------------------------------------------------------
-- 15-20: what each role can WRITE
-- ---------------------------------------------------------------------------------------------

do $$
declare
  denied boolean := false;
  detail text;
  n int;
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);

  begin
    insert into public.recipes (author_id, title)
    values ('11111111-1111-1111-1111-111111111111', 'anon recipe');
  exception when others then
    denied := true;
    detail := sqlerrm;
  end;

  if not denied then
    raise exception 'an anonymous client was able to insert a recipe';
  end if;
  if detail not like '%row-level security%' then
    raise exception 'expected an RLS violation (not a missing grant), got: %', detail;
  end if;
  raise notice 'ok 15. anon cannot insert a recipe (RLS, not a missing grant)';
end
$$;

do $$
declare
  denied boolean := false;
  detail text;
  n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

  insert into public.recipes (author_id, title)
  values ('11111111-1111-1111-1111-111111111111', 'Alice''s new cake');

  select count(*) into n from public.recipes where title = 'Alice''s new cake';
  if n <> 1 then
    raise exception 'an author could not insert their own recipe';
  end if;

  begin
    insert into public.recipes (author_id, title)
    values ('22222222-2222-2222-2222-222222222222', 'Recipe attributed to Bob');
  exception when others then
    denied := true;
    detail := sqlerrm;
  end;

  if not denied then
    raise exception 'a user was able to insert a recipe attributed to someone else';
  end if;
  if detail not like '%row-level security%' then
    raise exception 'expected an RLS violation, got: %', detail;
  end if;
  raise notice 'ok 16. an author can insert their own recipe, but not one attributed to someone else';
end
$$;

do $$
declare
  n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

  update public.recipes set title = 'hijacked'
  where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  get diagnostics n = row_count;

  if n <> 0 then
    raise exception 'another user updated % row(s) of someone else''s recipe', n;
  end if;
  raise notice 'ok 17. a user cannot update someone else''s recipe';
end
$$;

do $$
declare
  n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

  update public.recipes set title = 'Public soup, revised'
  where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  get diagnostics n = row_count;

  if n <> 1 then
    raise exception 'an author updated % rows of their own recipe, expected 1', n;
  end if;
  raise notice 'ok 18. an author can update their own recipe';
end
$$;

do $$
declare
  n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

  delete from public.recipes where id = 'aaaaaaaa-0000-0000-0000-000000000002';
  get diagnostics n = row_count;

  if n <> 0 then
    raise exception 'another user deleted % row(s) of someone else''s recipe', n;
  end if;
  raise notice 'ok 19. a user cannot delete someone else''s recipe';
end
$$;

do $$
declare
  n int;
  detail text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

  delete from public.recipes where id = 'aaaaaaaa-0000-0000-0000-000000000002';
  get diagnostics n = row_count;
  if n <> 1 then
    raise exception 'an author deleted % rows of their own recipe, expected 1', n;
  end if;

  update public.profiles set username = 'alice_cooks' where id = '11111111-1111-1111-1111-111111111111';
  get diagnostics n = row_count;
  if n <> 1 then
    raise exception 'a user updated % rows of their own profile, expected 1', n;
  end if;

  update public.profiles set username = 'alice_cooks' where id = '22222222-2222-2222-2222-222222222222';
  get diagnostics n = row_count;
  if n <> 0 then
    raise exception 'a user updated % rows of someone else''s profile', n;
  end if;

  begin
    insert into public.profiles (id, username)
    values ('22222222-2222-2222-2222-222222222222', 'bob_second_account');
    raise exception 'a user inserted a profile row for someone else';
  exception
    when others then
      if sqlerrm like '%inserted a profile row%' then
        raise;
      end if;
      if sqlerrm not like '%row-level security%' then
        raise exception 'expected an RLS violation inserting a foreign profile, got: %', sqlerrm;
      end if;
  end;

  raise notice 'ok 20. profile writes are limited to the owner on update and insert';
end
$$;

-- ---------------------------------------------------------------------------------------------
-- 21: cascades (an account deletion must not leave rows behind)
-- ---------------------------------------------------------------------------------------------

do $$
declare
  n int;
begin
  perform set_config('role', 'none', true);
  insert into auth.users (id, email) values
    ('55555555-5555-5555-5555-555555555555', 'erin@example.com');
  insert into public.recipes (author_id, title) values
    ('55555555-5555-5555-5555-555555555555', 'Erin''s recipe');

  delete from auth.users where id = '55555555-5555-5555-5555-555555555555';

  select count(*) into n from public.profiles where id = '55555555-5555-5555-5555-555555555555';
  if n <> 0 then
    raise exception 'deleting an auth user left % profile row(s)', n;
  end if;

  select count(*) into n from public.recipes
  where author_id = '55555555-5555-5555-5555-555555555555';
  if n <> 0 then
    raise exception 'deleting an auth user left % recipe(s)', n;
  end if;
  raise notice 'ok 21. deleting an account cascades to its profile and recipes';
end
$$;
