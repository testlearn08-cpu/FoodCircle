# FoodCircle

A responsive food-sharing community app — Flutter (Android / iOS / Web) on Supabase
(PostgreSQL + Auth + Storage).

## Current status

The repository contains the Phase 1a data/feed foundation plus an inferred Phase 1b/1c auth and
recipe-image-storage implementation. The latter is being reconstructed from the repository's
inferred roadmap because the authoritative handoff is not in this checkout; the new code is **not
verified until its CI run passes**.

- ✅ The existing mainline foundation builds and its tests pass in CI. The most recent verified
  main run is [38546973249](https://github.com/testlearn08-cpu/FoodCircle/actions/runs/38546973249).
- ✅ The public `/feed` reads through a repository (Supabase, or in-memory demo data when no
  project is configured) with loading, empty, error and refresh states.
- 🟡 Phase 1b adds email/password sign-in and sign-up, session-aware routing, and sign-out. The
  Supabase SDK persists configured sessions; the no-project fake is ephemeral and accepts demo
  credentials only. `/feed` remains public; `/recipes` and `/profile` require a session.
- 🟡 Migration `005_storage.sql` adds a public `recipe-images` bucket and owner-folder write
  policies. Its visibility, 10 MiB limit and MIME allowlist are inferred defaults, not approved
  product requirements. The migration has never been deployed.
- ⚠️ No Supabase project exists, and none is created by this repository or CI. Migrations `001`–`005`
  are still rewritable; CI exercises them against a disposable PostgreSQL test database only.
- ⚠️ The approved handoff documents are missing. Location, notifications and offline behaviour
  still have no implementation or schema. Recipe detail, the editor, search, and `uploadImage` are
  not part of this slice; do not begin Phase 2 until the handoff and product sign-off arrive.
- ⚠️ This sandbox has no Flutter/Dart SDK. Auth Dart must be compiled, analyzed, tested and formatted
  in CI before being described as verified.

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
| `No credentials committed` | No `service_role` key, personal access token or private key is in the repository. |
| `Dart static guardrails` | Public-feed/auth-route boundaries, auth-state refresh, and publishable-key wiring remain present. |
| `SQL expectations` | Policy and migration assertions match the SQL files (Python, fast local check). |
| `Database behaviour (RLS)` | The migrations apply to disposable `postgres:17`; recipe, profile and Storage policies are exercised as client roles. |
| `Flutter analyze + test` | Compiles, analyzes, runs unit/widget tests and enforces `dart format`. |
| `Scaffolding report` | Diffs against the generated Flutter template and publishes a pristine reference to `ci-scaffold`. |
| `Build web + publish preview` | Builds the web target and publishes the preview bundle. |
| `Build debug APK` | Builds the Android debug APK. |
| `Publish logs to ci-artifacts` | Publishes per-job logs and `RUN.md` for checkout-side diagnosis. |

### Bot branches (never merge these)

`ci-artifacts` (one commit per run: logs plus `RUN.md`), `ci-scaffold` (generated platform
scaffolding plus a pristine `vanilla/` app), and `preview` (the built web bundle) are force-pushed
by CI.

```bash
git fetch origin ci-artifacts && git show origin/ci-artifacts:RUN.md
git show origin/ci-artifacts:analyze.log
git show origin/ci-artifacts:dart-static.log
```

## Repository layout

```
lib/
  app.dart                         MaterialApp.router + GoRouter auth redirect
  core/config/                     --dart-define and Riverpod providers
  core/router/                     auth paths, return-target validation and router refresh
  data/models/                     AuthUser, Profile and Recipe
  data/repositories/               auth/recipe interfaces, Supabase adapters and in-memory fakes
  features/auth/                   sign-in, sign-up and minimal sign-out surface
  features/feed/                   public recipe feed
  navigation/                      responsive rail / bottom navigation
supabase/migrations/               001 schema · 002 indexes · 003 auth · 004 recipe metadata · 005 storage
supabase/tests/                    auth/storage stubs, RLS behavior and migration-upgrade suite
test/                              auth, routing, feed, models, repositories and SQL-policy checks
tool/                              static guards for Dart/security/SQL assumptions
```
