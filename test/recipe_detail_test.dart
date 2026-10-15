// A recipe's own page, reached the way a person reaches it: by tapping it in the feed.
//
// Scope note: the shell keeps the branches it has built, and a pushed route keeps the screen
// below it in the tree, so an unscoped `find.text` can match the same recipe twice. Every
// assertion here is scoped to the screen it is about.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/app.dart';
import 'package:foodcircle/core/providers.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';
import 'package:foodcircle/data/repositories/recipe_repository.dart';
import 'package:foodcircle/features/feed/feed_screen.dart';
import 'package:foodcircle/features/recipes/recipe_detail_screen.dart';

/// Phone width, and tall enough that the whole page is laid out without scrolling: these tests
/// are about what the screen says, not about how far down it is.
const Size kPhone = Size(430, 1600);

Future<void> pumpAppAt(
  WidgetTester tester,
  RecipeRepository repository, [
  Size size = kPhone,
]) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        recipeRepositoryProvider.overrideWithValue(repository),
      ],
      child: const FoodCircleApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Text on the page being tested, ignoring identical text on whatever is behind it.
Finder onDetail(String text) => find.descendant(
      of: find.byType(RecipeDetailScreen),
      matching: find.text(text),
    );

Future<void> openFromFeed(WidgetTester tester, String title) async {
  await tester.tap(find.descendant(
    of: find.byType(FeedScreen),
    matching: find.text(title),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a recipe page shows what you need to cook it', (tester) async {
    await pumpAppAt(tester, InMemoryRecipeRepository.seeded());

    await openFromFeed(tester, 'Everyday dal');

    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    expect(onDetail('Everyday dal'), findsOneWidget);
    expect(
      onDetail('The one that gets made when nobody can decide.'),
      findsOneWidget,
    );
    expect(onDetail('Ingredients'), findsOneWidget);
    expect(onDetail('1 cup red lentils'), findsOneWidget);
    expect(onDetail('Steps'), findsOneWidget);
    expect(
      onDetail('Rinse the lentils until the water runs clear.'),
      findsOneWidget,
    );
    // Meta the feed only hinted at.
    expect(onDetail('4 servings'), findsOneWidget);
    expect(onDetail('45 min'), findsOneWidget);
    expect(onDetail('easy'), findsOneWidget);
  });

  testWidgets('the author can delete their own recipe, from its page',
      (tester) async {
    await pumpAppAt(tester, InMemoryRecipeRepository.seeded());

    await openFromFeed(tester, 'Everyday dal');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this recipe?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Back on the feed, and the recipe is gone from it.
    expect(find.byType(RecipeDetailScreen), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FeedScreen),
        matching: find.text('Everyday dal'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(FeedScreen),
        matching: find.text('No-knead bread'),
      ),
      findsOneWidget,
    );
  });

  testWidgets("someone else's recipe offers no delete action", (tester) async {
    // Seeded demo data: "No-knead bread" belongs to Dev, and the acting user is Ana.
    await pumpAppAt(tester, InMemoryRecipeRepository.seeded());

    await openFromFeed(tester, 'No-knead bread');

    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RecipeDetailScreen),
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsNothing,
      reason: 'the UI hides what the policies would refuse',
    );
  });

  testWidgets('a private recipe says so on its page', (tester) async {
    await pumpAppAt(tester, InMemoryRecipeRepository.seeded());

    // Private, but it is Ana's own, so it is in her feed and identifiable as private.
    await openFromFeed(tester, 'Leftover rice fritters');

    expect(onDetail('Private'), findsOneWidget);
    expect(onDetail('Mix.'), findsOneWidget);
  });
}
