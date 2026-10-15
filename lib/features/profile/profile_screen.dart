import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/widgets/initial_avatar.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/profile.dart';
import '../../data/models/recipe.dart';
import '../recipes/recipe_providers.dart';

/// S6 in the product spec, reading half of it.
///
/// What is here: your identity (name, username, bio) and a way into your recipe box. What is not,
/// yet: editing any of it, and the avatar upload that goes with it — `profiles_update_own` is in
/// place and `Profile.toUpdateJson` exists, but a form that cannot be saved is worse than no form.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: demoBannerOrNull(),
      ),
      body: userId == null
          ? const CenteredMessage(
              icon: Icons.person_outline,
              title: 'Not signed in',
              message: 'Public recipes are readable without an account. '
                  'A profile is not.',
            )
          : _ProfileBody(userId: userId),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile?> profile = ref.watch(profileByIdProvider(userId));
    final AsyncValue<List<Recipe>> recipes =
        ref.watch(myRecipesProvider(userId));

    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => CenteredMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load your profile',
        message: '$error',
        action: FilledButton.tonal(
          onPressed: () => ref.invalidate(profileByIdProvider(userId)),
          child: const Text('Try again'),
        ),
      ),
      data: (profile) => profile == null
          ? const CenteredMessage(
              icon: Icons.person_off_outlined,
              title: 'No profile row',
              message: 'The row that holds your name and bio does not exist. '
                  'The signup trigger normally creates it.',
            )
          : RefreshIndicator(
              // Returning the refreshed future is what the indicator waits for; returning it
              // rather than awaiting it also keeps the value out of a throwaway local.
              onRefresh: () {
                ref.invalidate(profileByIdProvider(userId));
                return ref.refresh(myRecipesProvider(userId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _Header(profile: profile),
                  const SizedBox(height: 24),
                  _RecipeCount(
                    count: recipes.valueOrNull?.length,
                    isLoading: recipes.isLoading,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('My recipes'),
                      subtitle: const Text('Public and private, newest first'),
                      trailing: const Icon(Icons.chevron_right),
                      // A different branch of the shell, so this switches the destination
                      // rather than pushing a screen on top of this one.
                      onTap: () => context.go('/recipes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? bio = profile.bio?.trim();

    return Column(
      children: <Widget>[
        InitialAvatar(name: profile.name, radius: 36),
        const SizedBox(height: 16),
        Text(profile.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '@${profile.username}',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (bio != null && bio.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(bio, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _RecipeCount extends StatelessWidget {
  const _RecipeCount({required this.count, required this.isLoading});

  final int? count;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String value = count == null
        ? (isLoading ? '…' : '—')
        : (count == 1 ? '1 recipe' : '$count recipes');

    return Center(
      child: Text(
        value,
        style: theme.textTheme.titleMedium
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
