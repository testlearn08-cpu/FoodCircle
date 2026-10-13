# FoodCircle Architecture (Inferred / Unverified)

Status: Implemented (document). Unverified — exact architecture from v0.2 prototype / handoff unavailable.

## Stack
- Flutter 3.10+ (Android / iOS / Web shared foundation)
- Supabase (PostgreSQL + Auth + Storage)
- GoRouter (navigation)
- ResponsiveFramework (breakpoints)
- Riverpod (state — referenced in pubspec.yaml, not yet integrated)

## Shared Foundation
- `lib/main.dart` — entry point.
- `lib/app.dart` — MaterialApp.router with responsive breakpoints.
- `lib/navigation/responsive_shell.dart` — responsive navigation (drawer/rail/bottom nav).
- `android/app/` — Android manifest and build config.
- `ios/Runner/` — iOS runner assets and config placeholders.
- `web/index.html` — web entry.

## Privacy Rules (Unverified Against Prototype)
- Profiles: read all; update/delete own.
- Recipes: read public or own; insert/update/delete own.
- RLS enabled on both tables.

## Dependencies Missing / Unverified
- Flutter SDK (`flutter` not in `$PATH`).
- Supabase CLI (`supabase` not in `$PATH`).
- No running Supabase instance for migration validation.
- No development handoff / v0.2 prototype document to confirm exact architecture, privacy rules, or authorization requirements.
