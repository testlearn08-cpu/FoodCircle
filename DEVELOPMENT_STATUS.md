# FoodCircle Development Status

> Tracking document for `arena/f20df4a6-foodcircle`.

## Session Context
- The requested branch `feature/foodcircle-v0.2-navigation` **does not exist** —
  not locally, not on `origin`. `origin` has only `main` and a leftover
  `arena/689ae9a0-foodcircle`.
- FoodCircle v0.2 was **already merged** to `main` as PR #1 ("FoodCircle v0.2:
  Foundation, Migrations, Responsive Nav, Auth Tests", merged 2026-10-13
  09:56 UTC), from `arena/689ae9a0-foodcircle`.
- This session is pinned to `arena/f20df4a6-foodcircle`, which was
  byte-identical to `main` at the start of this pass. Work therefore continues
  on that branch instead of the non-existent feature branch.

## Verified / Confirmed ✅
- [x] GitHub repo access: `https://github.com/testlearn08-cpu/FoodCircle` (read + push verified via `gh`).
- [x] PR #1 is `MERGED`; `main` is at `d3e6c81`.
- [x] Repository root preserved (`/home/user/FoodCircle`).
- [x] Flutter SDK: **NOT FOUND** (`flutter` / `dart` not in `$PATH`).
- [x] Supabase CLI: **NOT FOUND** (`supabase` not in `$PATH`); no running instance.
- [x] Development handoff / approved v0.2 prototype: **NOT FOUND** in the workspace.
- [x] User selected: harden the v0.2 surface (navigation, tests, RLS gap) rather than re-open the merged v0.2 or install a Flutter SDK.
- [x] User selected: leave the stale `arena/689ae9a0-foodcircle` remote branch in place.

## Functionality States
- **Implemented**: code/files written and committed.
- **Checked**: verified by a script that can actually run in this environment.
- **Unverified**: never compiled, rendered, or executed (no Flutter SDK, no Supabase instance).

---

## What Changed In This Pass

### Navigation now actually navigates
An earlier revision built the shell with `onDestinationSelected: (i) {}` and a
hardcoded `selectedIndex: 0`, so tapping a destination did nothing.

- `lib/app.dart` — replaced the nested placeholder routes with
  `StatefulShellRoute.indexedStack`, one branch per destination
  (`/feed`, `/recipes`, `/profile`). Previously `/feed` etc. were nested routes
  that returned a bare placeholder, which unmounted the entire shell — rail and
  bottom bar included — as soon as anything was selected.
- `lib/navigation/responsive_shell.dart` — the shell now takes the router's
  `StatefulNavigationShell`, drives `selectedIndex` / `currentIndex` from
  `navigationShell.currentIndex`, and calls `goBranch` on selection. Re-selecting
  the active destination pops that branch to its root.
- The rail and bottom bar are both generated from one `kNavigationDestinations`
  list, so the two layouts cannot drift apart.
- `lib/screens/placeholder_screen.dart` — new; `PlaceholderScreen` avoids
  shadowing Flutter's built-in `Placeholder`.
- The router is now owned per app instance instead of a `static final` global, so
  each widget test starts from a clean location.

### Fixed: desktop crash in `NavigationRail`
`NavigationRail` asserts that an **extended** rail uses `labelType` of `null` or
`NavigationRailLabelType.none`. The previous code set `extended: true` together
with `labelType: NavigationRailLabelType.selected`, which trips that assertion at
desktop widths. Now `labelType` is `null` when extended.

### Tests: real, and actually discoverable
- **Renamed `test/auth_tests.dart` → `test/auth_test.dart`** and
  `test/privacy_tests.dart` → `test/privacy_test.dart`. `flutter test` only
  discovers files ending in `_test.dart`, so the previous names meant the suite
  was silently never collected.
