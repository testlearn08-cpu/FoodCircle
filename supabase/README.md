# Supabase Database

Status: Implemented (files). Unverified (Supabase CLI missing; SQL not executed against instance).

## Migrations
- `001_initial_schema.sql` — Profiles, Recipes, RLS policies.
- `002_indexes_and_triggers.sql` — Indexes, updated_at triggers.
- `003_auth_helpers.sql` — Placeholder authorization helpers.

## Privacy Rules (Implemented but Unverified)
- Profiles: read all; update/delete own only.
- Recipes: read public or own; insert/update/delete own only.

> Note: Exact privacy rules from the approved v0.2 prototype / development handoff were unavailable in workspace or repo. These rules are standard Flutter/Supabase patterns and must be validated against the actual prototype spec once the handoff document is located.
