-- Migration: recipe search
-- Status: Implemented (file). Verified by supabase/tests/10_rls_behaviour.sql (checks 22-27),
--         which run against a real PostgreSQL in CI.
--
-- S5 of the product spec is "search inside the feed, by title and ingredient text, filtered by
-- tag". The job to be done behind it is "what can I make tonight?" — which is why ingredient
-- matching is the point of this function, not a bonus: searching `lentils` has to find the
-- recipe whose ingredients say "1 cup red lentils", and no PostgREST filter can do that. Arrays
-- can be tested for containment (`cs`), not for a substring of one of their elements, so the
-- query has to run in the database.
--
-- Why a function and not a view:
--   * check 2 of the behavioural suite forbids views in `public`, and for a good reason — a view
--     runs with its *owner's* privileges unless `security_invoker` is set, and one used to leak
--     every user's email through `auth.users`. A view would also have to hard-code the
--     visibility rule (or lean on `security_invoker` to get it right anyway).
--   * `security invoker` means this function runs as whoever called it, so the policies in
--     migration 001 — not this file — decide what it can see. It contains no authorization
--     logic at all, deliberately: one boundary is debuggable, two that disagree are not.
--   * `set search_path = ''` plus schema-qualified identifiers, the same hardening 003 applies
--     to the signup trigger: with an empty search_path, nobody can shadow `public.recipes` with
--     an object they control.
--
-- What it does NOT do:
--   * no `pg_trgm`, no `unaccent`. `ilike '%needle%'` cannot use an index, so this is a
--     sequential scan. That is the right trade at this size: there is no data yet, `idx_recipes_tags`
--     and `idx_recipes_ingredients` (004) already serve containment queries, and adding an
--     extension would break the rule 001 sets — the whole suite has to run on a stock
--     PostgreSQL. When there are enough recipes for it to matter, a GIN index on
--     `to_tsvector(...)` is the core-PostgreSQL upgrade path.
--   * it does not search `description`. The spec says title and ingredient text; widening it is
--     a product decision, not a bug fix.

create or replace function public.search_recipes(
  q text default null,
  tag text default null,
  before timestamptz default null,
  max_rows integer default 30
)
returns setof public.recipes
language sql
stable
security invoker
set search_path = ''
as $$
  with pattern as (
    select case
             -- An empty or whitespace-only query is "no text filter", not "match nothing":
             -- the client sends the same call for a bare tag filter.
             when coalesce(btrim(q), '') = '' then null
             -- `%` and `_` are LIKE wildcards, so a query of "50%" would otherwise match
             -- everything. Escaped here so that the SQL implementation and the in-memory one
             -- (which uses a plain substring test) agree on what a needle means.
             else '%' || replace(replace(replace(btrim(q), '\', '\\'), '%', '\%'), '_', '\_') || '%'
           end as like_pattern
  )
  select r.*
  from public.recipes r, pattern p
  where
    (
      p.like_pattern is null
      or r.title ilike p.like_pattern
      or exists (
        select 1
        from unnest(r.ingredients) as ingredient
        where ingredient ilike p.like_pattern
      )
    )
    -- Tags are matched exactly, not case-insensitively: the tag filter in the UI only offers
    -- tags that exist, so there is no hand-typed tag to be forgiving about.
    and (tag is null or tag = any (r.tags))
    -- Keyset pagination, matching fetchFeed's contract, so `before` is never silently ignored.
    and (before is null or r.created_at < before)
  order by r.created_at desc
  limit least(greatest(coalesce(max_rows, 30), 1), 100);
$$;

comment on function public.search_recipes(text, text, timestamptz, integer) is
  'Feed search: title and ingredient substring match, optional exact tag filter, newest first. '
  'SECURITY INVOKER, so the RLS policies on public.recipes decide visibility.';
