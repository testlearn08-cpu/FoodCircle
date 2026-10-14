# FoodCircle — Full Analysis & Continuation Plan

> Written: 2026-10-14 · Branch: `arena/d6651471-foodcircle` · Base commit: `eff5019` (main)
> Supersedes the "Next Steps" sections in `DEVELOPMENT_STATUS.md` and the open questions in `ARCHITECTURE.md`.

---

## 1. TL;DR — where the project actually stands

**FoodCircle today is a navigation skeleton with a genuinely green CI pipeline and zero product
functionality.** The 615 lines of Dart in the repo are a router, a responsive nav shell, one
placeholder screen, and 362 lines of tests. There is no data layer, no authentication, no screen
that shows a recipe, and no buildable Android/iOS/web target. Supabase is *declared* in
`pubspec.yaml` and *never imported*.

Three things changed my read versus what the existing docs say, and all three are verified:

1. **The docs are stale in the project's favour.** `ARCHITECTURE.md` and `DEVELOPMENT_STATUS.md`
   both say "nothing has ever been compiled". That is no longer true: **CI run
   [38525965333](https://github.com/testlearn08-cpu/FoodCircle/actions/runs/38525965333) passed
   `flutter pub get`, `flutter analyze`, and `flutter test` on 2026-10-14.** The code compiles and
   the widget tests pass. That is a real milestone and the docs should stop hedging about it.
2. **The local environment is permanently blind, but CI is a usable build server.** `pub.dev` and
   `storage.googleapis.com` are unreachable from the sandbox (only `github.com`, `registry.npmjs.org`,
   `pypi.org` and `files.pythonhosted.org` respond), so no Flutter SDK can be installed here — that
   is now a confirmed constraint, not a guess. However, `git`/`gh`/`api.github.com` work fully, and
   Actions minutes are free on this public repo. **GitHub Actions is therefore the compiler, the test
   runner, *and* potentially the build/preview host for this project.**
3. **CI is currently write-only from here.** I can see *that* a job failed (step-level conclusions via
   the API) but I **cannot read job logs** — the log endpoint redirects to
   `results-receiver.actions.githubusercontent.com`, which is outside the sandbox allowlist
   (`gh run view --log` returns `EOF`). Until this is fixed, every CI failure is a blind guess.
   Fixing it is task **P0.1** and it gates almost everything else.

**Verdict:** the foundation is sound enough to build on — do not rewrite it. The next move is not
"more features", it is **making the feedback loop real** (build artifacts, readable logs, runnable
app) and then **laying a real data + auth foundation**, because today there is no app to add features
to.

---

### Progress log

| Item | State | Evidence |
|---|---|---|
| P0.1 CI exports logs + artifacts to `ci-artifacts`, runs on `arena/**`, `workflow_dispatch` | ✅ done | run 38535122523; logs readable from the sandbox via `git fetch origin ci-artifacts` |
| P0.2 `flutter build web` → `preview` branch, served as a live preview | ✅ done | run 38534656981 built and published `build/web`; served locally and verified asset-by-asset |
| P0.3 `flutter build apk --debug` job | ✅ done | run 38535122523: `✓ Built build/app/outputs/flutter-apk/app-debug.apk` (229.9 s) |
| P0.4 Regenerate platform scaffolding via `flutter create` | ✅ done | 64 files added; my hand-written manifest diffs against the pristine template by exactly our three intended lines |
| P0.5 `analysis_options.yaml` + `flutter_lints` + `dart format` gate | ✅ done | first run surfaced 5 real lints and 2 unformatted files — all fixed; `dart format` is now a gate |
| P0.6 Docs rewritten to match reality | ✅ done | README, `ARCHITECTURE.md`, `DEVELOPMENT_STATUS.md` banners |
| P0.5+ Behavioural SQL tests (Postgres service container) | ⬜ next | Phase 0.5 below |

Toolchain pinned by observation (not by guesswork): **Flutter 3.47.7 stable · Dart 3.13.5**
(revision `abaf9c52`), Android Gradle Plugin 9.1.0, Gradle 9.3.1, Kotlin 2.4.0, Java 17.

## 2. Method — how the analysis was produced

| Check | Result |
|---|---|
| Repository inventory (`find`, file counts, LOC) | 23 tracked files; 615 Dart LOC (362 test), 174 SQL LOC |
| Read every source file in full | Done — all 6 Dart files, 3 migrations, 2 docs, CI, tool script |
| Ran the only locally-runnable check | `python3 tool/check_sql_expectations.py` → **22/22 assertions, 0 failures** |
| Toolchain probe (`flutter`, `dart`, `supabase`, `psql`, `docker`, `java`, `gradle`) | **All absent**; node 22.22.3, npm 10.9.8, python 3.11.2, git 2.39.5, gh 2.23.0 |
| Network probe | `api.github.com` ✅, `registry.npmjs.org` ✅, `pub.dev` ❌, `storage.googleapis.com` ❌ |
| GitHub state (`gh`) | 3 PRs (all merged), 0 open issues, 4 branches, repo public, Actions enabled |
| CI history | 2 runs, both `success`; **Flutter analyze + test has executed for real** |
| CI log retrieval | ❌ blocked (`results-receiver.actions.githubusercontent.com` unreachable) |
| Flutter-tool file expectations (13 canonical files) | **9 of 13 missing** (see §4.1) |

---

## 3. Inventory — what exists and what it actually does

### 3.1 Application code (615 LOC)

| File | LOC | State | Notes |
|---|---|---|---|
| `lib/main.dart` | 6 | Implemented | `runApp` only. No `WidgetsFlutterBinding`, no `Supabase.initialize`, no `ProviderScope`. |
| `lib/app.dart` | 101 | Implemented, compiles | `MaterialApp.router`, `StatefulShellRoute.indexedStack` with 3 branches, `ResponsiveBreakpoints.builder`. |
| `lib/navigation/responsive_shell.dart` | 118 | Implemented, compiles | Single `kNavigationDestinations` source for rail + bottom bar; correct `goBranch` re-tap semantics. |
| `lib/screens/placeholder_screen.dart` | 28 | Implemented | "Not implemented yet". This is **all three screens**. |
| `test/auth_test.dart` | 145 | Executed ✅ | 7 widget tests; pass in CI. |
| `test/privacy_test.dart` | 217 | Executed ✅ | String-matching over SQL. Catches regressions, proves nothing about runtime behaviour. |

### 3.2 Database (174 LOC, 3 migrations, never applied anywhere)

| Migration | Contents |
|---|---|
| `001_initial_schema.sql` | `profiles` (id→`auth.users`, username unique, display_name, avatar_url, bio, timestamps), `recipes` (author_id NOT NULL, title, description, `ingredients jsonb`, `steps jsonb`, `is_public`), RLS enabled, 8 policies (`DROP POLICY IF EXISTS` before each). |
| `002_indexes_and_triggers.sql` | 4 indexes, `update_updated_at()` + triggers on both tables. |
| `003_auth_helpers.sql` | `DROP VIEW IF EXISTS public.auth_users` (leak fix), `handle_new_user()` SECURITY DEFINER signup trigger with `SET search_path = ''`, `REVOKE … FROM PUBLIC`. |

Schema is coherent for a *read-another-user's-recipe* app, but holds **no social data** (no likes,
saves, comments, follows), **no tags/search**, **no image storage bucket**, and no metadata a recipe
app needs (servings, times, difficulty).

