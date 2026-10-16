# Reconciliation checklist — inferred build vs. the real handoff

Everything in this repository that touches the *product* was inferred, because the handoff is
still missing. This file remains an inventory, not a signed-off delta report: no original handoff
document is available to confirm or contradict these assumptions.

**Continuation update (2026-10-14):** Phase 1b auth and Phase 1c `005_storage.sql` were reconstructed
from the inferred repository roadmap. They are provisional and must be checked against the real
handoff before extension or deployment. The current checkout has no location, notifications or
offline schema/behavior; those gaps are called out explicitly below. No Supabase project exists and
no migration has been deployed.

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
| No notification inbox, preferences, delivery state or notification schema | — | **⚠️ `05_LOCATION_NOTIFICATIONS_AND_OFFLINE.md` exists.** `04` must also identify the delivery integrations before any notification schema or sender is designed. |
| No offline cache, write outbox, conflict metadata or offline schema | — | **⚠️ `05_LOCATION_NOTIFICATIONS_AND_OFFLINE.md` exists.** Do not treat the in-memory demo repository as an offline design; wait for the handoff's offline contract. |
| Recipe images use a public `recipe-images` Storage bucket, 10 MiB limit, JPEG/PNG/WebP allowlist, and first-folder user UUID for writes | `supabase/migrations/005_storage.sql`, `RecipeImageUpload`, `SupabaseRecipeRepository.uploadImage` | **Inferred, not approved.** An explicitly authorized repository-only upload adapter validates the current limits, uses the authenticated user's folder and returns a public URL; the in-memory demo refuses uploads. Reconcile bucket visibility, size/MIME limits and folder convention against `04`, `06` and `09` before deployment. No project exists, `005` is rewritable, and there is no editor/UI integration. |

## 2. Authorization (settled by `03`, `06`)

| Assumption | Where it lives | If the handoff disagrees |
|---|---|---|
| Profiles readable by anyone (including `anon`); written only by their owner | `001` | — |
| Recipes readable when public or own; written only by the author | `001` | — |
| `recipes.author_id` references `auth.users`, and the author is loaded by a second query rather than a join | `001`, `supabase_recipe_repository.dart` | A foreign key to `public.profiles` would simplify this; it was avoided because the profile row is created by a trigger. |
| Signing up provisions exactly one `profiles` row via a `SECURITY DEFINER` trigger | `003` | — |
| **`service_role` must never reach a client** | `lib/core/config/env.dart`, `tool/check_no_secrets.py` | Unlikely to be contradicted. |

The previously verified suite asserted the core recipe/profile model in 21 checks; the Storage
migration added four checks (25 total), all passed by CI run `38560095418`. A later repository-only
upload adapter now follows those inferred policies and is covered by the current branch CI. If the
model or handoff contract changes, update these implementation tests; they are not an approved
product specification.

## 3. Screens and flows (settled by `01_PRODUCT_AND_SCREENS.md`)

