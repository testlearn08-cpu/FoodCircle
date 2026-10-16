// The profile destination, and the path from it into the recipe box.
//
// Both are reached by tapping the shell, like a person would, rather than by constructing the
// screens directly — what is being tested is the wiring as much as the widgets.
//
// Every assertion is scoped to the screen it is about: the shell keeps the branches it has built,
// so text that appears on two of them would otherwise be matched twice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';
import 'package:foodcircle/data/repositories/recipe_repository.dart';
import 'package:foodcircle/features/auth/sign_in_screen.dart';
import 'package:foodcircle/features/feed/feed_screen.dart';
import 'package:foodcircle/features/profile/profile_screen.dart';
import 'package:foodcircle/features/recipes/my_recipes_screen.dart';

import 'support/demo_app.dart';

const Size kPhone = Size(430, 900);

Future<void> pumpAppAt(
  WidgetTester tester,
  RecipeRepository repository, {
  bool signedIn = true,
}) =>
    pumpFoodCircleApp(
      tester,
      repository: repository,
      size: kPhone,
      signedIn: signedIn,
    );

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

  testWidgets('with no account the profile destination asks you to sign in', (
    tester,
  ) async {
    // No session. `/profile` is the account's own destination, so the router sends you to
    // sign-in rather than guessing who you are; the feed is unaffected and stays public.
    await pumpAppAt(
      tester,
      InMemoryRecipeRepository(),
      signedIn: false,
    );

    expect(find.byType(FeedScreen), findsOneWidget);

    await tapDestination(tester, 'Profile');
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('with no account the recipe box asks you to sign in as well', (
    tester,
  ) async {
    await pumpAppAt(
      tester,
      InMemoryRecipeRepository(),
      signedIn: false,
    );

    await tapDestination(tester, 'Recipes');
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(MyRecipesScreen), findsNothing);
  });
}