### 3.3 Tooling & docs

- `.github/workflows/ci.yml` — `sql-expectations` (python, passes) + `flutter` (pub get / analyze / test, passes). Triggers: `push` to `main` only, plus `pull_request`. **No `workflow_dispatch`, no branch pushes, no artifacts, no build step.**
- `tool/check_sql_expectations.py` — honest stand-in for `flutter test`; now redundant in principle but useful as a 5-second guard. Keep.
- Docs (`ARCHITECTURE.md`, `DEVELOPMENT_STATUS.md`, `supabase/README.md`) are unusually good on *reasoning* and unusually outdated on *status*. `README.md` is a single line: `# FoodCircle`.

---

## 4. Gap analysis, by layer

Severity: 🔴 blocker · 🟠 high · 🟡 medium · ⚪ later

### 4.1 Platform / build — 🔴 nothing is buildable

9 of the 13 files the Flutter tool and platform toolchains require are missing:

```
analysis_options.yaml        MISSING   → flutter_lints declared in pubspec, never enabled → default lints only
.metadata                    MISSING   → tooling can't identify project/version/migration info
web/manifest.json (+ icons)  MISSING   → PWA metadata absent
android/settings.gradle      MISSING   ┐
android/build.gradle         MISSING   ├ `flutter build apk` cannot work at all
android/gradle.properties    MISSING   │
…MainActivity.kt             MISSING   ┘ (`AndroidManifest.xml` points at a class that doesn't exist)
ios/Runner/Info.plist        MISSING   ┐
ios/Runner.xcodeproj/…       MISSING   ┘ `flutter build ios` cannot work at all
```

