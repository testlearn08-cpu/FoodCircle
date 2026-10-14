import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
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
        bottom: Env.isConfigured ? null : const _DemoModeBanner(),
      ),
      body: RefreshIndicator(
        // `ref.refresh(feedProvider.future)` returns the new value when it arrives, which is
        // exactly what RefreshIndicator waits for.
        onRefresh: () => ref.refresh(feedProvider.future),
        child: feed.when(
          data: (recipes) => recipes.isEmpty
              ? const _CenteredMessage(
                  icon: Icons.ramen_dining_outlined,
                  title: 'Nothing here yet',
                  message: 'Recipes shared publicly will show up here.',
                )
              : _RecipeList(recipes: recipes),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _CenteredMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load the feed',
            message: '$error',
            action: FilledButton.tonal(
              onPressed: () => ref.invalidate(feedProvider),
              child: const Text('Try again'),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: recipes.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => _RecipeTile(recipe: recipes[index]),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? imageUrl = recipe.imageUrl;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _Thumbnail(imageUrl: imageUrl),
      title: Text(
        recipe.title,
        style: theme.textTheme.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          _subtitleFor(recipe),
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing:
          recipe.isPublic ? null : const Icon(Icons.lock_outline, size: 18),
      onTap: () {
        // The detail screen is Phase 2; until then, say so rather than doing nothing.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${recipe.title} — detail screen is not built yet')),
        );
      },
    );
  }

  static String _subtitleFor(Recipe recipe) {
    final List<String> parts = <String>[
      if (recipe.author != null) recipe.author!.name,
      _relativeTime(recipe.createdAt),
      if (recipe.difficulty != null) recipe.difficulty!,
      if (recipe.totalMinutes != null) '${recipe.totalMinutes} min',
    ];
    return parts.join(' · ');
  }

  static String _relativeTime(DateTime when) {
    final Duration age = DateTime.now().difference(when);
    if (age.inMinutes < 1) return 'just now';
    if (age.inHours < 1) return '${age.inMinutes} min ago';
    if (age.inDays < 1) return '${age.inHours} h ago';
    if (age.inDays < 30) return '${age.inDays} d ago';
    final int months = age.inDays ~/ 30;
    return months == 1 ? '1 month ago' : '$months months ago';
  }
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
                child: Icon(Icons.restaurant_menu_outlined,
                    color: scheme.onSurfaceVariant),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant),
                ),
              ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Scrollable even when the content fits, so RefreshIndicator keeps working on an empty or
    // failed feed — otherwise the only way out of the error state is the retry button.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (action != null) ...<Widget>[
                    const SizedBox(height: 24),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Says plainly that this build is not connected to anything, because a demo that looks real is
/// worse than a demo that says it is a demo.
class _DemoModeBanner extends StatelessWidget implements PreferredSizeWidget {
  const _DemoModeBanner();

  @override
  Size get preferredSize => const Size.fromHeight(26);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      height: 26,
      width: double.infinity,
      color: scheme.tertiaryContainer,
      alignment: Alignment.center,
      child: Text(
        'Demo data · no Supabase project configured',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}
