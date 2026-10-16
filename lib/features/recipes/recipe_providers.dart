import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/profile.dart';
import '../../data/models/recipe.dart';

/// One recipe, by id.
///
/// The type is inferred on purpose: `FutureProvider.family` returns a family type whose public
/// name has changed between Riverpod majors, and naming it here would pin this file to one.
///
/// A null *value* is not the same as an empty result: it means "no such recipe, or you are not
/// allowed to see it", which the policies make indistinguishable.
final recipeByIdProvider = FutureProvider.family<Recipe?, String>(
  (ref, id) => ref.watch(recipeRepositoryProvider).fetchById(id),
);

/// The recipes the acting user owns, private ones included.
///
/// Takes the id rather than reading a session provider itself: a signed-out client resolves to
/// an empty list rather than an error, because "you have no recipes" is a truthful thing to say
/// about somebody with no account.
final myRecipesProvider = FutureProvider.family<List<Recipe>, String?>(
  (ref, authorId) async {
    if (authorId == null) return const <Recipe>[];
    return ref.watch(recipeRepositoryProvider).fetchMine(authorId);
  },
);

/// A single profile by id.
final profileByIdProvider = FutureProvider.family<Profile?, String>(
  (ref, id) => ref.watch(recipeRepositoryProvider).fetchProfile(id),
);
