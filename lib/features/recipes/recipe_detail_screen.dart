import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/initial_avatar.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/profile.dart';
import '../../data/models/recipe.dart';
import 'recipe_providers.dart';

/// S3 in the product spec: everything needed to cook from someone else's recipe, and the two
/// actions an author has on their own.
///
/// Reached from both lists — `/feed/:id` and `/recipes/:id` — which is why it takes an id and
/// reads the recipe itself rather than being handed one: the list already has a copy, but a
/// refresh, a deep link and a browser reload all have to work too.
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Recipe?> recipe = ref.watch(recipeByIdProvider(recipeId));
    final String? currentUserId = ref.watch(currentUserIdProvider);
    final Recipe? loaded = recipe.valueOrNull;

    // The UI hides Delete for other people's recipes. That is a courtesy, not a boundary: the
    // database refuses the write through `recipes_delete_own` whatever the client shows.
    final bool isAuthor = loaded != null && loaded.authorId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.title ?? 'Recipe'),
        bottom: demoBannerOrNull(),
        actions: <Widget>[
          if (isAuthor)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete recipe',
              onPressed: () => _confirmDelete(context, ref, loaded),
            ),
        ],
      ),
      body: recipe.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => CenteredMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load this recipe',
          message: '$error',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(recipeByIdProvider(recipeId)),
            child: const Text('Try again'),
          ),
        ),
        // Null covers both "never existed" and "not yours to see". Saying which would leak the
        // existence of other people's private recipes, so the screen says neither.
        data: (recipe) => recipe == null
            ? const CenteredMessage(
                icon: Icons.help_outline,
                title: 'Recipe not available',
                message:
                    'It may have been deleted, or it is private to its author.',
              )
            : _Body(recipe: recipe),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this recipe?'),
        content: Text('“${recipe.title}” will be gone for everyone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(recipeRepositoryProvider).delete(recipe.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $error')),
      );
      return;
    }

    // The row is gone, so anything that listed it — or pointed at it — is stale. Named
    // individually rather than invalidating the whole family, because only these are affected.
    ref.invalidate(feedProvider);
    // The chips are derived from the feed, so a deleted recipe can remove a tag.
    ref.invalidate(feedTagsProvider);
    ref.invalidate(myRecipesProvider(recipe.authorId));
    ref.invalidate(recipeByIdProvider(recipe.id));

    if (!context.mounted) return;
    context.pop();
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? description = recipe.description?.trim();
    final Profile? author = recipe.author;
    final bool emptyLists = recipe.ingredients.isEmpty && recipe.steps.isEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        _Banner(imageUrl: recipe.imageUrl),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (description != null && description.isNotEmpty) ...<Widget>[
                Text(description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
              ],
              _MetaRow(recipe: recipe),
              if (author != null) ...<Widget>[
                const SizedBox(height: 16),
                _AuthorLine(author: author),
              ],
              if (recipe.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _Tags(tags: recipe.tags),
              ],
              if (recipe.ingredients.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                const _Section(title: 'Ingredients'),
                for (final ingredient in recipe.ingredients)
                  _Ingredient(text: ingredient),
              ],
              if (recipe.steps.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                const _Section(title: 'Steps'),
                for (final (index, step) in recipe.steps.indexed)
                  _Step(number: index + 1, text: step),
              ],
              if (emptyLists) ...<Widget>[
                const SizedBox(height: 24),
                Text(
                  'This recipe has no ingredients or steps yet.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The photo, or a placeholder when there is none — which is the common case until uploads
/// land with the storage policies in migration 005.
class _Banner extends StatelessWidget {
  const _Banner({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? url = imageUrl;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: url == null
          ? ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Icon(
                Icons.restaurant_menu_outlined,
                size: 56,
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
                  size: 56,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final int? servings = recipe.servings;
    final int? total = recipe.totalMinutes;
    final String? difficulty = recipe.difficulty;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (servings != null)
          _MetaChip(
            icon: Icons.people_outline,
            label: servings == 1 ? '1 serving' : '$servings servings',
          ),
        if (total != null)
          _MetaChip(icon: Icons.schedule_outlined, label: '$total min'),
        if (difficulty != null)
          _MetaChip(
            icon: Icons.local_fire_department_outlined,
            label: difficulty,
          ),
        if (!recipe.isPublic)
          // Marked here as well as in the list, because this is the screen where somebody might
          // assume a link to it works for anyone.
          const _MetaChip(icon: Icons.lock_outline, label: 'Private'),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.author});

  final Profile author;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = author.name;

    return Row(
      children: <Widget>[
        InitialAvatar(name: name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: theme.textTheme.titleSmall),
              Text(
                '@${author.username}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final tag in tags)
          Text(
            '#$tag',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Ingredient extends StatelessWidget {
  const _Ingredient({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Icon(
              Icons.circle,
              size: 6,
              color: theme.colorScheme.outline,
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              '$number.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
