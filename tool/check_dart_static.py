#!/usr/bin/env python3
"""Fast source-level guardrails for the inferred auth foundation.

This is not a Dart parser and does not replace `flutter analyze` or the widget tests. It checks a
small set of security and routing invariants that are worth failing immediately if they disappear.
"""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent


CHECKS = [
    (
        "client initialization uses only the publishable/anon key",
        "lib/main.dart",
        ("publishableKey: Env.supabaseKey",),
    ),
    (
        "Supabase credentials come from the publishable-key dart-define",
        "lib/core/config/env.dart",
        ("String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY')",),
    ),
    (
        "the feed remains public and account routes are gated",
        "lib/core/router/auth_routes.dart",
        (
            "const String kFeedPath = '/feed'",
            "path == kRecipesPath",
            "path == kProfilePath",
            "String? safeNextLocation(String? candidate)",
        ),
    ),
    (
        "router redirects and refreshes when auth state changes",
        "lib/app.dart",
        (
            "refreshListenable: _authRouterRefresh",
            "requiresAuthenticatedUser(location)",
            "authRepository.currentUser",
        ),
    ),
    (
        "the Supabase adapter uses password auth and sends the profile username",
        "lib/data/repositories/supabase_auth_repository.dart",
        (
            "_client.auth.signInWithPassword(",
            "_client.auth.signUp(",
            "data: {'username': username.trim()}",
            "_client.auth.onAuthStateChange",
        ),
    ),
    (
        "recipe image uploads use an authenticated user folder and no overwrite",
        "lib/data/repositories/supabase_recipe_repository.dart",
        (
            "static const String _imageBucket = 'recipe-images'",
            "final String? userId = _client.auth.currentUser?.id",
            "final String path = '$userId/${_newImageName(upload.extension)}'",
            "await bucket.uploadBinary(",
            "FileOptions(contentType: upload.contentType, upsert: false)",
            "return bucket.getPublicUrl(path)",
        ),
    ),
    (
        "profile edits go through the draft, and cannot drop an avatar",
        "lib/data/models/profile.dart",
        (
            "class ProfileDraft",
            "'username': username",
            "'display_name': displayName",
            "'bio': bio",
        ),
    ),
    (
        "the profile write keeps the avatar and explains a taken username",
        "lib/data/repositories/supabase_recipe_repository.dart",
        (
            "Future<Profile> updateProfile(ProfileDraft draft)",
            ".from('profiles')",
            ".update(draft.toUpdateJson())",
            ".eq('id', draft.id)",
            "if (error.code == '23505')",
            "ProfileUpdateFailure('That username is taken.')",
        ),
    ),
    (
        "the in-memory profile write keeps the avatar it has no field for",
        "lib/data/repositories/in_memory_recipe_repository.dart",
        (
            "Future<Profile> updateProfile(ProfileDraft draft)",
            "avatarUrl: existing.avatarUrl",
            "ProfileUpdateFailure('That username is taken.')",
        ),
    ),
    (
        "the no-project path is explicitly ephemeral demo auth",
        "lib/data/repositories/in_memory_auth_repository.dart",
        (
            "class InMemoryAuthRepository implements AuthRepository",
            "ephemeral",
            "StreamController<AuthUser?>.broadcast",
        ),
    ),
]


def main() -> int:
    failures = []
    for title, relative_path, fragments in CHECKS:
        path = ROOT / relative_path
        if not path.is_file():
            failures.append(f"{title}: missing {relative_path}")
            continue

        source = path.read_text(encoding="utf-8")
        missing = [fragment for fragment in fragments if fragment not in source]
        if missing:
            failures.append(
                f"{title}: missing " + ", ".join(repr(fragment) for fragment in missing)
            )
        else:
            print(f"  ok  {title}")

    env_config = ROOT / 'lib/core/config/env.dart'
    if env_config.is_file():
        if 'SUPABASE_SERVICE_ROLE_KEY' in env_config.read_text(encoding='utf-8'):
            failures.append('client configuration must not define a service_role key')
        else:
            print('  ok  client configuration has no service_role key define')

    total_checks = len(CHECKS) + 1
    print()
    print(f"Dart static checks: {total_checks - len(failures)}/{total_checks} passed")
    for failure in failures:
        print(f"  FAIL {failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
