import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/recipe.dart';
import '../data/repositories/in_memory_recipe_repository.dart';
import '../data/repositories/recipe_repository.dart';
import '../data/repositories/supabase_recipe_repository.dart';
import 'config/env.dart';

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
