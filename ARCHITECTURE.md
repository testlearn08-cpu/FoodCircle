# FoodCircle Architecture

> **Current continuation status (2026-10-16):** One app, not two parallel branches. The data/feed
> foundation, the product surface (recipe page, recipe box, editor, search, profile) and the
> inferred email/password auth + recipe-image-storage slice are integrated on one branch, and CI
> verifies the tree that results. The auth/storage slice was reconstructed from this repository's
> roadmap because the authoritative handoff is missing — it is verified, not approved. No Supabase
> project exists, and nothing is deployed. `docs/handoff/RECONCILIATION.md` records the assumptions
> that still need the real handoff.

## Stack
- Flutter 3.10+ (Android / iOS / Web shared foundation)
- Supabase (PostgreSQL + Auth + Storage) — connected and initialised when a project is
  configured; the app runs on in-memory repositories when one is not.
- GoRouter (navigation, including the auth redirect)
- Riverpod (repositories, the feed, the recipe pages, and the session)
- No responsive-layout package: the shell measures `MediaQuery` itself against the
  two constants in `responsive_shell.dart`. `responsive_framework` was removed after
  its breakpoint list turned out to be both unread and wrong at the top end.

## Shared Foundation
- `lib/main.dart` — entry point; initialises Supabase when configured, then runs the
  app inside a `ProviderScope`.
- `lib/app.dart` — `MaterialApp.router` and the `GoRouter` definition of record: the
  auth routes, the `redirect` that sends you to sign-in when you ask for `/recipes` or
  `/profile` without a session, and one `StatefulShellRoute` branch per destination,
  each owning its own stack.
- `lib/navigation/responsive_shell.dart` — responsive navigation shell plus the
  shared destination list and the two layout breakpoint constants.
- `lib/core/config/env.dart` — the `--dart-define` contract, and whether a project was
  configured at all.
- `lib/core/providers.dart` — every provider the screens read. Two of them are the
  identity seam: `authUserProvider` (the session, including the synchronously restored
  one at startup) and `currentUserIdProvider` (who the app is acting as — null when
  nobody is, which is a supported state and not an error).
- `lib/core/router/` — the auth paths, the return-target validation that keeps an auth
  link from becoming an open redirect, and the refresh that re-runs the redirect when
  the session changes.
- `lib/core/widgets/` — the widgets that keep the screens consistent: a recipe list
  with its three states, the demo-mode banner, the empty/error view, and the initials
  avatar.
- `lib/data/` — `models/` (Recipe, Profile, AuthUser, RecipeImageUpload) and
  `repositories/`: the auth and recipe interfaces, their Supabase adapters, and the
  in-memory fakes the demo build and the widget tests run on.
- `lib/features/` — `feed/` (public recipes), `recipes/` (recipe page, recipe box,
  editor), `profile/` (identity, your recipe box, sign-out), `auth/` (sign-in,
  sign-up).
- `android/app/` — Android manifest and build config.
- `ios/Runner/` — iOS runner assets and config placeholders.
- `web/index.html` — web entry that boots the generated `flutter_bootstrap.js`.
- `assets/` — empty asset directory; `pubspec.yaml` declares it, so it must exist
  or `flutter pub get` fails.

## Application startup and providers

- `lib/main.dart` initializes Flutter and conditionally initializes Supabase. The only client
  credential is the publishable/anon key supplied with `--dart-define`; `service_role` must never
  enter a client build.
- `lib/core/config/env.dart` reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` at build time.
- `lib/core/providers.dart` selects Supabase adapters when configured and in-memory fakes otherwise.
  The no-project auth fake is ephemeral demo behavior, not a security boundary or persistent account
  store.
- Recipe data and authentication are behind separate repository interfaces. UI code never receives
  Supabase tokens or calls Supabase Auth directly.

## Authentication and routing

`lib/data/repositories/auth_repository.dart` defines the app-facing sign-in, sign-up, sign-out and
session stream. `SupabaseAuthRepository` delegates to `supabase_flutter`, whose local session
persistence is used for configured builds; `InMemoryAuthRepository` emits an ephemeral demo identity
when no project is configured.

The public feed (`/feed`) is available signed out. `/recipes` and `/profile` are session-gated. The
router reads the current user for its initial redirect and listens to auth-state changes to rerun
redirects. Return targets are restricted to same-app paths. `/profile` currently provides only the
identity and a sign-out action; profile editing and recipe management remain in the later,
handoff-gated product phase.

Sign-up sends the username as auth metadata so the existing `handle_new_user` database trigger can
create the `public.profiles` row. Supabase may require email confirmation; in that case the UI tells
the user to confirm before signing in. The demo fake does not send email and never persists a
password.

> The email/password flow and the routes it gates are inferred, not approved product requirements.
> Reconcile them against the missing handoff before expanding the auth or onboarding surface.

## Responsive navigation

One `StatefulShellRoute.indexedStack` branch per top-level destination (`/feed`, `/recipes`,
`/profile`). The shell wraps the router's `StatefulNavigationShell`, which means:

- selecting a destination swaps only the branch body — the rail / bottom bar stays mounted;
- each destination keeps its own navigation stack;
- re-selecting the active destination pops that branch back to its root.

`ResponsiveShell` derives both layouts from the single `kNavigationDestinations` list, so the rail and
bottom bar cannot drift apart.

Breakpoints (identical in `lib/app.dart` and `responsive_shell.dart`): mobile <= 450, tablet 451–800,
desktop > 800. Desktop uses an extended rail, tablet a labelled compact rail, mobile a
`BottomNavigationBar`.

> `NavigationRail` asserts that an extended rail uses `labelType` of `null` or
> `NavigationRailLabelType.none`. Passing `selected` for the desktop case trips that assertion.

## Database and Storage

Migrations `001`–`004` define profiles, recipes, RLS, auth helpers and recipe metadata. Migration
`005_storage.sql` is an inferred, rewritable migration that creates the public `recipe-images` bucket
and confines insert/update/delete operations to the authenticated user's UUID folder. Its current
10 MiB and JPEG/PNG/WebP limits are provisional. Public reads are intentional for recipe images.

The test suite uses test-only stand-ins for Supabase-managed `auth` and `storage` objects, then checks
row and Storage policies against PostgreSQL. These tests prove behavior of the local migration model,
not deployment to a Supabase project. No project exists, no key is configured in CI, and no migration
has been deployed.

Other product-facing data models are not present yet: location, notifications and offline behavior
have no schema or implementation. Do not infer those subsystems without the authoritative handoff.

## Security notes

- Profiles are readable by anyone; their writes are owner-restricted.
- Recipes are readable when public or by their author; writes are restricted to the author.
- `recipes.author_id` is `NOT NULL` and references `auth.users`.
- A hardened `SECURITY DEFINER` trigger provisions profiles without exposing `auth.users` through a
  public view.
- Storage writes are folder-scoped using `(storage.foldername(name))[1] = auth.uid()::text`.
- RLS and Storage policies, not client-side checks, are the authorization boundary.
- `service_role` bypasses RLS and must never reach the client.

## Verification status

- The existing Phase 1a app and migrations `001`–`004` were compiled/tested by CI at main commit
  `d5b7e57307f4c0ff90e8bfd9cd3b6df685fb00a4`.
- The new auth Dart and migration `005` are not considered verified until the current branch's CI
  analyze, test, formatting and database-behavior jobs pass.
- This sandbox has no Flutter/Dart SDK, Supabase CLI or Supabase project. Local Python static checks
  supplement (but do not replace) CI compilation and PostgreSQL execution.
