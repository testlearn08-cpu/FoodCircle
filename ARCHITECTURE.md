# FoodCircle Architecture

> **Status update (2026-10-14):** the "Unverified" caveat below applied only to the authoring
> sandbox of the first pass. `flutter analyze` and `flutter test` have since run green in CI
> ([run 38525965333](https://github.com/testlearn08-cpu/FoodCircle/actions/runs/38525965333)),
> so the shared foundation, the navigation shell and the tests described here are now
> **verified to compile and pass**. The database migrations remain unapplied and unverified.
> See [`docs/ANALYSIS_AND_ROADMAP.md`](docs/ANALYSIS_AND_ROADMAP.md).

Status: Implemented (document). Unverified — exact architecture from the v0.2
prototype / handoff is still unavailable, and no Flutter SDK was present in the
authoring environment, so nothing here has been compiled or run.

## Stack
- Flutter 3.10+ (Android / iOS / Web shared foundation)
- Supabase (PostgreSQL + Auth + Storage) — connected and initialised when a project
  is configured; the app runs on in-memory repositories when one is not.
- GoRouter (navigation)
- Riverpod (repositories, the feed, the recipe pages, and the session seam below)
- No responsive-layout package: the shell measures `MediaQuery` itself against the
  two constants in `responsive_shell.dart`. `responsive_framework` was removed after
  its breakpoint list turned out to be both unread and wrong at the top end.

## Shared Foundation
- `lib/main.dart` — entry point; initialises Supabase when configured, then runs the
  app inside a `ProviderScope`.
- `lib/app.dart` — `MaterialApp.router` and the `GoRouter` definition: one
  `StatefulShellRoute` branch per destination, with each branch owning its stack.
- `lib/navigation/responsive_shell.dart` — responsive navigation shell plus the
  shared destination list and the two layout breakpoint constants.
- `lib/core/config/env.dart` — the `--dart-define` contract, and whether a project was
  configured at all.
- `lib/core/session.dart` — who the app is acting as. Phase 1b replaces the body of
  `currentUserIdProvider` with real auth state; the screens do not change.
- `lib/core/widgets/` — the widgets that keep the screens consistent: a recipe list
  with its three states, the demo-mode banner, the empty/error view, and the initials
  avatar.
- `lib/features/` — `feed/` (public recipes), `recipes/` (recipe page, recipe box,
  editor), `profile/`.
- `android/app/` — Android manifest and build config.
- `ios/Runner/` — iOS runner assets and config placeholders.
- `web/index.html` — web entry that boots the generated `flutter_bootstrap.js`.
- `assets/` — empty asset directory; `pubspec.yaml` declares it, so it must exist
  or `flutter pub get` fails.

## Navigation
One `StatefulShellRoute.indexedStack` branch per top-level destination
(`/feed`, `/recipes`, `/profile`). The shell wraps the router's
`StatefulNavigationShell`, which means:

- selecting a destination swaps only the branch body — the rail / bottom bar
  stays mounted;
- each destination keeps its own navigation stack;
- re-selecting the active destination pops that branch back to its root.

`ResponsiveShell` derives both layouts from the single
`kNavigationDestinations` list, so the rail and bottom bar cannot drift apart.

Breakpoints (identical in `lib/app.dart` and `responsive_shell.dart`):
mobile <= 450, tablet 451-800, desktop > 800. Desktop uses an extended rail,
tablet a labelled compact rail, mobile a `BottomNavigationBar`.

> Note: `NavigationRail` asserts that an extended rail uses `labelType` of
> `null` or `NavigationRailLabelType.none`. Passing `selected` for the desktop
> case — as an earlier revision did — trips that assertion on desktop widths.

## Privacy Rules (Unverified Against Prototype)
- Profiles: readable by anyone; insert / update / delete restricted to the owner
  (`auth.uid() = id`). The insert policy is required for a client to create its
  own profile row.
- Recipes: readable when `is_public` or when the reader is the author; insert /
  update / delete restricted to the author (`auth.uid() = author_id`).
- `recipes.author_id` is `NOT NULL`, matching what the insert policy enforces.
- RLS is enabled on both tables. Every policy is preceded by
  `DROP POLICY IF EXISTS`, so a partially applied migration can be re-run.
- `003_auth_helpers.sql` provisions a `public.profiles` row for each new
  `auth.users` row via a `SECURITY DEFINER` trigger function with an empty
  `search_path` and schema-qualified identifiers; `EXECUTE` is revoked from
  `PUBLIC`. It no longer exposes any view over `auth.users` — see below.

### Removed: `public.auth_users`
An earlier revision of `003_auth_helpers.sql` created
`CREATE VIEW public.auth_users AS SELECT id, email FROM auth.users`.

That view was a data leak. A PostgreSQL view runs with the privileges of its
owner unless `security_invoker` is set (the default is owner privileges through
at least PostgreSQL 15), so the view read `auth.users` without the RLS policies
that protect it. Because Supabase exposes the `public` schema to the `anon` key,
any client could have read every user's id and email address. The view is
dropped, and `test/privacy_test.dart` asserts that no migration creates a view.

## Verification Status
- Flutter SDK: **NOT PRESENT** (`flutter` / `dart` not in `$PATH`) — nothing is
  compiled, analysed, or tested.
- Supabase CLI / instance: **NOT PRESENT** — no migration has ever been applied.
- `tool/check_sql_expectations.py`: re-implements the assertions in
  `test/privacy_test.dart` in Python and confirms each expected fragment really
  occurs in the migrations. This is a stand-in for the un-runnable suite, not a
  substitute for it.
