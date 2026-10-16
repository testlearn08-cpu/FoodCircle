import 'package:flutter/foundation.dart';

import 'profile.dart';

/// A recipe, as stored in `public.recipes`.
///
/// Field names match the columns, so `fromJson` takes a PostgREST row directly. Parsing is
/// deliberately forgiving about *types* (PostgreSQL `integer` may arrive as an int or a num,
/// timestamps arrive as ISO-8601 strings) and strict about *shape*: a row without an id or an
/// author is a bug, not a default.
@immutable
class Recipe {
  const Recipe({
    required this.id,
    required this.authorId,
    required this.title,
    required this.createdAt,
    this.description,
    this.imageUrl,
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    this.difficulty,
    this.tags = const <String>[],
    this.ingredients = const <String>[],
    this.steps = const <String>[],
    this.isPublic = true,
    this.author,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        authorId: json['author_id'] as String,
        title: (json['title'] as String?) ?? '',
        // `created_at` is NOT NULL in the database, so this fallback is unreachable in
        // practice; it exists so a hand-written fixture missing one field does not crash the
        // app, and it sorts last rather than pretending to be recent.
        createdAt: _asDate(json['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        servings: _asInt(json['servings']),
        prepMinutes: _asInt(json['prep_minutes']),
        cookMinutes: _asInt(json['cook_minutes']),
        difficulty: json['difficulty'] as String?,
        tags: _asStringList(json['tags']),
        ingredients: _asStringList(json['ingredients']),
        steps: _asStringList(json['steps']),
        isPublic: (json['is_public'] as bool?) ?? true,
      );

  final String id;
  final String authorId;
  final String title;
  final DateTime createdAt;
  final String? description;
  final String? imageUrl;
  final int? servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final String? difficulty;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> steps;
  final bool isPublic;

  /// Filled in by the repository, which loads the authors of a page of recipes in one extra
  /// query rather than a join: `recipes.author_id` references `auth.users`, not `profiles`, so
  /// PostgREST has nothing to embed along.
  final Profile? author;

  /// Total time, when the author filled in either part of it.
  int? get totalMinutes {
    final prep = prepMinutes ?? 0;
    final cook = cookMinutes ?? 0;
    final total = prep + cook;
    return total > 0 ? total : null;
  }

  Recipe copyWith({Profile? author}) => Recipe(
        id: id,
        authorId: authorId,
        title: title,
        createdAt: createdAt,
        description: description,
        imageUrl: imageUrl,
        servings: servings,
        prepMinutes: prepMinutes,
        cookMinutes: cookMinutes,
        difficulty: difficulty,
        tags: tags,
        ingredients: ingredients,
        steps: steps,
        isPublic: isPublic,
        author: author ?? this.author,
      );
}

/// A recipe that is about to be created: everything the client chooses, and nothing the
/// database generates.
///
/// `authorId` is not optional because the insert policy checks `auth.uid() = author_id`: a
/// client physically cannot create a recipe on someone else's behalf, and this type makes that
/// obvious rather than letting it fail at runtime.
@immutable
class RecipeDraft {
  const RecipeDraft({
    required this.authorId,
    required this.title,
    this.description,
    this.imageUrl,
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    this.difficulty,
    this.tags = const <String>[],
    this.ingredients = const <String>[],
    this.steps = const <String>[],
    this.isPublic = true,
  });

  final String authorId;
  final String title;
  final String? description;
  final String? imageUrl;
  final int? servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final String? difficulty;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> steps;
  final bool isPublic;

  Map<String, dynamic> toInsertJson() => {
        'author_id': authorId,
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'servings': servings,
        'prep_minutes': prepMinutes,
        'cook_minutes': cookMinutes,
        'difficulty': difficulty,
        'tags': tags,
        'ingredients': ingredients,
        'steps': steps,
        'is_public': isPublic,
      };
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _asDate(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return List<String>.unmodifiable(value.map((item) => item.toString()));
  }
  return const <String>[];
}