`android/app/build.gradle` and `AndroidManifest.xml` are hand-written fragments of a real Android
module; the iOS side is one app-icon `Contents.json`. **Consequence: the app has never run anywhere,
on any platform, ever.** Android/iOS scaffolding must be generated by the Flutter tool itself
(`flutter create --platforms=…`) rather than hand-written — the Xcode `project.pbxproj` is not
something to author by hand. That generation must happen in CI, then be pulled back into the repo.

### 4.2 Feedback loop — 🔴 we cannot see CI failures

- Logs unreadable from the sandbox (see §1.3). A failing `flutter analyze` would give me one bit.
- CI does not run on session branches without a PR; push-to-`arena/*` silently does nothing.
- CI builds nothing — no web bundle, no APK — so there is no way to *look at* the app.
- No coverage, no `dart format --set-exit-if-changed`, no pinned Flutter version
  (`node:20` deprecation notice already fires on `actions/checkout@v4`).

**This is the item that costs the most and is the cheapest to fix.** Export logs + build artifacts to
a bot branch (`ci-artifacts`) that I can `git fetch`; then a failure is a 30-second read instead of a
coin flip, and `python3 -m http.server` on a fetched `build/web` becomes a live preview you can click.

### 4.3 Application architecture — 🔴 no layers

- **No state management.** `flutter_riverpod` is a dependency with zero imports. Everything is
  `StatefulWidget` + `MediaQuery`.
- **No Supabase client.** `supabase_flutter` is a dependency with zero imports;
  `Supabase.initialize()` appears nowhere; there is no config/secret plumbing (`--dart-define`, no
  `.env.example`, no `lib/config/`).
- **No data models, no repository layer, no error/loading states.** `Recipe` and `Profile` exist only
  as SQL.
- **No auth flow or route guard.** `GoRouter` has no `redirect`, no `/sign-in` or `/sign-up`, no
  `errorBuilder`. An unauthenticated user cannot be distinguished from an authenticated one.
- **No feature structure.** Five files total under `lib/`; no `features/`, `data/`, `core/`.
- 🟡 `ResponsiveBreakpoints.builder` is **decorative and risky**: the shell reads
  `MediaQuery.of(context).size.width` directly (`responsive_shell.dart:71`) while the breakpoint list
  in `app.dart:42-48` ends the desktop band at **1920** — a 2560px monitor falls outside every
  breakpoint. Either read the breakpoints properly (`ResponsiveBreakpoints.of(context)`) or drop the
  dependency; keeping both is the worst option.
