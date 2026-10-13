/// Authorization and navigation tests for FoodCircle.
///
/// Status: Implemented (file). NOT EXECUTED — no Flutter SDK was available in
/// the authoring environment, so these tests have never been compiled or run.
/// See DEVELOPMENT_STATUS.md.
///
/// These replace the previous placeholders, which asserted `expect(true, isTrue)`
/// and therefore could not fail.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/app.dart';
import 'package:foodcircle/navigation/responsive_shell.dart';
import 'package:foodcircle/screens/placeholder_screen.dart';

void main() {
  /// Pumps the app at a given logical size.
  Future<void> pumpAppAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FoodCircleApp());
    await tester.pumpAndSettle();
  }

  group('FoodCircle application shell', () {
    testWidgets('builds and lands on the Feed destination', (tester) async {
      await pumpAppAt(tester, const Size(1400, 900));

      expect(find.byType(FoodCircleApp), findsOneWidget);
      expect(find.widgetWithText(PlaceholderScreen, 'Feed'), findsOneWidget);
    });

    testWidgets('desktop width renders an extended rail and no bottom bar',
        (tester) async {
      await pumpAppAt(tester, const Size(1400, 900));

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(rail.destinations.length, kNavigationDestinations.length);
      expect(rail.selectedIndex, 0);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('tablet width renders a compact rail', (tester) async {
      await pumpAppAt(tester, const Size(600, 900));

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('mobile width renders bottom navigation and no rail',
        (tester) async {
      await pumpAppAt(tester, const Size(400, 900));

      expect(find.byType(NavigationRail), findsNothing);
      final bar =
          tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(bar.items.length, kNavigationDestinations.length);
    });

    testWidgets('selecting a rail destination swaps the body but keeps the shell',
        (tester) async {
      await pumpAppAt(tester, const Size(1400, 900));
      expect(find.widgetWithText(PlaceholderScreen, 'Feed'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(PlaceholderScreen, 'Recipes'), findsOneWidget);
      expect(find.widgetWithText(PlaceholderScreen, 'Feed'), findsNothing);
      // The shell itself must survive the navigation.
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
        1,
      );
    });

    testWidgets('bottom navigation switches destination on mobile',
        (tester) async {
      await pumpAppAt(tester, const Size(400, 900));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(PlaceholderScreen, 'Profile'), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        2,
      );
    });
  });
}
