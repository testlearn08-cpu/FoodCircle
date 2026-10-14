// Model parsing and the in-memory repository.
//
// The point of these is not coverage: it is that PostgREST rows are parsed forgivingly (a num
// where an int is expected, missing optional fields) while the repository contract the UI
// depends on — ordering, visibility, pagination — is pinned down somewhere that runs in
// milliseconds instead of needing a database.

import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/data/models/profile.dart';
import 'package:foodcircle/data/models/recipe.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';

void main() {
  group('Recipe.fromJson', () {
    test('parses a full PostgREST row', () {
      final recipe = Recipe.fromJson(const <String, dynamic>{
        'id': 'aaaaaaaa-0000-0000-0000-000000000001',
        'author_id': '11111111-1111-1111-1111-111111111111',
        'title': 'Everyday dal',
        'description': 'The one that gets made when nobody can decide.',
        'image_url': 'https://example.com/dal.jpg',
        'servings': 4,
        'prep_minutes': 10,
        'cook_minutes': 35,
        'difficulty': 'easy',
        'tags': <dynamic>['vegetarian', 'weeknight'],
        'ingredients': <dynamic>['1 cup red lentils', '1 tsp turmeric'],
        'steps': <dynamic>['Rinse.', 'Simmer.', 'Temper.'],
        'is_public': true,
        'created_at': '2026-10-14T09:31:00.000Z',
        'updated_at': '2026-10-14T09:31:00.000Z',
      });

      expect(recipe.title, 'Everyday dal');
      expect(recipe.servings, 4);
      expect(recipe.prepMinutes, 10);
      expect(recipe.cookMinutes, 35);
      expect(recipe.totalMinutes, 45);
      expect(recipe.tags, <String>['vegetarian', 'weeknight']);
      expect(recipe.ingredients.length, 2);
      expect(recipe.steps.length, 3);
      expect(recipe.createdAt.isUtc, isTrue);
      expect(recipe.isPublic, isTrue);
      expect(recipe.author, isNull);
    });

    test('tolerates the shapes PostgreSQL actually returns', () {
      final recipe = Recipe.fromJson(const <String, dynamic>{
        'id': '1',
        'author_id': '2',
        'title': 'Minimal',
        'created_at': '2026-10-14T09:31:00.000Z',
        // numeric arrives as a num, not always an int
        'servings': 2.0,
        // arrays arrive as List<dynamic>, and may be absent entirely
        'tags': <dynamic>[],
        'is_public': false,
      });

      expect(recipe.servings, 2);
      expect(recipe.tags, isEmpty);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.steps, isEmpty);
      expect(recipe.difficulty, isNull);
      expect(recipe.totalMinutes, isNull);
      expect(recipe.isPublic, isFalse);
    });
  });

  group('Profile', () {
    test('falls back to the username when there is no display name', () {
      const withName =
          Profile(id: '1', username: 'ana_cooks', displayName: 'Ana');
      const withoutName =
          Profile(id: '2', username: 'dev_bakes', displayName: '   ');
      const bare = Profile(id: '3', username: 'sam');

      expect(withName.name, 'Ana');
      expect(withoutName.name, 'dev_bakes');
      expect(bare.name, 'sam');
    });
  });

  group('InMemoryRecipeRepository', () {
    late InMemoryRecipeRepository repository;

    setUp(() {
      repository = InMemoryRecipeRepository.seeded();
    });

    test('the feed is newest first', () async {
      final feed = await repository.fetchFeed();

      expect(feed.length, greaterThanOrEqualTo(2));
      for (var i = 1; i < feed.length; i++) {
        expect(
          feed[i - 1].createdAt.isAfter(feed[i].createdAt),
          isTrue,
          reason: 'the feed must be ordered newest first',
        );
      }
    });

    test('a private recipe is visible to its author and nobody else', () async {
      final asAuthor = await InMemoryRecipeRepository.seeded().fetchFeed();
      expect(asAuthor.map((r) => r.title), contains('Leftover rice fritters'));

      final anonymous = InMemoryRecipeRepository(
        recipes: await repository.fetchMine('demo-ana'),
        profiles: const <Profile>[],
      );
      final visible = await anonymous.fetchFeed();
      expect(visible.map((r) => r.title),
          isNot(contains('Leftover rice fritters')));
    });

    test('fetchMine returns only that author, newest first', () async {
      final mine = await repository.fetchMine('demo-ana');

      expect(mine, isNotEmpty);
      expect(mine.every((r) => r.authorId == 'demo-ana'), isTrue);
      expect(mine.first.title, 'Everyday dal');
    });

    test('keyset pagination never repeats a recipe', () async {
      final firstPage = await repository.fetchFeed(limit: 1);
      final secondPage = await repository.fetchFeed(
          limit: 10, before: firstPage.single.createdAt);

      expect(firstPage.single.id, 'demo-1');
      expect(secondPage.map((r) => r.id), isNot(contains('demo-1')));
    });

    test('create refuses to write a recipe attributed to someone else',
        () async {
      await expectLater(
        repository.create(
          const RecipeDraft(authorId: 'demo-dev', title: 'Not mine'),
        ),
        throwsStateError,
      );
    });

    test('create then delete round-trips', () async {
      final created = await repository.create(
        const RecipeDraft(
          authorId: 'demo-ana',
          title: 'Fried eggs',
          tags: <String>['breakfast'],
        ),
      );

      expect(created.id, isNotEmpty);
      expect(created.author?.name, 'Ana');
      expect(await repository.fetchById(created.id), isNotNull);
      expect(
        (await repository.fetchFeed()).first.title,
        'Fried eggs',
        reason: 'a new recipe is the newest thing in the feed',
      );

      await repository.delete(created.id);
      expect(await repository.fetchById(created.id), isNull);
    });

    test(
        'fetchById on someone else\'s private recipe looks like it does not exist',
        () async {
      final anonymous = InMemoryRecipeRepository(
        recipes: await repository.fetchMine('demo-ana'),
      );

      expect(await anonymous.fetchById('demo-3'), isNull);
    });
  });
}
