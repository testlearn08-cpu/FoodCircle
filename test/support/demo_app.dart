// The two overrides every screen test needs: which repository the app reads, and who it is
// acting as.
//
// A session is not decoration. `/recipes` and `/profile` redirect to sign-in without one, and the
// author-only affordances — delete, edit, "New recipe" — are rendered from the acting identity,
// so a test that wants the app as Ana has to sign in as Ana. `InMemoryAuthRepository` is the same
// ephemeral fake the demo build uses, which means these tests exercise the real router guard
// rather than a stubbed one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/app.dart';
import 'package:foodcircle/core/providers.dart';
import 'package:foodcircle/data/models/auth_user.dart';
import 'package:foodcircle/data/repositories/in_memory_auth_repository.dart';
import 'package:foodcircle/data/repositories/recipe_repository.dart';

/// Pumps the real app against [repository], signed in as the demo author by default.
///
/// Pass `signedIn: false` for the signed-out app: the feed stays public, and the account
/// destinations send you to sign-in.
Future<void> pumpFoodCircleApp(
  WidgetTester tester, {
  required RecipeRepository repository,
  Size size = const Size(430, 900),
  bool signedIn = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // The same id the seeded demo repository treats as the acting user, so "signed in" means the
  // author of the recipes the fixtures already contain rather than a stranger with no data.
  final InMemoryAuthRepository auth = InMemoryAuthRepository(
    initialUser: signedIn
        ? const AuthUser(
            id: InMemoryAuthRepository.demoUserId,
            email: 'demo@example.com',
          )
        : null,
  );
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        recipeRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: const FoodCircleApp(),
    ),
  );
  await tester.pumpAndSettle();
}
