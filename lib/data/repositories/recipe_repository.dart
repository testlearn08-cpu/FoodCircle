import '../models/profile.dart';
import '../models/recipe.dart';
import '../models/recipe_image_upload.dart';

/// Everything the UI is allowed to ask of the backend: recipes, and the profiles that their
/// authors are read through.
///
/// The UI depends on this interface, never on Supabase, which is what lets the app run with no
/// project configured ([InMemoryRecipeRepository]) and lets widget tests stay hermetic.
abstract class RecipeRepository {
  /// The public feed: newest first.
  ///
  /// Pagination is keyset-based on `created_at` (see migration 004's partial index) rather than
  /// OFFSET, so a recipe added while someone is scrolling cannot make them see a duplicate.
  ///
  /// [query] is a case-insensitive substring match against the title **or any ingredient**, and
  /// [tag] is an exact tag match. Both are optional and combine; either one present means the
  /// filtering happens in the database, because matching a substring of one element of a
  /// `text[]` is not something a PostgREST filter can express — see
  /// `supabase/migrations/006_recipe_search.sql`.
  ///
  /// The two implementations are required to agree: a query of `50%` matches the literal text
  /// `50%` in both, rather than acting as a LIKE wildcard.
  Future<List<Recipe>> fetchFeed({
    int limit = 20,
    DateTime? before,
    String? query,
    String? tag,
  });

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

  /// Replaces the caller's own editable profile fields.
  ///
  /// An update, never an insert: the row is created by the `handle_new_user` trigger when the
  /// account is, so there is nothing for the app to create. `profiles_update_own` restricts the
  /// write to the caller's own row, which is why a wrong [ProfileDraft.id] fails rather than
  /// editing somebody else.
  ///
  /// Throws a [ProfileUpdateFailure] when the username is already taken — the one refusal a
  /// person can fix by typing something else, and therefore the one the UI has to explain.
  Future<Profile> updateProfile(ProfileDraft draft);

  /// Uploads a recipe image and returns its public URL for `RecipeDraft.imageUrl`.
  ///
  /// The current bucket name, public visibility, MIME allowlist, size limit, and user-folder path
  /// are inferred and provisional. Reconcile them with the authoritative handoff before deploy.
  Future<String> uploadImage(RecipeImageUpload upload);

  Future<Recipe> create(RecipeDraft draft);

  /// Replaces an existing recipe's content.
  ///
  /// The author is fixed at creation: `author_id` is not part of the update, and the update
  /// policy (`recipes_update_own`) rejects anyone but the author anyway.
  Future<Recipe> update(String id, RecipeDraft draft);

  Future<void> delete(String id);
}

/// A safe-to-display error from a profile write.
///
/// Separate from a raw [StateError] policy refusal because this one is *for* the person typing:
/// it has a message worth showing in the form, next to the field that caused it.
class ProfileUpdateFailure implements Exception {
  const ProfileUpdateFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
