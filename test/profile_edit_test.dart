// Editing your profile: the screen, the write behind it, and the refusals in between.
//
// The flow tests drive the real app — a profile is reached by tapping the shell, the editor by
// tapping the action in its app bar — because what is being tested is the wiring as much as the
// form. Every assertion is scoped to the screen it is about: the shell keeps the branch below a
// pushed route in the tree, so the profile's own header is still there to be matched twice.
//
// The repository tests at the bottom pin what the screen cannot show: that a write keeps the
// avatar it has no field for, and that somebody else's row is refused rather than edited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/data/models/profile.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';
import 'package:foodcircle/data/repositories/recipe_repository.dart';
import 'package:foodcircle/features/profile/profile_editor_screen.dart';
import 'package:foodcircle/features/profile/profile_screen.dart';

import 'support/demo_app.dart';

/// Tall enough that the whole form, its helper texts and its counters are laid out: tapping Save
/// should not depend on a scroll position.
const Size kTallPhone = Size(430, 1200);

Finder inEditor(String text) => find.descendant(
      of: find.byType(ProfileEditorScreen),
      matching: find.text(text),
    );

Finder inProfile(String text) => find.descendant(
      of: find.byType(ProfileScreen),
      matching: find.text(text),
    );

String fieldText(WidgetTester tester, String key) {
  final TextFormField field = tester.widget<TextFormField>(
    find.byKey(Key(key)),
  );
  return field.controller?.text ?? '';
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('profile-edit-save')));
  await tester.pumpAndSettle();
}

/// Profile destination -> the edit action in its app bar.
Future<void> openEditor(
  WidgetTester tester, {
  RecipeRepository? repository,
}) async {
  await pumpFoodCircleApp(
    tester,
    repository: repository ?? InMemoryRecipeRepository.seeded(),
    size: kTallPhone,
  );

  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Profile'),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(ProfileScreen), findsOneWidget);

  await tester.tap(find.byKey(const Key('profile-edit')));
  await tester.pumpAndSettle();
  expect(find.byType(ProfileEditorScreen), findsOneWidget);
}

