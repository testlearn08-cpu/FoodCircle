// Search and the tag filter, driven through the real feed screen and the real provider graph.
//
// The debounce is explicit in these tests: typing does not change the query until 300ms have
// passed, and pumping past it is what a person does by continuing to look at the screen. The
// enter key and the clear button are both immediate, and both are tested here too.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/app.dart';
import 'package:foodcircle/core/providers.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';
import 'package:foodcircle/features/feed/feed_screen.dart';

/// Longer than the search field's debounce, so a pump past it is enough to apply the query.
const Duration kPastDebounce = Duration(milliseconds: 350);

const Size kPhone = Size(430, 900);

Future<void> pumpFeed(WidgetTester tester) async {
  tester.view.physicalSize = kPhone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        recipeRepositoryProvider
            .overrideWithValue(InMemoryRecipeRepository.seeded()),
      ],
      child: const FoodCircleApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A recipe title on the feed, ignoring the same text anywhere else in the tree.
Finder onFeed(String text) => find.descendant(
      of: find.byType(FeedScreen),
      matching: find.text(text),
    );

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(kPastDebounce);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('typing filters the feed to matching recipes', (tester) async {
    await pumpFeed(tester);
    expect(onFeed('Everyday dal'), findsOneWidget);
    expect(onFeed('No-knead bread'), findsOneWidget);

    // "lentils" is in the dal's ingredients and in no title, which is the case search exists for.
    await search(tester, 'lentils');

    expect(onFeed('Everyday dal'), findsOneWidget);
    expect(onFeed('No-knead bread'), findsNothing);
  });

  testWidgets('the debounce means a half-typed word is not a query',
      (tester) async {
    await pumpFeed(tester);

    await tester.enterText(find.byType(TextField), 'no');
    // Immediately after typing, nothing has been applied yet.
    await tester.pump();
    expect(onFeed('Everyday dal'), findsOneWidget);

    // ...and once the debounce elapses, it has.
    await tester.pump(kPastDebounce);
    await tester.pumpAndSettle();
    expect(onFeed('Everyday dal'), findsNothing);
    expect(onFeed('No-knead bread'), findsOneWidget);
  });

  testWidgets('pressing enter searches immediately', (tester) async {
    await pumpFeed(tester);

    await tester.enterText(find.byType(TextField), 'bread');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(onFeed('No-knead bread'), findsOneWidget);
    expect(onFeed('Everyday dal'), findsNothing);
  });

  testWidgets('a search with no results offers a way out', (tester) async {
    await pumpFeed(tester);

    await search(tester, 'sourdough starter');

    expect(onFeed('No recipes match'), findsOneWidget);
    expect(onFeed('Everyday dal'), findsNothing);

    await tester.tap(onFeed('Clear search'));
    await tester.pumpAndSettle();

    // Back to the unfiltered feed, and the field is empty again rather than showing a search
    // that is no longer applied.
    expect(onFeed('Everyday dal'), findsOneWidget);
    expect(onFeed('No-knead bread'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('the clear button empties the field and the filter', (tester) async {
    await pumpFeed(tester);

    await search(tester, 'bread');
    expect(onFeed('Everyday dal'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(onFeed('Everyday dal'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('a tag chip filters, and tapping it again clears it',
      (tester) async {
    await pumpFeed(tester);

    // The chips are the tags that exist in the feed, sorted.
    expect(onFeed('#baking'), findsOneWidget);
    expect(onFeed('#vegetarian'), findsOneWidget);
    expect(onFeed('#weeknight'), findsOneWidget);

    await tester.tap(onFeed('#baking'));
    await tester.pumpAndSettle();

    expect(onFeed('No-knead bread'), findsOneWidget);
    expect(onFeed('Everyday dal'), findsNothing);
    // The other chips are still offered: filtering by a tag must not remove the way back.
    expect(onFeed('#vegetarian'), findsOneWidget);

    await tester.tap(onFeed('#baking'));
    await tester.pumpAndSettle();

    expect(onFeed('Everyday dal'), findsOneWidget);
    expect(onFeed('No-knead bread'), findsOneWidget);
  });

  testWidgets('a tag and a text query narrow together', (tester) async {
    await pumpFeed(tester);

    await tester.tap(onFeed('#weeknight'));
    await tester.pumpAndSettle();
    await search(tester, 'lentil');

    expect(onFeed('Everyday dal'), findsOneWidget);
    expect(onFeed('No-knead bread'), findsNothing);

    // The same text with a tag nothing matches: empty, and recoverable.
    await search(tester, 'bread');
    expect(onFeed('No recipes match'), findsOneWidget);

    await tester.tap(onFeed('Clear search'));
    await tester.pumpAndSettle();
    // "Clear search" clears everything, including the tag, or the feed would still look empty.
    expect(onFeed('Everyday dal'), findsOneWidget);
    expect(onFeed('No-knead bread'), findsOneWidget);
  });

  testWidgets('the demo banner survives filtering', (tester) async {
    await pumpFeed(tester);

    await search(tester, 'bread');

    expect(onFeed('Demo data · no Supabase project configured'),
        findsOneWidget);
  });
}
