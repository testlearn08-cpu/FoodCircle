// The recipe editor: the screen that turns the app from something you read into something you
// write to.
//
// The widget test drives the real form through the real provider graph; the plain tests below it
// pin the parts that are easier to reason about away from the widget tree.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/data/models/recipe.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';
import 'package:foodcircle/data/repositories/recipe_repository.dart';
import 'package:foodcircle/features/recipes/recipe_detail_screen.dart';
import 'package:foodcircle/features/recipes/recipe_editor_screen.dart';
import 'package:foodcircle/features/recipes/my_recipes_screen.dart';

import 'support/demo_app.dart';

/// Tall enough to lay the whole form out, so tapping Save never depends on a scroll position.
const Size kTallPhone = Size(430, 2400);

Future<void> pumpEditor(
  WidgetTester tester,
  RecipeRepository repository,
) async {
  await pumpFoodCircleApp(tester, repository: repository, size: kTallPhone);

  // Feed -> recipe box -> editor, by tapping. The recipe box is the account's own destination,
  // so this also proves the router's guard lets a session through.
  await tester.tap(find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text('Recipes'),
  ));
  await tester.pumpAndSettle();
  expect(find.byType(MyRecipesScreen), findsOneWidget);

  await tester.tap(find.text('New recipe'));
  await tester.pumpAndSettle();
  expect(find.byType(RecipeEditorScreen), findsOneWidget);
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('a filled-in form creates a recipe and opens it', (tester) async {
    await pumpEditor(tester, InMemoryRecipeRepository.seeded());

    await tester.enterText(field('Title'), 'Khichuri');
    await tester.enterText(field('Servings'), '3');
    await tester.enterText(field('Cook minutes'), '25');
    await tester.enterText(field('Tags'), 'weeknight, rice');
    await tester.enterText(
      field('Ingredients'),
      '1 cup rice\n1 cup red lentils\n1 tsp turmeric',
    );
    await tester.enterText(field('Steps'), 'Rinse.\nSimmer until soft.');

    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();

    // The editor replaces itself with the recipe it just made.
    expect(find.byType(RecipeEditorScreen), findsNothing);
    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RecipeDetailScreen),
        matching: find.text('Khichuri'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(RecipeDetailScreen),
        matching: find.text('1 tsp turmeric'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(RecipeDetailScreen),
        matching: find.text('Simmer until soft.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the form refuses a recipe with no title', (tester) async {
    await pumpEditor(tester, InMemoryRecipeRepository.seeded());

    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();

    expect(find.text('Give the recipe a title'), findsOneWidget);
    // Still on the form: a validation failure must not navigate anywhere.
    expect(find.byType(RecipeEditorScreen), findsOneWidget);
    expect(find.byType(RecipeDetailScreen), findsNothing);
  });

  test('create() records the lists, the author and the visibility', () async {
    final repository = InMemoryRecipeRepository.seeded();

    final Recipe created = await repository.create(const RecipeDraft(
      authorId: 'demo-ana',
      title: 'Khichuri',
      ingredients: <String>['1 cup rice', '1 tsp turmeric'],
      steps: <String>['Rinse.', 'Simmer.'],
      isPublic: false,
    ));

    expect(created.ingredients, <String>['1 cup rice', '1 tsp turmeric']);
    expect(created.steps.length, 2);
    expect(created.isPublic, isFalse);
    // The author profile is looked up, the way the Supabase path loads authors separately.
    expect(created.author?.username, 'ana_cooks');
  });

  test('a created recipe is newest-first in the feed', () async {
    final repository = InMemoryRecipeRepository.seeded();

    await repository.create(const RecipeDraft(
      authorId: 'demo-ana',
      title: 'Khichuri',
    ));

    final List<Recipe> feed = await repository.fetchFeed();
    expect(feed.first.title, 'Khichuri');
    expect(feed.length, 4);
  });

  test('only the author can change a recipe', () async {
    final repository = InMemoryRecipeRepository.seeded();

    // demo-2 belongs to Dev; the acting user is Ana.
    await expectLater(
      repository.update(
        'demo-2',
        const RecipeDraft(authorId: 'demo-ana', title: 'Stolen bread'),
      ),
      throwsA(isA<StateError>()),
    );

    final Recipe? untouched = await repository.fetchById('demo-2');
    expect(untouched?.title, 'No-knead bread');
  });

  test('an edit keeps the image and the creation date a recipe already had',
      () async {
    final DateTime created = DateTime.utc(2026, 1, 1);
    final repository = InMemoryRecipeRepository(
      currentUserId: 'demo-ana',
      recipes: <Recipe>[
        Recipe(
          id: 'r1',
          authorId: 'demo-ana',
          title: 'Everyday dal',
          createdAt: created,
          imageUrl: 'https://example.test/dal.jpg',
        ),
      ],
    );

    final Recipe edited = await repository.update(
      'r1',
      const RecipeDraft(authorId: 'demo-ana', title: 'Everyday dal, again'),
    );

    expect(edited.title, 'Everyday dal, again');
    expect(edited.id, 'r1');
    expect(edited.createdAt, created);
    // The editor has no image field yet, so an edit must not silently drop one.
    expect(edited.imageUrl, 'https://example.test/dal.jpg');
  });
}
