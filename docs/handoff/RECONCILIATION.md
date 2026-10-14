# Reconciliation checklist — inferred build vs. the real handoff

Everything in this repository that touches the *product* was inferred, because the handoff was
missing. This file is the inventory: each row is an assumption that is currently baked into code,
migrations or tests, and the handoff document that settles it. When the documents land, work down
this list instead of re-reading the codebase.

Anything marked **⚠️** is a place where the *existence* of a handoff document is itself evidence
that my inference is incomplete.

---

## 1. Data model (settled by `03_DATABASE_AND_AUTHORIZATION.md`)

| Assumption | Where it lives | If the handoff disagrees |
|---|---|---|
| The core entity is a **recipe** with title, description, image, servings, prep/cook minutes, difficulty, tags, ingredients[], steps[], `is_public` | `supabase/migrations/001`, `004`; `lib/data/models/recipe.dart` | `004` has never been applied anywhere, so it can be rewritten rather than superseded. If the core entity is not a recipe at all, this is a rewrite of `001`—`004` and the models, and the earlier it is known the cheaper it is. |
| Recipes are `public` or private-to-author | `001` (`recipes_read_public`) | A third visibility (circle-only, or "visible to people nearby") would need a membership table and a new policy predicate. |
| `ingredients`/`steps` are `text[]` ordered lists | `004` | Structured steps (with times/temperatures) or unordered ingredient sets would change the type again. |
| A profile is username + display name + avatar + bio | `001`, `lib/data/models/profile.dart` | Extra fields are additive and cheap. Username *format* rules are the likely gap. |
| No location anywhere in the schema | — | **⚠️ `05_LOCATION_NOTIFICATIONS_AND_OFFLINE.md` exists.** If recipes or profiles carry a location, or if visibility depends on distance, then PostGIS, a coordinates column and a distance-aware policy are missing entirely. |

## 2. Authorization (settled by `03`, `06`)

| Assumption | Where it lives | If the handoff disagrees |
|---|---|---|
| Profiles readable by anyone (including `anon`); written only by their owner | `001` | — |
| Recipes readable when public or own; written only by the author | `001` | — |
| `recipes.author_id` references `auth.users`, and the author is loaded by a second query rather than a join | `001`, `supabase_recipe_repository.dart` | A foreign key to `public.profiles` would simplify this; it was avoided because the profile row is created by a trigger. |
| Signing up provisions exactly one `profiles` row via a `SECURITY DEFINER` trigger | `003` | — |
| **`service_role` must never reach a client** | `lib/core/config/env.dart`, `tool/check_no_secrets.py` | Unlikely to be contradicted. |

The behavioural suite (`supabase/tests/10_rls_behaviour.sql`) asserts the current model in 21
checks. If the model changes, those checks are the specification of what changes.

## 3. Screens and flows (settled by `01_PRODUCT_AND_SCREENS.md`)

| Assumption | Where it lives | If the handoff disagrees |
|---|---|---|
| Three top-level destinations: Feed, Recipes, Profile | `lib/navigation/responsive_shell.dart` | `kNavigationDestinations` is the single source for the rail and the bottom bar, so adding/removing a destination is one list plus one branch in `lib/app.dart`. |
| Feed = public recipes, newest first | `lib/features/feed/feed_screen.dart` | If "Feed" means something else (activity, nearby, a circle), the screen is a rewrite but the repository/provider shape survives. |
| Recipe detail, recipe editor, search are Phase 2 | roadmap | — |
| Sign-in is email + password, and browsing public recipes is allowed signed out | *not built yet* | **⚠️ Confirm before building Phase 1b.** If onboarding begins with a location permission, or if auth is phone/OTP or anonymous-first, the first-run flow differs from "land on the feed". |
| No onboarding, no permissions, no settings beyond sign-out | *not built yet* | **⚠️** `05` and `01` may specify an onboarding sequence. |

## 4. Things my spec does not mention at all (settled by `05`, `04`)

These are **whole subsystems** with a handoff document each, and nothing in the repository
addresses them:

- **Location.** No geolocation, no permission handling, no distance filtering, no privacy story
  for storing or displaying where a user is. If the product is about food *near you*, this is
  central rather than incidental.
- **Notifications.** No push, no in-app notification inbox, no notification preferences, no
  Supabase edge function or third-party sender.
- **Offline.** No local cache, no outbox for writes made offline, no conflict resolution. The
  in-memory repository is a *demo* fallback, not an offline strategy.
- **Integrations.** `04_API_AND_INTEGRATION_CONTRACTS.md` implies services beyond Supabase
  (maps? email? analytics?). Nothing is integrated.

## 5. Delivery and process (settled by `07`, `08`, `09`)

| Current state | Question for the handoff |
|---|---|
| CI is the only place this code is ever compiled; its logs, artifacts and web preview are published to `ci-artifacts` / `ci-scaffold` / `preview` branches (see `README.md`) | Does `08` mandate a workflow this conflicts with? |
| 42 tests: navigation, policy text, behavioural RLS, models, repository, feed | Does `07` define a coverage or acceptance bar that is higher? |
| No environments, no deploy target, no secrets management | `09` defines them; the `--dart-define` contract in `lib/core/config/env.dart` is the current guess. |
| `main` is the default branch; work happens on `arena/*` | `08` may specify a different branching model. |

## 6. What I will do when the documents arrive

1. Read all of them, then write a **delta report**: for each row above, confirmed / contradicted /
   unanswered, with the cheapest correction for each contradiction.
2. Correct the inferred artefacts in dependency order: schema → policies → behavioural tests →
   models → repositories → screens. The tests come with the changes, not after.
3. Update `PRODUCT_SPEC.md` to either quote the handoff or be deleted in its favour — it is
   currently retained only as a record of what was inferred.
4. Re-sequence the roadmap against `11_IMPLEMENTATION_BACKLOG.md` and record anything in
   `10_DECISIONS_AND_OPEN_GATES.md` that is still open.
