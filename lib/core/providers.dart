import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../data/models/auth_user.dart';
import '../data/models/recipe.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/in_memory_auth_repository.dart';
import '../data/repositories/in_memory_recipe_repository.dart';
import '../data/repositories/recipe_repository.dart';
import '../data/repositories/supabase_auth_repository.dart';
import '../data/repositories/supabase_recipe_repository.dart';
import 'config/env.dart';

/// The one place that decides whether this build uses Supabase Auth or the demo fake.
///
/// Supabase is only touched on the configured path; the in-memory implementation is deliberately
/// ephemeral and is not an authentication boundary.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  if (!Env.isConfigured) {
    final repository = InMemoryAuthRepository();
    ref.onDispose(() => unawaited(repository.dispose()));
    return repository;
  }
  return SupabaseAuthRepository(Supabase.instance.client);
});

/// Current identity, including the synchronously restored session on app startup.
final StreamProvider<AuthUser?> authUserProvider = StreamProvider<AuthUser?>((
  ref,
) async* {
  final repository = ref.watch(authRepositoryProvider);
  yield repository.currentUser;
  yield* repository.userChanges;
});

/// The one place that decides whether this build talks to a real backend.
///
/// `Supabase.instance.client` throws when `Supabase.initialize` was never called, so it is only
/// touched on the configured path.
final Provider<RecipeRepository> recipeRepositoryProvider =
    Provider<RecipeRepository>((ref) {
  if (!Env.isConfigured) {
    return InMemoryRecipeRepository.seeded();
  }
  return SupabaseRecipeRepository(Supabase.instance.client);
});

/// The public feed. `ref.invalidate(feedProvider)` re-fetches it — that is what pull-to-refresh
/// and the error state's retry button both do.
final FutureProvider<List<Recipe>> feedProvider = FutureProvider<List<Recipe>>(
  (ref) => ref.watch(recipeRepositoryProvider).fetchFeed(),
);
