import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/router/auth_router_refresh.dart';
import 'core/router/auth_routes.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/recipes/my_recipes_screen.dart';
import 'features/recipes/recipe_detail_screen.dart';
import 'features/recipes/recipe_editor_screen.dart';
import 'navigation/responsive_shell.dart';

/// Shared foundation for Android / iOS / Web.
///
/// Authentication uses the Supabase session when configured and an ephemeral in-memory demo
/// identity otherwise. The public feed remains reachable without either.
///
/// Three destinations, each with its own stack: the feed (public recipes), the recipe box
/// (yours, private ones included) and your profile. A recipe's page hangs off both lists, so
/// opening one keeps you in the destination you opened it from.
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
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }

  /// One branch per top-level destination.
  ///
  /// `StatefulShellRoute.indexedStack` keeps the shell (rail / bottom bar) mounted while the
  /// branch body changes, and gives each destination its own navigation stack.
  ///
  /// `responsive_framework` used to wrap this route's builder with a breakpoint list. It was
  /// decorative — nothing read it; `ResponsiveShell` measures `MediaQuery` itself — and wrong:
  /// the desktop band ended at 1920 logical pixels, so a 2560px monitor fell outside every
  /// breakpoint it declared. The shell's own two constants are the single source of truth now.
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
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => RecipeDetailScreen(
                        recipeId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: kRecipesPath,
                  builder: (context, state) => const MyRecipesScreen(),
                  routes: [
                    // `new` is declared before `:id` so the static segment wins: otherwise
                    // `/recipes/new` would match the detail route with id "new".
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => const RecipeEditorScreen(),
                    ),
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => RecipeDetailScreen(
                        recipeId: state.pathParameters['id']!,
                      ),
                      routes: [
                        GoRoute(
                          path: 'edit',
                          builder: (context, state) => EditRecipeScreen(
                            recipeId: state.pathParameters['id']!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: kProfilePath,
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
