import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/recipe_list.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/recipe.dart';

/// The public feed.
///
/// Reads [feedProvider] and nothing else, so it works identically against Supabase and against
/// the in-memory repository — which is what the web preview and the widget tests use.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Recipe>> feed = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodCircle'),
        bottom: demoBannerOrNull(),
      ),
      // Tapping used to explain that the detail screen was not built. It is built now, and it
      // lives in this branch, so the shell stays put: `/feed/:id`.
      body: RecipeAsyncList(
        recipes: feed,
        onTap: (recipe) => context.push('/feed/${recipe.id}'),
        onRefresh: () => ref.refresh(feedProvider.future),
        onRetry: () => ref.invalidate(feedProvider),
        emptyTitle: 'Nothing here yet',
        emptyMessage: 'Recipes shared publicly will show up here.',
        errorTitle: 'Could not load the feed',
      ),
    );
  }
}
