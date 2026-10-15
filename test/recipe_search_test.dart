// Search, against the in-memory repository.
//
// These pin the contract that supabase/migrations/006_recipe_search.sql implements in SQL: the
// two are required to agree, and the behavioural suite asserts the SQL half (checks 22-27) so a
// disagreement between them fails CI rather than showing up as a user-visible difference between
// the demo build and a connected one.

import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/data/models/recipe.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';

List<String> titles(List<Recipe> recipes) =>
    [for (final Recipe recipe in recipes) recipe.title];

void main() {
  // Seeded demo data, and who owns what:
  //   Everyday dal            Ana, public,  ingredients include "1 cup red lentils", tags:
  //                           vegetarian, weeknight
  //   No-knead bread          Dev, public,  "400 g bread flour", tags: baking
  //   Leftover rice fritters  Ana, PRIVATE, "2 cups cooked rice", no tags
  // The acting user is Ana.

  test('matches the title, case-insensitively', () async {
    final repository = InMemoryRecipeRepository.seeded();

    expect(titles(await repository.fetchFeed(query: 'bread')),
        <String>['No-knead bread']);
    expect(titles(await repository.fetchFeed(query: 'BREAD')),
        <String>['No-knead bread']);
  });

  test('matches inside the ingredient list, not just the title', () async {
    final repository = InMemoryRecipeRepository.seeded();

    // The point of the whole feature: "lentils" appears in Everyday dal's ingredients and
    // nowhere in its title.
    expect(titles(await repository.fetchFeed(query: 'lentils')),
        <String>['Everyday dal']);
    expect(titles(await repository.fetchFeed(query: 'ghee')),
        <String>['Everyday dal']);
    // A substring, not a whole word.
    expect(titles(await repository.fetchFeed(query: 'lentil')),
        <String>['Everyday dal']);
  });

  test('a blank query is no filter at all', () async {
    final repository = InMemoryRecipeRepository.seeded();

    expect((await repository.fetchFeed(query: '   ')).length, 3);
    expect((await repository.fetchFeed(query: '')).length, 3);
    expect((await repository.fetchFeed()).length, 3);
  });

  test('filters by tag, exactly', () async {
    final repository = InMemoryRecipeRepository.seeded();

    expect(titles(await repository.fetchFeed(tag: 'baking')),
        <String>['No-knead bread']);
    expect(titles(await repository.fetchFeed(tag: 'weeknight')),
        <String>['Everyday dal']);
    // Not a substring match, and not case-insensitive: a tag is an identifier.
    expect(await repository.fetchFeed(tag: 'bak'), isEmpty);
    expect(await repository.fetchFeed(tag: 'BAKING'), isEmpty);
    expect(await repository.fetchFeed(tag: 'nothing-has-this'), isEmpty);
  });

  test('a query and a tag narrow together', () async {
    final repository = InMemoryRecipeRepository.seeded();

    expect((await repository.fetchFeed(query: 'lentil', tag: 'weeknight'))
        .length, 1);
    // Both conditions have to hold: the dal matches the text but not the tag.
    expect(await repository.fetchFeed(query: 'lentil', tag: 'baking'), isEmpty);
  });

  test('search cannot see past the visibility rule', () async {
    final repository = InMemoryRecipeRepository.seeded();

    // Ana owns the private "Leftover rice fritters", so she finds it.
    expect(titles(await repository.fetchFeed(query: 'rice')),
        <String>['Leftover rice fritters']);

    // The same query as a signed-out client finds nothing at all: the only match is private.
    final anonymous = InMemoryRecipeRepository(
      recipes: await repository.fetchFeed(limit: 50),
    );
    expect(await anonymous.fetchFeed(query: 'rice'), isEmpty);

    // ...and the public half is still reachable without an account.
    expect(titles(await anonymous.fetchFeed(query: 'lentils')),
        <String>['Everyday dal']);
  });

  test('% and _ are literal text, not wildcards', () async {
    final repository = InMemoryRecipeRepository(
      recipes: <Recipe>[
        Recipe(
          id: 'r1',
          authorId: 'demo-ana',
          title: 'Discount day',
          createdAt: DateTime.utc(2026, 1, 2),
          ingredients: const <String>['50% off mince'],
        ),
        Recipe(
          id: 'r2',
          authorId: 'demo-ana',
          title: 'Weeknight dal',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );

    expect(titles(await repository.fetchFeed(query: '50%')),
        <String>['Discount day']);
    // A bare wildcard would match everything; escaped, it matches nothing.
    expect(await repository.fetchFeed(query: '%'), isEmpty);
    expect(await repository.fetchFeed(query: '_'), isEmpty);
  });

  test('before paginates a search the way it paginates the feed', () async {
    final repository = InMemoryRecipeRepository.seeded();

    final List<Recipe> all = await repository.fetchFeed();
    final DateTime oldest = all.last.createdAt;

    final List<Recipe> older = await repository.fetchFeed(
      query: 'e',
      before: oldest,
    );
    expect(older.length, lessThan(all.length));
    expect(older.every((recipe) => recipe.createdAt.isBefore(oldest)), isTrue);
  });

  test('limit is honoured, and results stay newest-first', () async {
    final repository = InMemoryRecipeRepository.seeded();

    final List<Recipe> one = await repository.fetchFeed(query: 'e', limit: 1);
    expect(one.length, 1);
    expect(one.single.title, 'Everyday dal');

    final List<Recipe> many = await repository.fetchFeed(query: 'e', limit: 50);
    expect(many.length, 3);
    for (int i = 1; i < many.length; i++) {
      expect(
        many[i - 1].createdAt.isAfter(many[i].createdAt),
        isTrue,
        reason: 'the feed is newest-first, filtered or not',
      );
    }
  });

  test('the tag chips cover every tag in the feed, without duplicates', () async {
    final repository = InMemoryRecipeRepository.seeded();

    final Set<String> tags = <String>{
      for (final Recipe recipe in await repository.fetchFeed(limit: 50))
        ...recipe.tags,
    };

    expect(tags, <String>{'vegetarian', 'weeknight', 'baking'});
  });
}
