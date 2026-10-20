-- Asserts that an upgrade of a database that already held data is correct.
--
-- Runs after 004 (and every later migration) has been applied on top of the rows seeded by
-- 05_legacy_seed.sql. See run.sh: this is a different path from the fresh-database suite in
-- 10_rls_behaviour.sql, and it is the path that silently corrupts data when it is wrong.

do $$
declare
  v_type text;
begin
  select data_type into v_type
    from information_schema.columns
   where table_schema = 'public' and table_name = 'recipes'
     and information_schema.columns.column_name = 'ingredients';

  if v_type <> 'ARRAY' then
    raise exception 'ingredients should be an array after 004, found %', v_type;
  end if;

  select data_type into v_type
    from information_schema.columns
   where table_schema = 'public' and table_name = 'recipes'
     and information_schema.columns.column_name = 'steps';

  if v_type <> 'ARRAY' then
    raise exception 'steps should be an array after 004, found %', v_type;
  end if;

  raise notice 'ok  U1. ingredients and steps are arrays, and the jsonb columns are gone';
end
$$;

do $$
declare
  v_ingredients text[];
  v_steps text[];
  v_tags text[];
begin
  select ingredients, steps, tags into v_ingredients, v_steps, v_tags
    from public.recipes where id = 'cccccccc-0000-0000-0000-000000000001';

  if v_ingredients <> array['flour', 'butter', 'salt, to taste', 'the "good" vanilla'] then
    raise exception 'the ingredients conversion lost or mangled data: %', v_ingredients;
  end if;

  if v_steps <> array['mix', 'bake'] then
    raise exception 'the steps conversion lost or mangled data: %', v_steps;
  end if;

  if v_tags <> array[]::text[] then
    raise exception 'tags should default to an empty array, found %', v_tags;
  end if;

  raise notice 'ok  U2. existing ingredients and steps survived the conversion, commas and quotes included';
end
$$;

do $$
declare
  v_ingredients text[];
begin
  select ingredients into v_ingredients
    from public.recipes where id = 'cccccccc-0000-0000-0000-000000000002';

  if v_ingredients <> array[]::text[] then
    raise exception 'an empty jsonb list should convert to an empty text array, found %', v_ingredients;
  end if;

  raise notice 'ok  U3. an empty list converts to an empty array, not to {""}';
end
$$;

do $$
declare
  n int;
begin
  update public.recipes set created_at = now(), updated_at = now()
   where created_at is null or updated_at is null;

  select count(*) into n from public.recipes
   where created_at is null or updated_at is null;
  if n <> 0 then
    raise exception '% recipe(s) still have a null timestamp', n;
  end if;

  raise notice 'ok  U4. timestamps are populated and non-null';
end
$$;

do $$
declare
  n int;
begin
  -- The legacy rows are visible to an anonymous client only where they are public, after the
  -- whole upgrade: the policies must still be doing their job on the post-upgrade schema.
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);

  select count(*) into n from public.recipes;
  if n <> 1 then
    raise exception 'after the upgrade anon should see exactly the 1 public legacy recipe, saw %', n;
  end if;

  raise notice 'ok  U5. the policies still work on the upgraded schema';
end
$$;

do $$
declare
  is_public boolean;
  policy_count int;
begin
  select public into is_public
    from storage.buckets where id = 'recipe-images';
  if not found or is_public is distinct from true then
    raise exception 'the upgrade did not create a public recipe-images bucket';
  end if;

  select count(*) into policy_count
    from pg_policies
   where schemaname = 'storage'
     and tablename = 'objects'
     and policyname in (
       'recipe_images_read_public',
       'recipe_images_insert_own',
       'recipe_images_update_own',
       'recipe_images_delete_own'
     );
  if policy_count <> 4 then
    raise exception 'the upgrade installed % of 4 recipe image policies', policy_count;
  end if;

  raise notice 'ok  U6. migration 005 creates the bucket and all four policies on upgrade';
end
$$;
