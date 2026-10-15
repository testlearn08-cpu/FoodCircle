# FoodCircle

A responsive food-sharing community app — Flutter (Android / iOS / Web) on Supabase
(PostgreSQL + Auth + Storage).

## Status: early skeleton, actively being bootstrapped

Be clear about what this is today, because it is easy to misread the repo:

- ✅ **Builds on every platform target, and its test suite passes** — in CI
  ([run 38685862019](https://github.com/testlearn08-cpu/FoodCircle/actions/runs/38685862019), all
  seven jobs): `flutter build web --release` publishes a runnable web bundle, `flutter build apk
  --debug` produces an installable Android APK, and 55 tests + `analyze` + `dart format` are green.
- ✅ Responsive navigation shell works: three top-level destinations (`/feed`, `/recipes`,
  `/profile`) with a desktop rail, tablet rail and mobile bottom bar, each with its own
  navigation stack.
- ✅ Database schema + RLS policies are written (3 migrations).
- ⚠️ **iOS scaffolding exists but has never been compiled** — that needs macOS, which CI
  does not have.
- ✅ **The feed is real.** `/feed` reads through a repository (Supabase, or in-memory when no
  project is configured) with pull-to-refresh and loading / empty / error states. Riverpod does
  the wiring; `supabase_flutter` is connected and initialised when a project is configured.
- ⚠️ **The database is verified, not deployed.** Migrations `001`–`004` are applied from empty
  *and* as an upgrade of a populated database on every CI run, and the RLS policies are
  exercised as `anon` / `authenticated` / `service_role`. No Supabase project exists yet.
- ✅ **All three destinations are real.** `/feed` lists public recipes, `/recipes` is your own
  recipe box (private ones included), and `/profile` is your identity — and tapping a recipe opens
  its page, with ingredients, steps, and delete for its author. A recipe can be written from the
  app too: `/recipes/new` and `/recipes/:id/edit` share one validated form.
- ❌ **Auth is not built.** There is no sign-in, so the writing screens run as the demo user when
  no project is configured and say "Not signed in" when one is. There is no route guard yet.

**Read [`docs/ANALYSIS_AND_ROADMAP.md`](docs/ANALYSIS_AND_ROADMAP.md) first** — it is the current
source of truth for state and for what happens next. `DEVELOPMENT_STATUS.md` is a historical log
of earlier passes; `ARCHITECTURE.md` describes the shared foundation in detail.

## Quick start

Requires Flutter 3.10+ (Dart 3.0+).

```bash
flutter pub get
flutter analyze
flutter test
```

With no `--dart-define` the app runs on in-memory demo data — the feed works, and an amber banner
says so. Point it at a project to use the real thing:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable / "anon" key>
```

> The project runs today with **no configuration** — it has no Supabase connection yet. When auth
> lands, the connection is supplied at build time rather than committed:
>
> ```bash
> flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
> ```
>
> Only the **anon** key ever belongs on a client. Never commit `service_role`.

### Database

Migrations live in `supabase/migrations/` and are applied in filename order; see
[`supabase/README.md`](supabase/README.md) for the privacy model and the test suite. They have
never been applied to a Supabase project — the first time they reach one they become append-only.

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres supabase/tests/run.sh
```

### Continuous integration

`.github/workflows/ci.yml` runs on every pull request:

| Job | What it proves |
|---|---|
| `No credentials committed` | No `service_role` key, personal access token or private key is in the repository. It is public, and a leaked `service_role` key bypasses every RLS policy. |
| `SQL expectations` | The RLS policies and the `auth.users` leak guard still exist as written (python3, ~5s). |
| `Database behaviour (RLS)` | The migrations apply to a real `postgres:17` and the policies behave: 21 checks as `anon` / `authenticated` / `service_role`. |
| `Flutter analyze + test` | Compiles, `flutter_lints` clean, `dart format` clean, 7 widget tests pass. |
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
git fetch origin ci-artifacts && git show origin/ci-artifacts:RUN.md   # what ran, what failed
git show origin/ci-artifacts:analyze.log                              # and why
```

## Repository layout

```
lib/
  main.dart                       entry point
  app.dart                        MaterialApp.router + GoRouter, one branch per destination
  navigation/responsive_shell.dart  rail / bottom bar from one destination list
lib/core/                         config (--dart-define), Riverpod providers, session seam
lib/core/widgets/                 shared list, state and avatar widgets
lib/data/                         models + repositories (Supabase and in-memory)
lib/features/feed/                the public feed
lib/features/recipes/             recipe page, recipe box, editor
lib/features/profile/             the profile screen
supabase/migrations/              001 schema · 002 indexes+triggers · 003 auth helpers · 004 metadata
supabase/tests/                   behavioural RLS suite, migration-upgrade test, auth stub
test/                             navigation, policies, models, repositories, feed, detail, editor, profile
tool/check_sql_expectations.py    fast local mirror of the policy assertions
docs/ANALYSIS_AND_ROADMAP.md      current state + delivery plan
```

## Development environment note

This repository is currently developed from a sandbox that has **no Flutter SDK and no network
access to the SDK download hosts or to Actions job logs**. Dart code is therefore written blind and
verified by CI, which is why CI is wired to publish its own logs, its build output and a runnable
web preview. See Phase 0 in the roadmap.
