# FoodCircle

A responsive food-sharing community app — Flutter (Android / iOS / Web) on Supabase
(PostgreSQL + Auth + Storage).

## Status: early skeleton, actively being bootstrapped

Be clear about what this is today, because it is easy to misread the repo:

- ✅ **Compiles and its test suite passes** — verified in CI
  ([run 38525965333](https://github.com/testlearn08-cpu/FoodCircle/actions/runs/38525965333),
  2026-10-14: `flutter pub get` → `flutter analyze` → `flutter test`, all green).
- ✅ Responsive navigation shell works: three top-level destinations (`/feed`, `/recipes`,
  `/profile`) with a desktop rail, tablet rail and mobile bottom bar, each with its own
  navigation stack.
- ✅ Database schema + RLS policies are written (3 migrations).
- ❌ **Nothing is buildable yet.** The Android/iOS/web platform scaffolding is incomplete.
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
[`supabase/README.md`](supabase/README.md) for the privacy model. They have never been applied —
the first time they reach a shared database they become append-only.

### Continuous integration

`.github/workflows/ci.yml` runs on every pull request:

| Job | What it proves |
|---|---|
| `SQL expectations` | The RLS policies and the `auth.users` leak guard still exist as written (python3, ~5s). |
| `Flutter analyze + test` | The code compiles, lints are clean, and 7 widget tests pass. |

## Repository layout

```
lib/
  main.dart                       entry point
  app.dart                        MaterialApp.router + GoRouter + breakpoints
  navigation/responsive_shell.dart  rail / bottom bar from one destination list
  screens/placeholder_screen.dart   body for destinations with no real screen yet
supabase/migrations/              001 schema · 002 indexes+triggers · 003 auth helpers
test/                             navigation + policy tests (run by CI)
tool/check_sql_expectations.py    fast local mirror of the policy assertions
docs/ANALYSIS_AND_ROADMAP.md      current state + delivery plan
```

## Development environment note

This repository is currently developed from a sandbox that has **no Flutter SDK and no network
access to the SDK download hosts**. Dart code is therefore written blind and verified by CI. That is
why the roadmap starts by turning CI into a build/artifact/preview server — see Phase 0 in the
roadmap.
