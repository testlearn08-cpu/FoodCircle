import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:go_router/go_router.dart';
import 'navigation/responsive_shell.dart';

/// Shared foundation for Android / iOS / Web.
/// Status: Implemented (file). Demo (unverified compilation — no Flutter SDK).
class FoodCircleApp extends StatelessWidget {
  const FoodCircleApp({super.key});

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
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
      ),
    );
  }

  /// Navigation scaffold — responsive nav shell.
  /// Status: Demo / Unverified (navigation routes not validated without SDK).
  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ResponsiveShell(),
        routes: [
          GoRoute(path: 'feed', builder: (_, __) => const _Placeholder('Feed')),
          GoRoute(path: 'profile', builder: (_, __) => const _Placeholder('Profile')),
          GoRoute(path: 'recipes', builder: (_, __) => const _Placeholder('Recipes')),
        ],
      ),
    ],
  );
}

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder(this.label);
  @override
  Widget build(BuildContext context) => Center(child: Text(label, style: Theme.of(context).textTheme.headlineMedium));
}
