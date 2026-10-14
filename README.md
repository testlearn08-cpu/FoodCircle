# FoodCircle

A responsive food-sharing community app — Flutter (Android / iOS / Web) on Supabase
(PostgreSQL + Auth + Storage).

## Status: early skeleton, actively being bootstrapped

Be clear about what this is today, because it is easy to misread the repo:

- ✅ **Builds on every platform target, and its test suite passes** — in CI
  ([run 38535122523](https://github.com/testlearn08-cpu/FoodCircle/actions/runs/38535122523)):
  `flutter build web --release` publishes a runnable web bundle, `flutter build apk --debug`
  produces an installable Android APK, and `analyze` + `test` + `dart format` are green.
- ✅ Responsive navigation shell works: three top-level destinations (`/feed`, `/recipes`,
  `/profile`) with a desktop rail, tablet rail and mobile bottom bar, each with its own
  navigation stack.
- ✅ Database schema + RLS policies are written (3 migrations).
- ⚠️ **iOS scaffolding exists but has never been compiled** — that needs macOS, which CI
  does not have.
- ❌ **There is no product functionality.** All three screens render "Not implemented yet";
  Supabase is declared in `pubspec.yaml` but never imported; there is no auth, no data layer,
  no recipe screen.
- ❌ No migration has ever been applied to a real PostgreSQL instance.

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
| `SQL expectations` | The RLS policies and the `auth.users` leak guard still exist as written (python3, ~5s). |
| `Database behaviour (RLS)` | The migrations apply to a real `postgres:17` and the policies behave: 21 checks as `anon` / `authenticated` / `service_role`. |
| `Flutter analyze + test` | Compiles, `flutter_lints` clean, `dart format` clean, 7 widget tests pass. |
| `Scaffolding report` | Diffs the repo against what `flutter create` generates, and publishes a pristine reference app to `ci-scaffold`. |
| `Build web + publish preview` | `flutter build web --release` succeeds and force-pushes the bundle to the `preview` branch. |
| `Build debug APK` | The Android target really builds; the APK is attached to the run. |
| `Publish logs to ci-artifacts` | Every job's output is pushed to `ci-artifacts` — the only way to read CI failures from a sandbox with no log access. |

### Bot branches (never merge these)

`ci-artifacts` (one commit per run: every job's logs plus `RUN.md`), `ci-scaffold`
(`flutter create` output plus a pristine `vanilla/` template app), `preview` (the built web
bundle). Each is force-pushed by the run that owns it.

```bash
git fetch origin ci-artifacts && git show origin/ci-artifacts:RUN.md   # what ran, what failed
git show origin/ci-artifacts:analyze.log                              # and why
```

## Repository layout

```
lib/
  main.dart                       entry point
  app.dart                        MaterialApp.router + GoRouter + breakpoints
  navigation/responsive_shell.dart  rail / bottom bar from one destination list
  screens/placeholder_screen.dart   body for destinations with no real screen yet
supabase/migrations/              001 schema · 002 indexes+triggers · 003 auth helpers
supabase/tests/                   behavioural RLS suite + the auth stub it needs
test/                             navigation + policy tests (run by CI)
tool/check_sql_expectations.py    fast local mirror of the policy assertions
docs/ANALYSIS_AND_ROADMAP.md      current state + delivery plan
```

## Development environment note

This repository is currently developed from a sandbox that has **no Flutter SDK and no network
access to the SDK download hosts or to Actions job logs**. Dart code is therefore written blind and
verified by CI, which is why CI is wired to publish its own logs, its build output and a runnable
web preview. See Phase 0 in the roadmap.
