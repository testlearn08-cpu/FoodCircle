import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/feed/feed_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/recipes/my_recipes_screen.dart';
import 'features/recipes/recipe_detail_screen.dart';
import 'features/recipes/recipe_editor_screen.dart';
import 'navigation/responsive_shell.dart';

/// Shared foundation for Android / iOS / Web.
///
/// Three destinations, each with its own stack: the feed (public recipes), the recipe box
/// (yours, private ones included) and the profile. A recipe's page hangs off both lists, so
/// opening one keeps you in the destination you opened it from.
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
    );
  }

  /// One branch per top-level destination.
  ///
  /// `StatefulShellRoute.indexedStack` keeps the shell (rail / bottom bar) mounted while the
  /// branch body changes, and gives each destination its own navigation stack. The previous
  /// revision nested plain placeholder routes under `/`, which replaced the entire shell with a
  /// bare placeholder as soon as a destination was selected.
  ///
  /// `responsive_framework` used to wrap this route's builder with a breakpoint list. It was
  /// decorative — nothing read it; `ResponsiveShell` measures `MediaQuery` itself — and wrong:
  /// the desktop band ended at 1920 logical pixels, so a 2560px monitor fell outside every
  /// breakpoint it declared. The shell's own two constants are the single source of truth now.
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
                  path: '/recipes',
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
                  path: '/profile',
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