- `test/auth_test.dart` — replaced `expect(true, isTrue)` with widget tests that
  pump the app at three widths and assert the `NavigationRail` is extended on
  desktop, compact on tablet, and absent on mobile; that the bottom bar appears
  on mobile; and that selecting a destination swaps the body while keeping the
  shell mounted and advancing `selectedIndex` / `currentIndex`.
- `test/privacy_test.dart` — replaced four conceptual no-op tests with static
  assertions over the migration SQL: RLS enabled on both tables, all eight
  policies present with their exact `USING` / `WITH CHECK` clauses, and the
  `auth.users` leak guarded by asserting that no migration creates a view.

### Closed the `auth.users` leak
`003_auth_helpers.sql` previously created
`CREATE VIEW public.auth_users AS SELECT id, email FROM auth.users`. A view runs
with its owner's privileges unless `security_invoker` is set, so it bypassed RLS
on `auth.users`; with Supabase exposing `public` to the `anon` key, any client
could read every user's id and email. The view is dropped and replaced with a
signup trigger (`SECURITY DEFINER`, `SET search_path = ''`, schema-qualified
identifiers, `EXECUTE` revoked from `PUBLIC`) that provisions a profile row.

### Other gaps closed
- `profiles` had **no INSERT policy** — with RLS enabled, a client could not
  create its own profile row.
- `recipes.author_id` is now `NOT NULL`, matching what the insert policy already
  required; `is_public` is `NOT NULL DEFAULT true`.
- Every `CREATE POLICY` is preceded by `DROP POLICY IF EXISTS`, so a partially
  applied migration can be re-run instead of erroring on an existing policy.
- `assets/` now exists. `pubspec.yaml` declares it, and `flutter pub get` fails
  when a declared asset directory is missing.
- `web/index.html` loaded `main.dart.js` with no engine bootstrap, which renders
  a blank page; it now loads the generated `flutter_bootstrap.js`.

---

## Checked This Pass ✅
- [x] `tool/check_sql_expectations.py` — re-implements every assertion in
      `test/privacy_test.dart` in Python and confirms all 22 expected fragments
      really occur in the migrations they are read from, and that the negative
      assertions (`create view`, `create or replace view`) hold. **22/22, 0 failures.**
- [x] Delimiter balance across all six Dart files (comments and string contents
      stripped before balancing); all balanced.
- [x] Every `package:foodcircle/...` import resolves to a file that exists.
- [x] `kNavigationDestinations` is declared once and consumed by both layouts and
      by the tests; the previous `static final` router and `_Placeholder` are gone.

## Unverified ❓
- **Nothing has been compiled.** `flutter analyze` and `flutter test` have never
  been run — there is no Flutter SDK in this environment. The passing checks above
  are static; they cannot prove the Dart compiles or that the widgets render.
- GoRouter `StatefulShellRoute` behaviour (branch switching, state preservation,
  deep links) is unexercised.
- No migration has been applied to any database; the signup trigger, the policies
  and the `REVOKE` are all untested against PostgreSQL.
- `web/index.html` now targets `flutter_bootstrap.js`, which is correct for
  current Flutter stable but has not been built.

## Next Steps
- [ ] Install the Flutter SDK, then run `flutter pub get`, `flutter analyze` and
      `flutter test` — expect to fix compile errors, since none of this code has
      ever been through a compiler.
- [ ] Install the Supabase CLI and apply all three migrations to a scratch
      database; verify the signup trigger against a real `auth.users` insert.
- [ ] Add a CI workflow (e.g. `subosito/flutter-action` + `flutter test`) so the
      suite runs on push instead of relying on a clean local environment.
- [ ] Integrate Riverpod — it is declared in `pubspec.yaml` but unused.
- [ ] Obtain the development handoff / approved v0.2 prototype, and validate the
      privacy rules and authorization requirements against that spec.
- [ ] Replace `PlaceholderScreen` bodies with the real Feed / Recipes / Profile
      screens, and wire Supabase auth.