- 🟡 `assets/` is declared and empty (`.gitkeep`); no images, icons, or splash configured.
- ⚪ No dark theme, no localization setup, no a11y semantics, no analytics/crash reporting.

### 4.4 Data & security — 🟠 policies are plausible, unproven, and incomplete

- **No migration has ever been applied to any Postgres.** Syntax, trigger creation on `auth.users`,
  `auth.uid()` behaviour under `SET ROLE`, and every policy are unverified.
- Policies are asserted by *string matching* in `test/privacy_test.dart` — this catches a weakened
  policy in review, and cannot catch a policy that is wrong when executed.
- Missing hardening: no `CHECK` on `username` format/length, `updated_at` has no `NOT NULL`, no
  `citext`/case-insensitive username uniqueness, no trigram or GIN index for search, `ingredients`/
  `steps` `jsonb` unvalidated (`jsonb_typeof = 'array'` not enforced).
- **No Supabase Storage bucket or storage policies** → image upload is impossible as designed.
- Minor: `REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC` runs *after* `CREATE TRIGGER`;
  on a re-run as a non-superuser, `CREATE TRIGGER` can then fail on the EXECUTE privilege check.
  Fine on Supabase's `postgres` role, worth a comment.
- ⚪ No `supabase/config.toml`, so `supabase start` (local dev DB) is not configured.

### 4.5 Product — 🔴 there is nothing to use

Three destinations (`/feed`, `/recipes`, `/profile`) render "Not implemented yet". **No user can sign
up, create a recipe, see a recipe, or edit a profile.** There is no search, no social graph, no
notifications. The product intent ("a responsive food sharing community app") is documented in one
sentence; the "approved v0.2 prototype / development handoff" referenced throughout the docs has now
been missing across **three consecutive sessions** — treat the spec as *not existing* and write one.

### 4.6 Docs / process / hygiene — 🟡

- `README.md` is one line — no setup, no run instructions, no env var contract.
- Status docs assert "nothing has been compiled", now false (CI is green).
- No `LICENSE` on a public repo; no issue templates, no `CODEOWNERS`, no PR template, no CHANGELOG.
- No release/versioning story (version pinned at `0.2.0+1` since the first PR).

---

## 5. Constraints that shape the plan

| # | Constraint | Consequence |
|---|---|---|
| C1 | No Flutter/Dart SDK locally, and it cannot be installed (pub.dev + Google storage unreachable) | All compilation, testing and building happens in CI. Code must be written "blind" and validated in small batches. |
| C2 | CI job logs are unreachable from the sandbox | CI must export its own logs/artifacts into a branch. **Blocker for everything else.** |
| C3 | GitHub Actions is free here (public repo) and has a 6-hour job limit | Mobile + web builds are feasible in CI. |
| C4 | No product spec, no prototype, no designs | We must write a one-page spec and get explicit sign-off before Phase 2, or accept inferred scope. |
| C5 | No Supabase project / credentials available | Auth and storage work can be written and unit-tested with fakes, but end-to-end verification needs a project (free tier) or a local stack. |
| C6 | Real Postgres is only available via CI service containers (no docker/psql locally) | RLS behaviour tests must run in CI. This is achievable and is the honest version of `privacy_test.dart`. |

---

## 6. Target architecture

```
lib/
  main.dart                     # ensureInitialized → Supabase.initialize(env) → runApp(ProviderScope)
  app.dart                      # MaterialApp.router + theme + router provider
  core/
    config/env.dart             # String.fromEnvironment, fails loudly when unset
    router/app_router.dart      # GoRouter + auth redirect guard + errorBuilder
    theme/app_theme.dart        # light/dark, design tokens
    widgets/                    # AsyncValueView, EmptyState, ErrorRetry, skeletons
  features/
    auth/         data/ domain/ presentation/     # controller + sign-in/sign-up screens
    feed/         data/ domain/ presentation/
    recipes/      data/ domain/ presentation/     # list, detail, editor
    profile/      data/ domain/ presentation/
  data/
    models/                     # Profile, Recipe, Comment (+ fromJson/toJson/copyWith)
    repositories/               # abstract + Supabase impl + in-memory fake
  navigation/responsive_shell.dart   # unchanged in spirit
supabase/
  config.toml                   # local dev stack
  migrations/004_…  005_…       # append-only from here on
  tests/                        # SQL behaviour tests (RLS) run in CI
```

