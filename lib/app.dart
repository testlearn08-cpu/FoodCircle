import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'core/providers.dart';
import 'core/router/auth_router_refresh.dart';
import 'core/router/auth_routes.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/account_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/feed/feed_screen.dart';
import 'navigation/responsive_shell.dart';
import 'screens/placeholder_screen.dart';

/// Shared foundation for Android / iOS / Web.
///
/// Authentication uses the Supabase session when configured and an ephemeral in-memory demo
/// identity otherwise. The public feed remains reachable without either.
class FoodCircleApp extends ConsumerStatefulWidget {
  const FoodCircleApp({super.key});

  @override
  ConsumerState<FoodCircleApp> createState() => _FoodCircleAppState();
}

class _FoodCircleAppState extends ConsumerState<FoodCircleApp> {
  late final AuthRouterRefresh _authRouterRefresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authRepository = ref.read(authRepositoryProvider);
    _authRouterRefresh = AuthRouterRefresh(authRepository.userChanges);
    _router = _buildRouter(authRepository);
  }

  @override
  void dispose() {
    _router.dispose();
    _authRouterRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FoodCircle',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
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

  GoRouter _buildRouter(AuthRepository authRepository) {
    return GoRouter(
      initialLocation: kFeedPath,
      refreshListenable: _authRouterRefresh,
      redirect: (context, state) {
        final location = state.uri.path;
        final user = authRepository.currentUser;

        if (requiresAuthenticatedUser(location) && user == null) {
          return authRoute(kSignInPath, nextLocation: state.uri.toString());
        }

        final isAuthRoute = location == kSignInPath || location == kSignUpPath;
        if (isAuthRoute && user != null) {
          return safeNextLocation(state.uri.queryParameters['next']) ??
              kFeedPath;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: kSignInPath,
          builder: (context, state) => SignInScreen(
            nextLocation: safeNextLocation(state.uri.queryParameters['next']),
          ),
        ),
        GoRoute(
          path: kSignUpPath,
          builder: (context, state) => SignUpScreen(
            nextLocation: safeNextLocation(state.uri.queryParameters['next']),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              ResponsiveShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: kFeedPath,
                  builder: (context, state) => const FeedScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: kRecipesPath,
                  builder: (context, state) =>
                      const PlaceholderScreen(title: 'Recipes'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: kProfilePath,
                  builder: (context, state) => const AccountScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
