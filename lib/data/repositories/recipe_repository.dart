import '../models/profile.dart';
import '../models/recipe.dart';

/// Everything the UI is allowed to ask of recipes.
///
/// The UI depends on this interface, never on Supabase, which is what lets the app run with no
/// project configured ([InMemoryRecipeRepository]) and lets widget tests stay hermetic.
abstract class RecipeRepository {
  /// The public feed: newest first.
  ///
  /// Pagination is keyset-based on `created_at` (see migration 004's partial index) rather than
  /// OFFSET, so a recipe added while someone is scrolling cannot make them see a duplicate.
  Future<List<Recipe>> fetchFeed({int limit = 20, DateTime? before});

  /// A single recipe. Returns null when it does not exist *or* when the reader is not allowed
  /// to see it — the policies make those indistinguishable on purpose, and a UI that needs to
  /// tell them apart would be a UI that leaks the existence of other people's private recipes.
  Future<Recipe?> fetchById(String id);

  /// The signed-in user's own recipes, newest first.
  ///
  /// Unlike [fetchFeed] this includes the author's private recipes: `recipes_read_public`
  /// allows an author to read their own rows whether they are public or not.
  Future<List<Recipe>> fetchMine(String authorId, {int limit = 50});

  /// A single profile. Returns null when there is no such row.
  ///
  /// Profiles are readable by anyone, including `anon` (`profiles_read_all`), which is what makes
  /// an author's name and avatar available next to their recipes. Only the owner can write their
  /// own row.
  Future<Profile?> fetchProfile(String id);

  Future<Recipe> create(RecipeDraft draft);

  /// Replaces an existing recipe's content.
  ///
  /// The author is fixed at creation: `author_id` is not part of the update, and the update
  /// policy (`recipes_update_own`) rejects anyone but the author anyway.
  Future<Recipe> update(String id, RecipeDraft draft);

  Future<void> delete(String id);
}