**Rules going forward:** migrations become append-only the moment they are applied anywhere; every
feature gets a repository interface with a fake implementation (so widget tests stay hermetic and the
web preview can run on seed data); no PII or `service_role` key in the repo.

---

## 7. Roadmap

### Phase 0 — Make the loop real 🔴 *prerequisite for all other work* (size: M)

| # | Task | Why | Done when |
|---|---|---|---|
| P0.1 | CI exports logs + artifacts to a `ci-artifacts` bot branch; add `workflow_dispatch`, run on all branches; `checkout@v5` | The sandbox cannot read job logs; without this, failures are unguessable | I `git fetch origin ci-artifacts` and read `analyze.log` / `test.log` / `build-web.log` for any run |
| P0.2 | Add `flutter build web --release` job publishing to a `preview` branch | Gives a **clickable live preview** of the real app in this environment | The web bundle is servable from the sandbox and renders the nav shell |
| P0.3 | Add `flutter build apk --debug` job (artifact only) | Proves the mobile target actually builds | APK produced, build time recorded |
| P0.4 | Generate platform scaffolding via `flutter create --platforms=android,ios,web .` **in CI**, commit the result back | 9 required files are missing; pbxproj can't be hand-written | `android/`+`ios/`+`web/` complete and a debug APK builds |
| P0.5 | Add `analysis_options.yaml` with `flutter_lints`, fix resulting lints, add `dart format --set-exit-if-changed` | Lints are currently off; `flutter_lints` is a dead dependency | CI green with lints enabled |
| P0.6 | README + status docs rewritten to match reality (incl. this roadmap) | Docs claim the opposite of the truth about CI | New contributor can run everything from the README |

**Exit criteria for Phase 0:** green CI that runs analyze + test + web build + APK build + SQL
behaviour tests; readable logs; a live preview URL of the running app; docs accurate.

### Phase 0.5 — Prove the database (size: S, runs inside CI)

- Postgres service container; create a minimal `auth` stub schema (`auth.users`, `auth.uid()` backed
  by a GUC), apply all migrations in order, then run **behavioural** SQL tests with `SET ROLE anon` /
  `authenticated`: anon can read public recipes, cannot read a private one, cannot insert for another
  author, cannot update another's row; the signup trigger provisions exactly one profile row and
  survives a duplicate-username race.
- Keep `test/privacy_test.dart` as the fast static guard; it is no longer the *only* evidence.

### Phase 1 — Data & auth foundation (size: M–L)

- `004_recipes_metadata.sql`: `image_url`, `tags text[]`, `servings`, `prep_minutes`, `cook_minutes`,
  `difficulty`, `CHECK` constraints, `updated_at NOT NULL`, GIN index on tags, trigram index on title.
- `005_storage.sql`: `recipe-images` bucket + owner-scoped storage policies.
- App: `lib/core/config/env.dart` + `--dart-define` contract + `.env.example`;
  `Supabase.initialize`; `ProviderScope`; Riverpod providers for client, session, profile.
- Models + repository interfaces + Supabase impls + in-memory fakes.
- Auth: sign-up / sign-in / sign-out screens, session persistence, `GoRouter` redirect guard,
  auth-state-driven router refresh.
- Tests: fake-repository unit tests, auth-gate widget tests, sign-in → feed journey.

### Phase 2 — The actual product: Feed, Recipes, Profile (size: L)

- Feed: public recipes, paginated (keyset on `created_at,id`), pull-to-refresh, author chips,
  loading/empty/error states.
