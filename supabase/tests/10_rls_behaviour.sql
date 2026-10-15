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

-- ---------------------------------------------------------------------------------------------
-- 22-27: search (migration 006)
--
-- These need recipes with ingredients and tags, which the fixtures above deliberately do not
-- have. They insert their own and delete them again at the end, so the table is left exactly as
-- the earlier checks found it — check 14 asserts a total row count, and a test that changes what
-- a later test sees is a test that fails for the wrong reason.
-- ---------------------------------------------------------------------------------------------

do $$
declare
  n int;
begin
  perform set_config('role', 'none', true);
  insert into public.recipes (id, author_id, title, ingredients, tags, is_public) values
    ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
     'Lentil soup', array['1 cup red lentils', '1 tsp turmeric'], array['vegetarian', 'weeknight'], true),
    ('cccccccc-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
     'Secret lentil stew', array['1 cup green lentils'], array['vegetarian'], false),
    ('cccccccc-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222',
     'Bob''s lentil bake', array['lentils, tinned'], array['baking'], false),
    ('cccccccc-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222',
     'Discount day', array['50% off mince'], array['weeknight'], true);

  -- 22. anon reach: the public match is found, the two private ones are not.
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);

  -- Exactly one public fixture matches "lentil" by title ("Lentil soup"); "Discount day" is
  -- public too but contains no lentil. The two private lentil recipes must not appear.
  select count(*) into n from public.search_recipes(q => 'lentil');
  if n <> 1 then
    raise exception 'anon search for "lentil" returned % rows, expected 1 (the public match)', n;
  end if;

  select count(*) into n from public.search_recipes(q => 'lentil')
  where id = 'cccccccc-0000-0000-0000-000000000002';
  if n <> 0 then
    raise exception 'search leaked a private recipe to anon';
  end if;

  -- The ingredient match is the point: "red lentils" has to match the query "lentil".
  select count(*) into n from public.search_recipes(q => 'red lentils');
  if n <> 1 then
    raise exception 'ingredient search returned % rows, expected the one with "1 cup red lentils"', n;
  end if;
  raise notice 'ok 22. anon can search ingredients, and only sees public matches';

  -- 23. an author finds their own private recipe; someone else does not.
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

  select count(*) into n from public.search_recipes(q => 'secret');
  if n <> 1 then
    raise exception 'an author could not find their own private recipe by search (% rows)', n;
  end if;

  perform set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

  select count(*) into n from public.search_recipes(q => 'secret');
  if n <> 0 then
    raise exception 'search showed someone else''s private recipe (% rows)', n;
  end if;
  raise notice 'ok 23. search respects the visibility rule for signed-in users too';

  -- 24. matching is case-insensitive, on the title and on an ingredient.
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);

  select count(*) into n from public.search_recipes(q => 'LENTIL SOUP');
  if n <> 1 then
    raise exception 'title search should be case-insensitive, matched %', n;
  end if;

  select count(*) into n from public.search_recipes(q => 'TURMERIC');
  if n <> 1 then
    raise exception 'ingredient search should be case-insensitive, matched %', n;
  end if;
  raise notice 'ok 24. search is case-insensitive over titles and ingredients';

  -- 25. the tag filter narrows, and combines with the text query.
  select count(*) into n from public.search_recipes(tag => 'weeknight');
  if n <> 2 then
    raise exception 'tag filter returned % rows, expected 2', n;
  end if;

  select count(*) into n from public.search_recipes(q => 'lentil', tag => 'weeknight');
  if n <> 1 then
    raise exception 'query+tag returned % rows, expected 1', n;
  end if;

  select count(*) into n from public.search_recipes(tag => 'not-a-tag');
  if n <> 0 then
    raise exception 'an unknown tag matched % rows', n;
  end if;
  raise notice 'ok 25. the tag filter narrows a search and combines with the text query';

  -- 26. `%` and `_` are literals in a query, not wildcards.
  --
  -- Note for anyone editing the messages below: a `%` inside a RAISE string is a format
  -- placeholder, so these deliberately spell "percent" out. Writing a bare one here fails at
  -- runtime with "too few parameters specified for RAISE" — which is how this check was
  -- written the first time.
  perform set_config('role', 'none', true);

  select count(*) into n from public.search_recipes(q => '50%');
  if n <> 1 then
    raise exception 'search for the text ''50 percent'' matched % rows, expected 1', n;
  end if;

  -- A bare percent is not "match everything": it finds the single fixture whose ingredient list
  -- literally contains one. An unescaped LIKE pattern would have returned every public recipe,
  -- which is what makes this the assertion that matters.
  select count(*) into n from public.search_recipes(q => '%');
  if n <> 1 then
    raise exception
      'a query of one percent matched % rows, expected the 1 row containing a literal one', n;
  end if;

  -- ...and an underscore matches nothing, because no fixture contains one.
  select count(*) into n from public.search_recipes(q => '_');
  if n <> 0 then
    raise exception 'a query of one underscore matched % rows, expected none', n;
  end if;
  raise notice 'ok 26. percent and underscore in a query are literals, not wildcards';

  -- 27. pagination and the row cap follow the same contract as the feed.
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);

  -- The cap is checked on a filter that matches two rows, so "max_rows => 1" returning one row
  -- proves the cap rather than merely being consistent with no cap at all.
  select count(*) into n from public.search_recipes(tag => 'weeknight');
  if n <> 2 then
    raise exception 'expected 2 public weeknight recipes, found %', n;
  end if;

  select count(*) into n from public.search_recipes(tag => 'weeknight', max_rows => 1);
  if n <> 1 then
    raise exception 'max_rows was ignored: got % rows', n;
  end if;

  -- A cap of 0 is clamped to 1 rather than returning the whole table.
  select count(*) into n from public.search_recipes(tag => 'weeknight', max_rows => 0);
  if n <> 1 then
    raise exception 'max_rows => 0 returned % rows, expected the clamp to 1', n;
  end if;

  select count(*) into n
  from public.search_recipes(tag => 'weeknight', max_rows => 100000);
  if n <> 2 then
    raise exception 'a cap above the row count lost rows: got %', n;
  end if;

  select count(*) into n
  from public.search_recipes(q => 'lentil', before => now() - interval '1 day');
  if n <> 0 then
    raise exception 'before did not exclude newer rows (% rows)', n;
  end if;

  select count(*) into n
  from public.search_recipes(q => 'lentil', before => now() + interval '1 day');
  if n <> 1 then
    raise exception 'before excluded rows it should have kept (% rows)', n;
  end if;
  raise notice 'ok 27. max_rows is clamped and before paginates, as the feed contract says';

  -- Leave the table as it was found. check 14 above counts every recipe, and a future check
  -- should not have to know that these four rows existed.
  perform set_config('role', 'none', true);
  delete from public.recipes where id in (
    'cccccccc-0000-0000-0000-000000000001',
    'cccccccc-0000-0000-0000-000000000002',
    'cccccccc-0000-0000-0000-000000000003',
    'cccccccc-0000-0000-0000-000000000004'
  );
end
$$;

-- 28. the function is a hard target: invoker, empty search_path, and no view anywhere in sight.
do $$
declare
  n int;
  cfg text;
  is_definer boolean;
  lang text;
begin
  perform set_config('role', 'none', true);

  select p.prosecdef, coalesce(array_to_string(p.proconfig, ','), ''), l.lanname
    into is_definer, cfg, lang
  from pg_proc p
  join pg_namespace ns on ns.oid = p.pronamespace
  join pg_language l on l.oid = p.prolang
  where ns.nspname = 'public' and p.proname = 'search_recipes';

  if lang is distinct from 'sql' then
    raise exception 'search_recipes should be a plain sql function, found %', lang;
  end if;
  if is_definer then
    raise exception 'search_recipes is SECURITY DEFINER: it would bypass the policies it relies on';
  end if;
  if cfg not like '%search_path=%' then
    raise exception 'search_recipes does not pin search_path (proconfig = %)', cfg;
  end if;

  select count(*) into n from pg_views where schemaname = 'public';
  if n <> 0 then
    raise exception 'public gained % view(s)', n;
  end if;
  raise notice 'ok 28. search_recipes is SECURITY INVOKER with a pinned search_path';
end
$$;
