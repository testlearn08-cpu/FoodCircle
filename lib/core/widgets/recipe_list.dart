import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/recipe.dart';
import 'state_views.dart';

/// A list of recipes with the three states the product spec asks of every list: loading, empty
/// (with a message that says what would fill it), and error (with a retry that really retries).
///
/// One widget rather than one per screen, so the feed and "my recipes" cannot drift into
/// behaving differently when the backend is slow or absent.
class RecipeAsyncList extends StatelessWidget {
  const RecipeAsyncList({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRetry,
    this.emptyIcon = Icons.ramen_dining_outlined,
    this.errorTitle = 'Could not load recipes',
  });

  final AsyncValue<List<Recipe>> recipes;
  final void Function(Recipe recipe) onTap;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String errorTitle;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: recipes.when(
        data: (list) => list.isEmpty
            ? CenteredMessage(
                icon: emptyIcon,
                title: emptyTitle,
                message: emptyMessage,
              )
            : _RecipeList(recipes: list, onTap: onTap),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => CenteredMessage(
          icon: Icons.cloud_off_outlined,
          title: errorTitle,
          message: '$error',
          action: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({required this.recipes, required this.onTap});

  final List<Recipe> recipes;
  final void Function(Recipe recipe) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: recipes.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final Recipe recipe = recipes[index];
        return RecipeTile(recipe: recipe, onTap: () => onTap(recipe));
      },
    );
  }
}

/// One recipe in a list: a thumbnail, a title, and the one line of metadata that fits.
///
/// Shared by the feed and by "my recipes", which is also what makes the tap target — the thing
/// that turns a list into a product — defined exactly once.
class RecipeTile extends StatelessWidget {
  const RecipeTile({super.key, required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _Thumbnail(imageUrl: recipe.imageUrl),
      title: Text(
        recipe.title,
        style: theme.textTheme.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          recipeSubtitle(recipe),
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing:
          recipe.isPublic ? null : const Icon(Icons.lock_outline, size: 18),
      onTap: onTap,
    );
  }
}

/// The single line under a recipe title: who cooked it, when, and the two facts people filter
/// on when they are deciding what to make tonight.
String recipeSubtitle(Recipe recipe) {
  final List<String> parts = <String>[
    if (recipe.author != null) recipe.author!.name,
    relativeTime(recipe.createdAt),
    if (recipe.difficulty != null) recipe.difficulty!,
    if (recipe.totalMinutes != null) '${recipe.totalMinutes} min',
  ];
  return parts.join(' · ');
}

/// "3 h ago" rather than a timestamp, because a feed is read at a glance.
String relativeTime(DateTime when) {
  final Duration age = DateTime.now().difference(when);
  if (age.inMinutes < 1) return 'just now';
  if (age.inHours < 1) return '${age.inMinutes} min ago';
  if (age.inDays < 1) return '${age.inHours} h ago';
  if (age.inDays < 30) return '${age.inDays} d ago';
  final int months = age.inDays ~/ 30;
  return months == 1 ? '1 month ago' : '$months months ago';
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String? imageUrl;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? url = imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _size,
        height: _size,
        child: url == null
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.restaurant_menu_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}
