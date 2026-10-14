import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/app.dart';
import 'package:foodcircle/core/providers.dart';
import 'package:foodcircle/data/repositories/in_memory_auth_repository.dart';
import 'package:foodcircle/features/auth/account_screen.dart';
import 'package:foodcircle/features/auth/sign_in_screen.dart';
import 'package:foodcircle/features/auth/sign_up_screen.dart';
import 'package:foodcircle/features/feed/feed_screen.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InMemoryAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const FoodCircleApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('auth-gated navigation', () {
    testWidgets('public feed remains available without signing in', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.byType(FeedScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('a protected destination returns to the sign-in page', (
      tester,
    ) async {
      await pumpApp(tester);
      await openProfile(tester);

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byKey(const Key('sign-in-email')), findsOneWidget);
    });

    testWidgets(
      'sign-up returns to the protected destination and sign-out works',
      (tester) async {
        await pumpApp(tester);
        await openProfile(tester);
        await tester.tap(find.byKey(const Key('sign-in-sign-up')));
        await tester.pumpAndSettle();

        expect(find.byType(SignUpScreen), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('sign-up-email')),
          'cook@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('sign-up-username')),
          'home_cook',
        );
        await tester.enterText(
          find.byKey(const Key('sign-up-password')),
          'demo-password',
        );
        await tester.enterText(
          find.byKey(const Key('sign-up-confirm-password')),
          'demo-password',
        );
        await tester.tap(find.byKey(const Key('sign-up-submit')));
        await tester.pumpAndSettle();

        expect(find.byType(AccountScreen), findsOneWidget);
        expect(find.text('cook@example.com'), findsOneWidget);

        await tester.tap(find.byKey(const Key('account-sign-out')));
        await tester.pumpAndSettle();

        expect(find.byType(FeedScreen), findsOneWidget);
        await openProfile(tester);
        expect(find.byType(SignInScreen), findsOneWidget);
      },
    );

    testWidgets('sign-in restores the protected destination', (tester) async {
      await pumpApp(tester);
      await openProfile(tester);

      await tester.enterText(
        find.byKey(const Key('sign-in-email')),
        'cook@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('sign-in-password')),
        'demo-password',
      );
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pumpAndSettle();

      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.text('cook@example.com'), findsOneWidget);
    });
  });
}
