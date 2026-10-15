// The feed screen, driven through the real provider graph with the repository swapped out.
//
// This is what the in-memory repository buys: the screen under test is the one that ships, the
// provider wiring is the wiring that ships, and the only thing replaced is the thing that would
// have needed a network.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/app.dart';
import 'package:foodcircle/core/config/env.dart';
import 'package:foodcircle/core/providers.dart';
import 'package:foodcircle/data/models/profile.dart';
import 'package:foodcircle/data/models/recipe.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';
import 'package:foodcircle/data/repositories/recipe_repository.dart';

class _FailingRepository implements RecipeRepository {
  int calls = 0;

  @override
  Future<List<Recipe>> fetchFeed({
    int limit = 20,
    DateTime? before,
    String? query,
    String? tag,
  }) async {
    calls++;
    throw StateError('the network is on fire');
  }

  @override
  Future<Recipe?> fetchById(String id) async => throw UnimplementedError();

  @override
  Future<List<Recipe>> fetchMine(String authorId, {int limit = 50}) async =>
      throw UnimplementedError();

  @override
  Future<Profile?> fetchProfile(String id) async => throw UnimplementedError();

  @override
  Future<Recipe> create(RecipeDraft draft) async => throw UnimplementedError();

  @override
  Future<Recipe> update(String id, RecipeDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) async => throw UnimplementedError();
}

Future<void> pumpFeed(WidgetTester tester, RecipeRepository repository) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        recipeRepositoryProvider.overrideWithValue(repository)
      ],
      child: const FoodCircleApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders recipes from the repository', (tester) async {
    await pumpFeed(tester, InMemoryRecipeRepository.seeded());

    expect(find.text('Everyday dal'), findsOneWidget);
    expect(find.text('No-knead bread'), findsOneWidget);
    // The author's display name comes from the joined profile, not the recipe row.
    expect(find.textContaining('Ana'), findsWidgets);
  });

  testWidgets('says it is a demo when no project is configured',
      (tester) async {
    // The test build never passes --dart-define, so this is the unconfigured path.
    expect(Env.isConfigured, isFalse);

    await pumpFeed(tester, InMemoryRecipeRepository.seeded());

    expect(find.textContaining('Demo data'), findsOneWidget);
  });

  testWidgets('shows an empty state rather than an empty list', (tester) async {
    await pumpFeed(tester, InMemoryRecipeRepository());

    expect(find.text('Nothing here yet'), findsOneWidget);
    // Scrollable even with nothing in it, or RefreshIndicator would have nothing to attach to.
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('shows the failure and offers a retry that retries',
      (tester) async {
    final repository = _FailingRepository();
    await pumpFeed(tester, repository);

    expect(find.text('Could not load the feed'), findsOneWidget);
    expect(find.textContaining('the network is on fire'), findsOneWidget);
    // Not an exact count any more: the tag chips are derived from the feed and read the same
    // repository, so they fail alongside it. What matters is that the feed was asked at all, and
    // that asking again is what the retry does.
    final int before = repository.calls;
    expect(before, greaterThan(0));

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.calls, greaterThan(before),
        reason: 'retry must re-run the provider, not just rebuild');
  });
}
