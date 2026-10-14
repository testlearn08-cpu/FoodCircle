// Authorization and navigation tests for FoodCircle.
//
// These RUN: CI executes `flutter test` on every push (see .github/workflows/ci.yml and
// docs/ANALYSIS_AND_ROADMAP.md). The earlier header claiming they had never been compiled
// was accurate when no Flutter SDK was available to the authoring environment and is not
// any more.
//
// Two deliberate fragilities to avoid:
//
//  1. Taps go through `find.descendant(of: <nav widget>, matching: find.text(...))`
//     rather than `find.byIcon`. Bottom navigation animates between `icon` and `activeIcon`,
//     so an icon finder can match more than one widget and `tester.tap` fails rather than
//     picking one.
//
//  2. There is no assertion that a previously visited destination is *gone* after
//     navigating away. `StatefulShellRoute.indexedStack` keeps visited branches in the
//     widget tree, and whether a finder skips the hidden ones depends on whether they are
//     wrapped in `Offstage` or in `Visibility.maintain` — the latter is not skipped.
//     Asserting absence here would be a coin flip; the meaningful behaviour (body swapped,
//     shell still mounted, index advanced) is asserted instead.

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

  /// A destination label inside the rail, ignoring identical body text.
  Finder railLabel(String label) => find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text(label),
      );

  /// A destination label inside the bottom bar, ignoring identical body text.
  Finder barLabel(String label) => find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(label),
      );

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
      expect(bar.currentIndex, 0);
    });

    testWidgets(
        'selecting a rail destination swaps the body but keeps the shell',
        (tester) async {
      await pumpAppAt(tester, const Size(1400, 900));
      expect(find.widgetWithText(PlaceholderScreen, 'Feed'), findsOneWidget);

      await tester.tap(railLabel('Recipes'));
      await tester.pumpAndSettle();

      // The Recipes branch is now built and showing.
      expect(find.widgetWithText(PlaceholderScreen, 'Recipes'), findsOneWidget);
      // ...and the shell survived the navigation, with the rail following along.
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        1,
      );
    });

    testWidgets('re-selecting the active destination is harmless',
        (tester) async {
      await pumpAppAt(tester, const Size(1400, 900));

      await tester.tap(railLabel('Feed'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(PlaceholderScreen, 'Feed'), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0,
      );
    });

    testWidgets('bottom navigation switches destination on mobile',
        (tester) async {
      await pumpAppAt(tester, const Size(400, 900));

      await tester.tap(barLabel('Profile'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(PlaceholderScreen, 'Profile'), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        2,
      );
      // Still no rail, i.e. the layout did not change under us.
      expect(find.byType(NavigationRail), findsNothing);
    });
  });
}
