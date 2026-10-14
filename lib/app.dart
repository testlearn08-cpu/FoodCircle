import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'features/feed/feed_screen.dart';
import 'navigation/responsive_shell.dart';
import 'screens/placeholder_screen.dart';

/// Shared foundation for Android / iOS / Web.
///
/// Status: Implemented (file). Unverified — no Flutter SDK in the authoring
/// environment, so this has never been compiled. See DEVELOPMENT_STATUS.md.
class FoodCircleApp extends StatefulWidget {
  const FoodCircleApp({super.key});

  @override
  State<FoodCircleApp> createState() => _FoodCircleAppState();
}

class _FoodCircleAppState extends State<FoodCircleApp> {
  /// Owned per app instance rather than as a static singleton, so that each
  /// `pumpWidget` in a widget test starts from a clean navigation state.
  late final GoRouter _router = _buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FoodCircle',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      routerConfig: _router,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: kMobileMaxWidth, name: MOBILE),
          Breakpoint(
            start: kMobileMaxWidth + 1,
            end: kDesktopMinWidth,
            name: TABLET,
          ),
          Breakpoint(start: kDesktopMinWidth + 1, end: 1920, name: DESKTOP),
        ],
      ),
    );
  }

  /// One branch per top-level destination.
  ///
  /// `StatefulShellRoute.indexedStack` keeps the shell (rail / bottom bar)
  /// mounted while the branch body changes, and gives each destination its own
  /// navigation stack. The previous revision nested plain placeholder routes
  /// under `/`, which replaced the entire shell with a bare placeholder as soon
  /// as a destination was selected.
  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/feed',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              ResponsiveShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/feed',
                  builder: (context, state) => const FeedScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/recipes',
                  builder: (context, state) =>
                      const PlaceholderScreen(title: 'Recipes'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) =>
                      const PlaceholderScreen(title: 'Profile'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
