import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/recipe.dart';
import 'recipe_repository.dart';

/// The real thing: PostgREST over the anon key, with RLS doing all the authorisation.
///
/// Nothing here checks permissions. That is deliberate — the policies in `supabase/migrations`
/// are the only authorization boundary, and a client that also checks is a client that lies to
/// itself about being secure.
class SupabaseRecipeRepository implements RecipeRepository {
  SupabaseRecipeRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'recipes';

  @override
  Future<List<Recipe>> fetchFeed({int limit = 20, DateTime? before}) async {
    var query = _client.from(_table).select().eq('is_public', true);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return _withAuthors(rows);
  }

  @override
  Future<Recipe?> fetchById(String id) async {
    final row = await _client.from(_table).select().eq('id', id).maybeSingle();
    if (row == null) return null;

    final recipe = Recipe.fromJson(row);
    final authors = await _fetchAuthors(<String>{recipe.authorId});
    return recipe.copyWith(author: authors[recipe.authorId]);
  }

  @override
  Future<List<Recipe>> fetchMine(String authorId, {int limit = 50}) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .limit(limit);
    return _withAuthors(rows);
  }

  @override
  Future<Profile?> fetchProfile(String id) async {
    final row = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_url, bio')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  @override
  Future<Recipe> create(RecipeDraft draft) async {
    final row = await _client
        .from(_table)
        .insert(draft.toInsertJson())
        .select()
        .single();
    return Recipe.fromJson(row);
  }

  @override
  Future<Recipe> update(String id, RecipeDraft draft) async {
    final json = draft.toInsertJson()
      // A recipe cannot change author, and the update policy rejects the attempt anyway.
      ..remove('author_id')
      // The editor has no image field yet (uploads need the storage policies in migration 005),
      // so an edit must not silently drop an image the row already has.
      ..remove('image_url');

    final row =
        await _client.from(_table).update(json).eq('id', id).select().single();
    return Recipe.fromJson(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  Future<List<Recipe>> _withAuthors(List<Map<String, dynamic>> rows) async {
    final recipes = [for (final row in rows) Recipe.fromJson(row)];
    final authors = await _fetchAuthors(
      {for (final recipe in recipes) recipe.authorId},
    );
    return [
      for (final recipe in recipes)
        recipe.copyWith(author: authors[recipe.authorId]),
    ];
  }

  /// `recipes.author_id` references `auth.users`, not `profiles`, so there is no foreign key
  /// for PostgREST to embed the author along. One extra query for a page of recipes is cheaper
  /// than a join view that would have to be kept in step with the policies.
  Future<Map<String, Profile>> _fetchAuthors(Set<String> ids) async {
    if (ids.isEmpty) return const <String, Profile>{};

    final rows = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_url, bio')
        .inFilter('id', ids.toList());

    return {
      for (final row in rows) row['id'] as String: Profile.fromJson(row),
    };
  }
}
