import 'package:flutter/foundation.dart';
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

/// What the feed is currently showing: the search text and the tag filter.
///
/// Value equality matters here: the feed re-queries whenever this changes, and typing a letter
/// and deleting it again should not be two round trips.
@immutable
class FeedQuery {
  const FeedQuery({this.text = '', this.tag});

  final String text;
  final String? tag;

  /// Whether anything is actually being filtered. Drives which empty state the feed shows.
  bool get isFiltered => text.trim().isNotEmpty || tag != null;

  FeedQuery copyWith({String? text, String? tag, bool clearTag = false}) =>
      FeedQuery(
        text: text ?? this.text,
        tag: clearTag ? null : (tag ?? this.tag),
      );

  @override
  bool operator ==(Object other) =>
      other is FeedQuery && other.text == text && other.tag == tag;

  @override
  int get hashCode => Object.hash(text, tag);
}

/// The feed's filter state. The search field and the tag chips both write to it; the feed reads
/// it. Nothing else holds a copy, so the two controls cannot disagree.
final StateProvider<FeedQuery> feedQueryProvider =
    StateProvider<FeedQuery>((ref) => const FeedQuery());

/// The public feed, filtered by [feedQueryProvider].
///
/// `ref.invalidate(feedProvider)` re-fetches it — that is what pull-to-refresh, the error state's
/// retry button and the editor's save all do.
final FutureProvider<List<Recipe>> feedProvider = FutureProvider<List<Recipe>>(
  (ref) {
    final FeedQuery query = ref.watch(feedQueryProvider);
    return ref
        .watch(recipeRepositoryProvider)
        .fetchFeed(query: query.text, tag: query.tag);
  },
);

/// Every tag that appears in the current feed, for the filter chips.
///
/// Derived from the feed rather than from a `distinct tag` query because there is no such
/// endpoint: a view is forbidden by the security model (check 2 of the behavioural suite) and a
/// second function would be more surface than this needs. It deliberately does **not** watch
/// [feedQueryProvider] — if it did, selecting a tag would remove every other tag from the chips
/// and there would be no way back.
///
/// Anything that writes a recipe invalidates this alongside [feedProvider], because the set of
/// tags can change with the recipes.
final FutureProvider<List<String>> feedTagsProvider =
    FutureProvider<List<String>>((ref) async {
  final List<Recipe> recipes =
      await ref.watch(recipeRepositoryProvider).fetchFeed(limit: 50);

  final Set<String> tags = <String>{
    for (final Recipe recipe in recipes) ...recipe.tags,
  };
  return tags.toList()..sort();
});
