import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/widgets/recipe_list.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/recipe.dart';
import 'recipe_providers.dart';

/// The "Recipes" destination: the acting user's own recipe box.
///
/// Deliberately not "all recipes" — that is what the feed is for. This is the private half:
/// `fetchMine` returns the author's rows whether they are public or not, so a recipe nobody else
/// can see still has somewhere to live, and gets a lock icon in the list to say so.
class MyRecipesScreen extends ConsumerWidget {
  const MyRecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? userId = ref.watch(currentUserIdProvider);
    final AsyncValue<List<Recipe>> mine = ref.watch(myRecipesProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My recipes'),
        bottom: demoBannerOrNull(),
      ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/recipes/new'),
              icon: const Icon(Icons.add),
              label: const Text('New recipe'),
            ),
      body: userId == null
          ? const CenteredMessage(
              icon: Icons.lock_outline,
              title: 'Not signed in',
              // No "sign-in is coming" here: UI text should describe the app, not the roadmap.
              message:
                  'Only you can see your own recipes, so this list needs an '
                  'account. Public recipes are readable without one.',
            )
          : RecipeAsyncList(
              recipes: mine,
              onTap: (recipe) => context.push('/recipes/${recipe.id}'),
              onRefresh: () => ref.refresh(myRecipesProvider(userId).future),
              onRetry: () => ref.invalidate(myRecipesProvider(userId)),
              emptyIcon: Icons.menu_book_outlined,
              emptyTitle: 'Your recipe box is empty',
              emptyMessage:
                  'Write down something you cooked — it takes a minute, '
                  'and it is the only way the feed fills up.',
              errorTitle: 'Could not load your recipes',
            ),
    );
  }
}