| Assumption | Where it lives | If the handoff disagrees |
|---|---|---|
| Three top-level destinations: Feed, Recipes, Profile | `lib/navigation/responsive_shell.dart` | `kNavigationDestinations` is the single source for the rail and the bottom bar, so adding/removing a destination is one list plus one branch in `lib/app.dart`. |
| Feed = public recipes, newest first | `lib/features/feed/feed_screen.dart` | If "Feed" means something else (activity, nearby, a circle), the screen is a rewrite but the repository/provider shape survives. |
| **`/recipes` is "the recipes you wrote"** — a personal recipe box, private rows included, not a browse-all-recipes catalogue | `lib/features/recipes/my_recipes_screen.dart` (2026-10-15) | Renaming or re-scoping is one screen plus one branch in `lib/app.dart`; `fetchMine` already exists. **⚠️ This is the most contentions inference in this list:** the destination is labelled "Recipes", and the handoff may well mean a catalogue, a category browser or a circle-scoped list. The feed is public recipes, so a second browse-all list would be near-duplicate — which is *why* this was read as "mine", not proof that it is. |
| A recipe page belongs to whichever list you opened it from (`/feed/:id` and `/recipes/:id` both route to it) | `lib/app.dart` | If `01` specifies one canonical URL per recipe, collapse to one route; nothing else changes. |
| A recipe that is unreadable and a recipe that does not exist are treated identically ("Recipe not available") | `lib/features/recipes/recipe_detail_screen.dart` | Deliberate: distinguishing them would leak the existence of other people's private recipes. Would only change if `06` asks for a different disclosure policy. |
| Editor input limits mirror the database's `CHECK` constraints (title 1–120, servings 1–100, times 0–1440, ≤10 tags) | `lib/features/recipes/recipe_editor_screen.dart`, `supabase/migrations/004` | These are the database's numbers, not a product decision — `01`/`07` may want different ones, in which case both places change together. |
| Editing a recipe cannot change its image | `recipe_editor_screen.dart`, `in_memory_recipe_repository.dart`, `supabase_recipe_repository.dart` | An omission, not a rule: the editor has no image field, and `005_storage.sql`'s bucket is not wired to it. Both repositories deliberately preserve `image_url` on update so the omission is reversible. |
| Recipe detail, the recipe box and the editor exist | `lib/features/recipes/`, roadmap §1a | — |
| **Search is substring matching over title + ingredients, with an exact tag filter, newest-first** | `supabase/migrations/006_recipe_search.sql`, `lib/features/feed/feed_screen.dart` | `01`/`07` may expect more: relevance ranking, fuzzy matching, a search over `description` or over other people (searching *users*, not recipes), or typo tolerance. All are changes to one function and one provider. This is the second-most contentions inference here; the first is `/recipes` above. |
| Search does not rank, and does not paginate by relevance | `006`, `feed_screen.dart` | Deliberate: results are `created_at desc`, the same order as the unfiltered feed, so a filtered feed is never a different thing from a feed. Relevance ranking would need a `tsvector` and a second ordering. |
| There is no `pg_trgm`, `unaccent` or `tsvector` index — search is a sequential scan | `006` | Correct at zero rows and cheap to revisit. Extensions are the constraint: 001 promises the whole suite runs on a stock PostgreSQL, so the upgrade path is a GIN index on `to_tsvector(...)`, not `pg_trgm`. A handoff document asking for typo tolerance or ranked results is what would justify breaking that promise. |
| Search returns at most 30 rows by default, clamped to 100 | `006` | A cap the handoff may want different; it is one argument. The UI does not currently paginate a search — it shows the first page and stops, which `07` may call incomplete. |
| A recipe is not searchable by its tags unless a tag filter is used, and tags are matched exactly (case-sensitive, no substrings) | `006`, `feed_screen.dart` | Tag chips are built from tags that exist, so there is no hand-typed tag to be forgiving about. Free-text tag search would be a change to the function's `where` clause. |
| Sign-in is email + password with a username supplied as signup metadata, and browsing public recipes is allowed signed out | `lib/features/auth/`, `lib/data/repositories/*auth_repository.dart`, `lib/core/providers.dart`, `lib/core/router/auth_routes.dart` | **Inferred and implemented, not approved.** Confirm the auth method, the username/password rules, onboarding and which routes require a session against `01`, `03` and `06` before extending it. If onboarding begins with a location permission, or auth is phone/OTP/anonymous-first, the first-run flow changes — but everything downstream reads `currentUserIdProvider`, so the screens do not. |
| `/feed` and `/feed/:id` are public; `/recipes`, `/recipes/:id`, `/recipes/new`, `/recipes/:id/edit` and `/profile` require a session and redirect to sign-in with a validated return target | `lib/app.dart`, `lib/core/router/auth_routes.dart` | **Inferred and implemented, not approved.** `05` and `01` may specify onboarding, privacy prompts, or a different gating model entirely. The return target accepts app-local paths only, so an auth link cannot become an open redirect. |
| The demo build's sign-in identity is the seeded demo author | `lib/data/repositories/in_memory_auth_repository.dart` | Demo-only coherence: signing in as a stranger who owns nothing cannot demonstrate the recipe box. A configured build uses the real session's UUID; nothing on this path touches Postgres. |
| Editing your profile is not built, and a profile is read-only | `lib/features/profile/profile_screen.dart` | `profiles_update_own` and `Profile.toUpdateJson` support it server-side; the screen omits it because avatar upload needs a Storage-backed editor field. |
| No onboarding, no permissions, and no settings beyond sign-out | `lib/features/profile/profile_screen.dart` | **⚠️** `05` and `01` may specify an onboarding sequence. Sign-out itself is the one account setting that exists. |

## 4. Things my spec does not mention at all (settled by `05`, `04`)

These are **whole subsystems** with a handoff document each, and nothing in the repository
addresses them:

- **⚠️ Location.** No geolocation, permission handling, distance filtering, or privacy story for
  storing/displaying a user's location. If the product is about food *near you*, this is central,
  not incidental. `05` must settle it before any location schema or permission work.
- **⚠️ Notifications.** No push, in-app inbox, notification preferences, Supabase Edge Function,
  or third-party sender. `05`/`04` must determine whether this subsystem exists and its delivery
  contract before schema or integration work.
- **⚠️ Offline.** No local cache, offline write outbox, or conflict resolution. The in-memory
  repository is a *demo* fallback, not an offline strategy. `05` must settle expected offline
  behavior before a cache or sync schema is designed.
- **Integrations.** `04_API_AND_INTEGRATION_CONTRACTS.md` implies services beyond Supabase
  (maps? email? analytics?). Nothing is integrated.

## 5. Delivery and process (settled by `07`, `08`, `09`)

| Current state | Question for the handoff |
|---|---|
| CI is the only place this code is ever compiled; its logs, artifacts and web preview are published to `ci-artifacts` / `ci-scaffold` / `preview` branches (see `README.md`) | Does `08` mandate a workflow this conflicts with? |
| 98 tests — navigation, policy text, behavioural RLS, models, repositories, feed, recipe page, editor, profile, auth, search — plus 32 behavioural database checks, all green in [38862331246](https://github.com/testlearn08-cpu/FoodCircle/actions/runs/38862331246) | Does `07` define a coverage or acceptance bar that is higher? |
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
