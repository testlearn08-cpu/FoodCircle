// The profile destination, and the path from it into the recipe box.
//
// Both are reached by tapping the shell, like a person would, rather than by constructing the
// screens directly — what is being tested is the wiring as much as the widgets.
//
// Every assertion is scoped to the screen it is about: the shell keeps the branches it has built,
// so text that appears on two of them would otherwise be matched twice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/app.dart';
import 'package:foodcircle/core/providers.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';
import 'package:foodcircle/data/repositories/recipe_repository.dart';
import 'package:foodcircle/features/profile/profile_screen.dart';
import 'package:foodcircle/features/recipes/my_recipes_screen.dart';

const Size kPhone = Size(430, 900);

Future<void> pumpAppAt(WidgetTester tester, RecipeRepository repository) async {
  tester.view.physicalSize = kPhone;
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

Future<void> tapDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the profile shows who you are and how much you have cooked',
      (tester) async {
    await pumpAppAt(tester, InMemoryRecipeRepository.seeded());

    await tapDestination(tester, 'Profile');
    expect(find.byType(ProfileScreen), findsOneWidget);

    Finder onProfile(String text) => find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.text(text),
        );

    expect(onProfile('Ana'), findsOneWidget);
    expect(onProfile('@ana_cooks'), findsOneWidget);
    expect(onProfile('Cooks for four, most days.'), findsOneWidget);
    // Demo data: two of the three seeded recipes are Ana's, one of them private — and a private
    // recipe still counts here, because its author can read it.
    expect(onProfile('2 recipes'), findsOneWidget);
  });

  testWidgets('the profile leads into the recipe box', (tester) async {
    await pumpAppAt(tester, InMemoryRecipeRepository.seeded());

    await tapDestination(tester, 'Profile');
    await tester.tap(find.descendant(
      of: find.byType(ProfileScreen),
      matching: find.text('My recipes'),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(MyRecipesScreen), findsOneWidget);

    Finder inBox(String text) => find.descendant(
          of: find.byType(MyRecipesScreen),
          matching: find.text(text),
        );

    expect(
      inBox('Leftover rice fritters'),
      findsOneWidget,
      reason: 'your own private recipes belong in your box',
    );
    expect(
      inBox('No-knead bread'),
      findsNothing,
      reason: "somebody else's recipe does not",
    );
  });

  testWidgets('with no account the profile says so instead of guessing',
      (tester) async {
    // No demo identity: this is what a configured build looks like before sign-in works.
    await pumpAppAt(tester, InMemoryRecipeRepository());

    await tapDestination(tester, 'Profile');
    expect(
      find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.text('Not signed in'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.text('@ana_cooks'),
      ),
      findsNothing,
    );

    await tapDestination(tester, 'Recipes');
    expect(find.byType(MyRecipesScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MyRecipesScreen),
        matching: find.text('Not signed in'),
      ),
      findsOneWidget,
    );
    // Nothing to add a recipe to, so no way to start one.
    expect(
      find.descendant(
        of: find.byType(MyRecipesScreen),
        matching: find.text('New recipe'),
      ),
      findsNothing,
    );
  });
}