void main() {
  group('the editor', () {
    testWidgets('opens with what the profile already says', (tester) async {
      await openEditor(tester);

      // Read through the controllers rather than by matching text: an empty field renders its
      // hint, and these hints are the values a demo profile happens to have, so `find.text`
      // matches twice. The controller is also the thing that gets saved.
      expect(fieldText(tester, 'profile-edit-display-name'), 'Ana');
      expect(fieldText(tester, 'profile-edit-username'), 'ana_cooks');
      expect(
        fieldText(tester, 'profile-edit-bio'),
        'Cooks for four, most days.',
      );
    });

    testWidgets('saving takes you back to the profile it changed', (
      tester,
    ) async {
      final repository = InMemoryRecipeRepository.seeded();
      await openEditor(tester, repository: repository);

      await enter(tester, 'profile-edit-display-name', 'Ana Rao');
      await enter(tester, 'profile-edit-bio', 'Cooks for six now.');
      await save(tester);

      expect(find.byType(ProfileEditorScreen), findsNothing);
      expect(inProfile('Ana Rao'), findsOneWidget);
      expect(inProfile('Cooks for six now.'), findsOneWidget);
      // The count is the same screen's other half, and it still knows about the private recipe.
      expect(inProfile('2 recipes'), findsOneWidget);

      // The write landed, rather than only the widget tree having been rebuilt.
      final Profile? saved = await repository.fetchProfile('demo-ana');
      expect(saved?.displayName, 'Ana Rao');
      expect(saved?.bio, 'Cooks for six now.');
      expect(saved?.username, 'ana_cooks');
    });

    testWidgets('clearing a field clears it rather than storing blank text', (
      tester,
    ) async {
      final repository = InMemoryRecipeRepository.seeded();
      await openEditor(tester, repository: repository);

      await enter(tester, 'profile-edit-display-name', '   ');
      await enter(tester, 'profile-edit-bio', '');
      await save(tester);

      final Profile? saved = await repository.fetchProfile('demo-ana');
      expect(saved?.displayName, isNull);
      expect(saved?.bio, isNull);
      // With no display name the profile falls back to the username, which is the point of
      // allowing a blank one.
      expect(inProfile('@ana_cooks'), findsOneWidget);
    });

    testWidgets('a username somebody else has is refused, in words', (
      tester,
    ) async {
      final repository = InMemoryRecipeRepository.seeded();
      await openEditor(tester, repository: repository);

      // Seeded demo data: `dev_bakes` is Dev's.
      await enter(tester, 'profile-edit-username', 'dev_bakes');
      await save(tester);

      expect(find.byType(ProfileEditorScreen), findsOneWidget);
      expect(inEditor('That username is taken.'), findsOneWidget);

      final Profile? unchanged = await repository.fetchProfile('demo-ana');
      expect(unchanged?.username, 'ana_cooks');
      // The other row is untouched too: a refused write changes nothing at all.
      final Profile? other = await repository.fetchProfile('demo-dev');
      expect(other?.username, 'dev_bakes');
    });

    testWidgets('an empty username is refused before anything is sent', (
      tester,
    ) async {
      final repository = InMemoryRecipeRepository.seeded();
      await openEditor(tester, repository: repository);

      await enter(tester, 'profile-edit-username', '   ');
      await save(tester);

      expect(inEditor('Choose a username'), findsOneWidget);
      expect(find.byType(ProfileEditorScreen), findsOneWidget);
      final Profile? unchanged = await repository.fetchProfile('demo-ana');
      expect(unchanged?.username, 'ana_cooks');
    });

    testWidgets('the fields stop at the lengths the editor declares', (
      tester,
    ) async {
      await openEditor(tester);

      await enter(tester, 'profile-edit-display-name', 'n' * 100);
      await enter(tester, 'profile-edit-username', 'u' * 100);
      await enter(tester, 'profile-edit-bio', 'b' * 2200);

      expect(fieldText(tester, 'profile-edit-display-name').length, 80);
      expect(fieldText(tester, 'profile-edit-username').length, 30);
      expect(fieldText(tester, 'profile-edit-bio').length, 2000);
    });

    testWidgets('without a session there is nothing to edit, and it says so', (
      tester,
    ) async {
      // The router's guard means this screen is not reachable signed out; pumping it directly is
      // what a wrong route or a future regression would look like.
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: EditProfileScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not signed in'), findsOneWidget);
      expect(find.byType(ProfileEditorScreen), findsNothing);
    });
  });

  group('the write behind the editor', () {
    testWidgets('the profile destination offers the way in', (tester) async {
      await pumpFoodCircleApp(
        tester,
        repository: InMemoryRecipeRepository.seeded(),
        size: kTallPhone,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Profile'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-edit')), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byKey(const Key('profile-edit')))
            .onPressed,
        isNotNull,
      );
    });

    test('keeps the avatar a row already has', () async {
      final repository = InMemoryRecipeRepository(
        currentUserId: 'demo-ana',
        profiles: const [
          Profile(
            id: 'demo-ana',
            username: 'ana_cooks',
            displayName: 'Ana',
            avatarUrl: 'https://example.test/ana.png',
          ),
        ],
      );

      final Profile updated = await repository.updateProfile(
        const ProfileDraft(
          id: 'demo-ana',
          username: 'ana_rao',
          displayName: 'Ana Rao',
          bio: 'Cooks for six now.',
        ),
      );

      expect(updated.username, 'ana_rao');
      expect(updated.displayName, 'Ana Rao');
      expect(
        updated.avatarUrl,
        'https://example.test/ana.png',
        reason: 'the editor has no avatar field, so a save must not drop one',
      );
      expect((await repository.fetchProfile('demo-ana'))?.avatarUrl,
          'https://example.test/ana.png');
    });

    test('refuses to write a profile that is not yours', () async {
      final repository = InMemoryRecipeRepository.seeded();

      await expectLater(
        repository.updateProfile(
          const ProfileDraft(id: 'demo-dev', username: 'not_dev'),
        ),
        throwsA(isA<StateError>()),
      );
      final Profile? other = await repository.fetchProfile('demo-dev');
      expect(other?.username, 'dev_bakes');
    });

    test('refuses a taken username with a message, not a crash', () async {
      final repository = InMemoryRecipeRepository.seeded();

      await expectLater(
        repository.updateProfile(
          const ProfileDraft(id: 'demo-ana', username: 'dev_bakes'),
        ),
        throwsA(
          isA<ProfileUpdateFailure>().having(
            (failure) => failure.message,
            'message',
            'That username is taken.',
          ),
        ),
      );
    });

    test('the update payload carries no avatar', () {
      const draft = ProfileDraft(
        id: 'demo-ana',
        username: 'ana_cooks',
        displayName: 'Ana',
        bio: 'Cooks for four, most days.',
      );

      expect(draft.toUpdateJson().keys, <String>[
        'username',
        'display_name',
        'bio',
      ]);
    });
  });
}
