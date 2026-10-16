# FoodCircle

A responsive food-sharing community app — Flutter (Android / iOS / Web) on Supabase
(PostgreSQL + Auth + Storage).

## Current status

One branch, integrated end to end: the Phase 1a data/feed foundation, the product surface built on
it (recipe page, recipe box, editor, search, profile) and the inferred Phase 1b/1c auth and
recipe-image-storage slice. The auth/storage slice is reconstructed from this repository's inferred
roadmap because the authoritative handoff is not in this checkout — it is verified by CI, not
approved, and `docs/handoff/RECONCILIATION.md` lists what still needs the real documents.

- ✅ **Builds on every platform target, and its test suite passes** — in CI, every job in
  [38862331246](https://github.com/testlearn08-cpu/FoodCircle/actions/runs/38862331246):
  `flutter build web --release` publishes a runnable web bundle,
  `flutter build apk --debug` produces an installable Android APK, 111 tests pass, `analyze`
  reports no issues, `dart format` has 0 changes, and the 33 behavioural database checks pass
  against a real `postgres:17`.
- ✅ Responsive navigation shell works: three top-level destinations (`/feed`, `/recipes`,
  `/profile`) with a desktop rail, tablet rail and mobile bottom bar, each with its own
  navigation stack.
- ✅ Database schema + RLS policies are written (6 migrations).
- ✅ **Auth is real, and it gates the account's own screens.** Email/password sign-in and sign-up
  (`/sign-in`, `/sign-up`), session-aware routing with a return target, and sign-out on the
  profile page. `/feed` stays public: signed out, the app is a read-only browser of public
  recipes. `/recipes` and `/profile` require a session and send you to sign-in if you ask for
  them without one. The Supabase SDK persists configured sessions; without a project the fake is
  ephemeral and accepts demo credentials only.
- ✅ **Recipes can carry an image.** `005_storage.sql` adds a public `recipe-images` bucket with
  owner-folder write policies, and `RecipeRepository.uploadImage` returns the public URL. Its
  visibility, 10 MiB limit and MIME allowlist are inferred defaults, not approved product
  requirements, and the migration has never been deployed.
- ⚠️ **iOS scaffolding exists but has never been compiled** — that needs macOS, which CI
  does not have.
- ✅ **The feed is real.** `/feed` reads through a repository (Supabase, or in-memory when no
  project is configured) with pull-to-refresh and loading / empty / error states. Riverpod does
  the wiring; `supabase_flutter` is connected and initialised when a project is configured.
- ⚠️ **The database is verified, not deployed.** Migrations `001`–`006` are applied from empty
  *and* as an upgrade of a populated database on every CI run, and the RLS policies are
  exercised as `anon` / `authenticated` / `service_role`. No Supabase project exists yet.
- ✅ **All three destinations are real.** `/feed` lists public recipes, `/recipes` is your own
  recipe box (private ones included), and `/profile` is your identity — and tapping a recipe opens
  its page, with ingredients, steps, and delete for its author. A recipe can be written from the
  app too: `/recipes/new` and `/recipes/:id/edit` share one validated form. Your profile is
  editable in place: name, username and bio at `/profile/edit`, with a taken username explained
  rather than swallowed.
- ✅ **Search works, including inside ingredient lists.** The feed's search box matches titles and
  ingredients, with tag chips built from the tags actually present. That filtering runs in the
  database (`006_recipe_search.sql`), because a substring of one element of a `text[]` is not
  something a PostgREST filter can express.
- ❌ **The rest of the product is still unbuilt.** Location, notifications and offline behaviour
  have no implementation and no schema, and the approved handoff documents are missing. Phase 2
  should not begin until the handoff and product sign-off arrive.

The source of the inferred plan is [`docs/ANALYSIS_AND_ROADMAP.md`](docs/ANALYSIS_AND_ROADMAP.md).
The authoritative product handoff belongs under [`docs/handoff/`](docs/handoff/); see its README
and [`RECONCILIATION.md`](docs/handoff/RECONCILIATION.md) for the open assumptions. `DEVELOPMENT_STATUS.md`
is a historical log, not current state.

## Quick start

Requires Flutter 3.10+ (Dart 3.0+).

```bash
flutter pub get
flutter analyze
flutter test
```

With no `--dart-define`, the app runs on in-memory demo data. Sign-in and sign-up are simulated,
credentials are not stored, and the feed displays a demo-mode banner. This is **not real
authentication**. To connect an existing Supabase project, configure only its publishable/anon key:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable / anon key>
```

The Supabase Flutter SDK persists the configured auth session. **Only the publishable/anon key may
reach a client; never use or commit `service_role`.** No project is configured in CI or in this
sandbox.

### Database and storage

Migrations live in `supabase/migrations/` and run in filename order. They have never been applied to
a Supabase project; once deployed, applied migrations become append-only. The PostgreSQL CI suite
uses test-only stubs for Supabase-managed `auth` and `storage` objects and exercises recipe-image
read/write policies without creating a Supabase project.

`RecipeRepository.uploadImage` is a repository-only, provisional upload path: it accepts JPEG, PNG,
or WebP bytes up to 10 MiB, uses the current authenticated user's folder in the public
`recipe-images` bucket, and returns the public URL. These limits and bucket rules are inferred and
must be reconciled with the authoritative handoff before deployment. The in-memory demo refuses
binary uploads; no recipe-editor UI is wired to the API yet.

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres supabase/tests/run.sh
```

### Continuous integration

`.github/workflows/ci.yml` runs on pushes to `main` and `arena/**`, pull requests, and manual
dispatch:

| Job | What it proves |
|---|---|
| `No credentials committed` | No `service_role` key, personal access token or private key is in the repository. It is public, and a leaked `service_role` key bypasses every RLS policy. |
| `Dart static guardrails` | Public-feed/auth-route boundaries, auth-state refresh, and publishable-key wiring remain present. |
| `SQL expectations` | The RLS policies and the `auth.users` leak guard still exist as written (python3, ~5s). |
| `Database behaviour (RLS)` | The migrations apply to a real `postgres:17` and the policies behave: 33 checks as `anon` / `authenticated` / `service_role`, covering the recipe and profile policies, the public image bucket's owner-folder writes, and the checks that prove a search cannot see past the visibility rule. |
| `Flutter analyze + test` | Compiles, `flutter_lints` clean, `dart format` clean (44 files, 0 changed), and 111 tests pass. |
| `Scaffolding report` | Diffs the repo against what `flutter create` generates, and publishes a pristine reference app to `ci-scaffold`. |
| `Build web + publish preview` | `flutter build web --release` succeeds, and a run that is not a pull request force-pushes the bundle to the `preview` branch. PR runs build it without publishing, so a broken web build still fails the PR. |
| `Build debug APK` | The Android target really builds; the APK is attached to the run. |
| `Publish logs to ci-artifacts` | Every job's output is pushed to `ci-artifacts` — the only way to read CI failures from a sandbox with no log access. |

`.github/workflows/format.yml` is a second workflow, on `arena/**` pushes only: it runs
`dart format .` and publishes the result to `ci-formatted`, so the formatting the gate above
demands can be read rather than guessed at from a sandbox that has no Dart SDK. It is a
development aid, not a gate — `flutter analyze + test` in `ci.yml` is the gate.

### Bot branches (never merge these)

`ci-artifacts` (one commit per run: every job's logs plus `RUN.md`), `ci-scaffold`
(`flutter create` output plus a pristine `vanilla/` template app), `preview` (the built web
bundle), `ci-formatted` (the tree as `dart format` would write it). Each is force-pushed by the
run that owns it.

```bash
git fetch origin ci-artifacts && git show origin/ci-artifacts:RUN.md
git show origin/ci-artifacts:analyze.log
git show origin/ci-artifacts:dart-static.log
```

## Repository layout

```
lib/
  main.dart                       entry point
  app.dart                        MaterialApp.router + GoRouter: auth routes, the guard, one branch per destination
  navigation/responsive_shell.dart  rail / bottom bar from one destination list
lib/core/config/                  --dart-define and Env.isConfigured
lib/core/router/                  auth paths, return-target validation, router refresh
lib/core/providers.dart           auth + identity, the repository, the feed and its filters
lib/core/widgets/                 shared list, state and avatar widgets
lib/data/                         models + repositories (Supabase and in-memory)
lib/features/auth/                sign-in and sign-up
lib/features/feed/                the public feed
lib/features/recipes/             recipe page, recipe box, editor
lib/features/profile/             identity, profile editor, your recipe box, sign out
supabase/migrations/              001 schema · 002 indexes+triggers · 003 auth helpers · 004 metadata · 005 storage · 006 search
supabase/tests/                   behavioural RLS suite, migration-upgrade test, auth/storage stubs
test/                             navigation, policies, models, repositories, feed, detail, editor, profile, auth, search
tool/                             static guards (secrets, Dart surface, SQL expectations) and the local SQL suite
docs/ANALYSIS_AND_ROADMAP.md      current state + delivery plan
```
