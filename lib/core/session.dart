import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/in_memory_recipe_repository.dart';
import 'config/env.dart';
import 'providers.dart';

/// Who the app is acting as, or null for "nobody in particular".
///
/// The real thing — sign-in and sign-up screens, session persistence, and a `GoRouter` redirect
/// guard that reacts to `onAuthStateChange` — is Phase 1b and is not built yet. Until it lands
/// this is the seam every product screen reads instead of reaching for an auth API itself, so
/// there is exactly one place to change when it does.
///
/// Two sources, in the order the app can trust them:
///
///  * a configured project: the Supabase session's user, which is null until someone signs in;
///  * no project at all: the in-memory repository's demo user, so the web preview and the widget
///    tests can exercise the writing screens too, not just the reading ones.
///
/// Returning null is a supported state, not an error: with no session the app is a read-only
/// browser of public recipes, which is exactly what the policies allow an anonymous client to do.
/// Every screen that writes has to cope with it.
final Provider<String?> currentUserIdProvider = Provider<String?>((ref) {
  if (!Env.isConfigured) {
    final repository = ref.watch(recipeRepositoryProvider);
    // The demo identity lives in the demo repository on purpose: there is no session there, so
    // the repository that stands in for one is the thing to read.
    return repository is InMemoryRecipeRepository
        ? repository.currentUserId
        : null;
  }

  // Not watched, only read: `auth.currentUser` is a snapshot, and a provider that rebuilds on
  // every auth event belongs with the rest of the auth state in Phase 1b.
  return Supabase.instance.client.auth.currentUser?.id;
});