- Recipe detail: image, ingredients, steps, author card, edit/delete for the owner.
- Recipe editor: create/edit/delete with validation, image upload to Storage with progress + retry.
- Profile: view + edit own profile, avatar upload, "my recipes".
- Search & filters: title/ingredient/tag, sort by newest/popular.
- **Gate: one-page product spec signed off (C4)** — otherwise these screens encode guesses.

### Phase 3 — Social & retention (size: L)

- Likes, saves/favourites, comments (`006_social.sql` + policies + tests).
- The "circle" concept from the product name: follow/circle graph + a circle-scoped feed.
- Realtime via Supabase channels for comments/likes; notification inbox.
- Reporting/moderation basics (public app → required before any real launch).

### Phase 4 — Polish & release (size: M)

Dark theme, a11y semantics + text-scaling, i18n decision (decide *before* Phase 2 strings multiply),
launcher icons/splash, image caching, error reporting, release signing config, store metadata,
`LICENSE`, PR/issue templates, `CHANGELOG`, versioning (`0.3.0+2` onward).

### Deferred / explicit non-goals for now

Offline-first sync, iOS release pipeline (needs an Apple developer account), native
push notifications, payments, multi-language content, Docker-based local Supabase.

---

## 8. Risk register

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| R1 | **No product spec** — three sessions have looked for the v0.2 handoff and not found it | We build the wrong product, expensively | Write a 1-page spec in Phase 1; sign off before Phase 2 code |
| R2 | **Blind development** — no local compiler | Slow, guessy debugging; broken main | Phase 0 log/artifact export, small commits, CI on every push |
| R3 | Regenerating platform scaffolding overwrites something | Lost work | Nothing custom exists yet (only a manifest + gradle fragment) → safest moment is now |
| R4 | RLS policies wrong in a way string-matching can't see | Data leak on a public app | Phase 0.5 behavioural SQL tests; re-run after every policy change |
| R5 | Credentials mishandled (service_role committed) | Full DB compromise | Anon key only, via `--dart-define`; document in README; add a CI secret-scan step |
| R6 | No Supabase project available (C5) | Auth/storage can't be verified end-to-end | Build behind repository interfaces with fakes; verify when a project exists |
| R7 | Flutter/Dart version drift (`channel: stable`, unpinned) | Green today, red tomorrow with no code change | Pin a Flutter version in CI; bump deliberately |
| R8 | Scope sprawl across social features | Nothing ships | Phases are strictly ordered; Phase 2 must be usable end-to-end before Phase 3 starts |

---

## 9. Decisions I need from you

1. **Spec** — do you have the v0.2 prototype / handoff / any notes on what FoodCircle should *do*
   (screens, flows, who the users are)? If not, I'll write a one-page spec and you approve it.
2. **Verification target** — is a live **web preview** in this environment the fastest way for you to
   see progress, or do you care about an installable **Android APK** first?
3. **Supabase** — is there an existing project I should target (you can paste the project URL; the
   anon key is public-safe), or should everything stay fake-backed until you create one?
4. **Product scope for the next milestone** — minimum lovable product (auth + create/view recipes +
   profile), or should social features (likes, comments, circle/follow) land in the same push?

---

## 10. Immediate next actions (Phase 0, in order)

1. `ci-artifacts` log/artifact exporter + `workflow_dispatch` + all-branch triggers. *(Unblocks R2.)*
2. `flutter build web` → `preview` branch → serve it here → first screenshot of the app ever.
3. `flutter create` scaffolding regeneration → commit → `flutter build apk --debug` in CI.
4. `analysis_options.yaml` + lints + `dart format` gate.
5. Postgres-behaviour SQL test job (Phase 0.5).
6. Docs rewrite (README, `ARCHITECTURE.md` status, `DEVELOPMENT_STATUS.md` banner).

Everything above is verifiable from this sandbox — no credentials, no local SDK, no new services.
