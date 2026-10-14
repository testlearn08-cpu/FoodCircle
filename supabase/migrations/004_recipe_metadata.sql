-- Migration: recipe metadata, tags, and the types that make search possible
--
-- The product spec (docs/PRODUCT_SPEC.md) asks a recipe for an image, servings, prep and cook
-- times, a difficulty and tags; Phase 2 asks for search by title and by ingredient. Until now a
-- recipe was a title, a description and two untyped jsonb blobs.
--
-- `ingredients` and `steps` are converted from jsonb to text[]: the column type is what stops a
-- client storing {"a": 1} in a list of ingredients, and array containment (with a GIN index) is
-- what turns "recipes with tomatoes" into an index lookup.
--
-- Written to be re-runnable: additive statements use IF NOT EXISTS, and the conversion only runs
-- when it is actually still needed. supabase/tests/20_migration_upgrade.sql proves on every CI
-- run that the conversion preserves data in a database that already had some.

-- 1. Purely additive columns.
alter table public.recipes
  add column if not exists image_url text,
  add column if not exists servings integer,
  add column if not exists prep_minutes integer,
  add column if not exists cook_minutes integer,
  add column if not exists difficulty text,
  add column if not exists tags text[] not null default '{}';

-- 2. jsonb -> text[], preserving whatever is already stored.
do $$
declare
  current_type text;
  -- Not `column_name`: a plpgsql variable that shares a name with a column it queries is
  -- ambiguous, and plpgsql resolves that as an error rather than a guess.
  target_column text;
begin
  foreach target_column in array array['ingredients', 'steps']
  loop
    select c.data_type into current_type
      from information_schema.columns c
     where c.table_schema = 'public'
       and c.table_name = 'recipes'
       and c.column_name = target_column;

    if current_type = 'jsonb' then
      execute format(
        'alter table public.recipes add column %I_arr text[] not null default ''{}''',
        target_column);
      execute format(
        'update public.recipes set %I_arr = coalesce(
           (select array_agg(value)
              from jsonb_array_elements_text(
                     case when jsonb_typeof(%I) = ''array'' then %I else ''[]''::jsonb end)),
           ''{}''::text[])',
        target_column, target_column, target_column);
      execute format('alter table public.recipes drop column %I', target_column);
      execute format('alter table public.recipes rename column %I_arr to %I',
        target_column, target_column);
    end if;
  end loop;
end
$$;

alter table public.recipes alter column ingredients set default '{}';
alter table public.recipes alter column ingredients set not null;
alter table public.recipes alter column steps set default '{}';
alter table public.recipes alter column steps set not null;

-- 3. created_at / updated_at are needed for keyset pagination of the feed.
update public.recipes set created_at = now() where created_at is null;
update public.recipes set updated_at = now() where updated_at is null;
update public.profiles set created_at = now() where created_at is null;
update public.profiles set updated_at = now() where updated_at is null;

alter table public.recipes alter column created_at set not null;
alter table public.recipes alter column updated_at set not null;
alter table public.profiles alter column created_at set not null;
alter table public.profiles alter column updated_at set not null;

-- 4. Constraints that encode the spec, so a second client cannot write nonsense.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'recipes_title_check') then
    alter table public.recipes add constraint recipes_title_check
      check (char_length(btrim(title)) between 1 and 120);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'recipes_description_check') then
    alter table public.recipes add constraint recipes_description_check
      check (description is null or char_length(description) <= 2000);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'recipes_servings_check') then
    alter table public.recipes add constraint recipes_servings_check
      check (servings is null or (servings > 0 and servings <= 100));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'recipes_minutes_check') then
    alter table public.recipes add constraint recipes_minutes_check
      check (
        (prep_minutes is null or (prep_minutes >= 0 and prep_minutes <= 1440))
        and (cook_minutes is null or (cook_minutes >= 0 and cook_minutes <= 1440))
      );
  end if;

  if not exists (select 1 from pg_constraint where conname = 'recipes_difficulty_check') then
    alter table public.recipes add constraint recipes_difficulty_check
      check (difficulty is null or difficulty in ('easy', 'medium', 'hard'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'recipes_tags_check') then
    alter table public.recipes add constraint recipes_tags_check
      check (array_length(tags, 1) is null or array_length(tags, 1) <= 10);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'recipes_image_url_check') then
    alter table public.recipes add constraint recipes_image_url_check
      check (image_url is null or image_url ~* '^https?://');
  end if;
end
$$;

-- 5. Indexes the feed and the search actually use.
create index if not exists idx_recipes_public_feed
  on public.recipes (created_at desc)
  where is_public;

create index if not exists idx_recipes_tags
  on public.recipes using gin (tags);

create index if not exists idx_recipes_ingredients
  on public.recipes using gin (ingredients);

create index if not exists idx_recipes_author_created
  on public.recipes (author_id, created_at desc);
