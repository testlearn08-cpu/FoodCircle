import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/recipe.dart';
import '../models/recipe_image_upload.dart';
import 'recipe_repository.dart';

/// The real thing: PostgREST and Storage over the publishable/anon key, with RLS doing all the
/// authorization.
///
/// The current auth user is used only to construct the Storage object's owner-folder path; that
/// client-side value grants no permission. The policies in `supabase/migrations` remain the only
/// authorization boundary.
class SupabaseRecipeRepository implements RecipeRepository {
  SupabaseRecipeRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'recipes';
  static const String _imageBucket = 'recipe-images';
  static final Random _secureRandom = Random.secure();

  @override
  Future<List<Recipe>> fetchFeed({
    int limit = 20,
    DateTime? before,
    String? query,
    String? tag,
  }) async {
    final String needle = (query ?? '').trim();

    // Anything the filters can express sends the query to the database instead: matching a
    // substring of one element of the ingredients array is not something a PostgREST filter can
    // do, and the visibility rule has to stay in one place (the policies). See
    // supabase/migrations/006_recipe_search.sql.
    if (needle.isNotEmpty || tag != null) {
      final dynamic result = await _client.rpc(
        'search_recipes',
        params: <String, dynamic>{
          'q': needle.isEmpty ? null : needle,
          'tag': tag,
          'before': before?.toUtc().toIso8601String(),
          'max_rows': limit,
        },
      );

      final List<dynamic> rows = result is List ? result : const <dynamic>[];
      return _withAuthors(<Map<String, dynamic>>[
        for (final row in rows) Map<String, dynamic>.from(row as Map),
      ]);
    }

    var queryBuilder = _client.from(_table).select().eq('is_public', true);
    if (before != null) {
      queryBuilder =
          queryBuilder.lt('created_at', before.toUtc().toIso8601String());
    }

    final rows =
        await queryBuilder.order('created_at', ascending: false).limit(limit);
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
  Future<String> uploadImage(RecipeImageUpload upload) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in is required to upload a recipe image.');
    }

    // The authenticated session supplies the first path segment checked by migration 005. Do not
    // accept a caller-provided owner ID or filename; both could escape the user's Storage folder.
    final String path = '$userId/${_newImageName(upload.extension)}';
    final bucket = _client.storage.from(_imageBucket);
    await bucket.uploadBinary(
      path,
      upload.bytes,
      fileOptions: FileOptions(contentType: upload.contentType, upsert: false),
    );
    return bucket.getPublicUrl(path);
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

  static String _newImageName(String extension) {
    final String randomPart = List<int>.generate(
      16,
      (_) => _secureRandom.nextInt(256),
    ).map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '$randomPart.$extension';
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
