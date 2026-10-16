import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/auth_routes.dart';
import '../../core/widgets/initial_avatar.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/profile.dart';
import '../../data/models/recipe.dart';
import '../../data/repositories/auth_repository.dart';
import '../recipes/recipe_providers.dart';

/// S6 in the product spec, plus the account surface (S7's sign-out).
///
/// What is here: your identity (name, email, username, bio), a way to change the three fields
/// that are yours to change (`/profile/edit`), a way into your recipe box, and the way out —
/// signing out. What is still not: the avatar, because migration 005's bucket is recipe images
/// and there is no bucket for avatars. The screen says so rather than offering a field it cannot
/// save.
///
/// It absorbed the account screen that PR #5 added, rather than sitting next to it: one
/// destination called "Profile" showing your name and, two taps away, your email is a worse
/// screen than one that shows both. The sign-out key and the email text are unchanged, so the
/// expectations written against that screen still describe this one.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: demoBannerOrNull(),
        actions: <Widget>[
          // Enabled only with a session: without one there is no row to edit, and the router
          // would send the tap to sign-in anyway.
          IconButton(
            key: const Key('profile-edit'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
            onPressed: userId == null
                ? null
                : () => context.push('/profile/edit'),
          ),
        ],
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
    // The identity's own address, which comes from the session rather than from `profiles`:
    // the table deliberately has no email column, and the row has no business storing one.
    final String? email = ref.watch(authUserProvider).valueOrNull?.email;

    // The account card is the page's footer, not the last item in the list: signing out must
    // not depend on your profile row having loaded, or a profile that failed to load would be
    // an account you could not leave.
    return Column(
      children: <Widget>[
        Expanded(
          child: profile.when(
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
                    message:
                        'The row that holds your name and bio does not exist. '
                        'The signup trigger normally creates it.',
                  )
                : RefreshIndicator(
                    // Returning the refreshed future is what the indicator waits for;
                    // returning it rather than awaiting it also keeps the value out of a
                    // throwaway local.
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
                            subtitle: const Text(
                              'Public and private, newest first',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            // A different branch of the shell, so this switches the
                            // destination rather than pushing a screen on top.
                            onTap: () => context.go('/recipes'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AccountCard(email: email),
        ),
      ],
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

/// Your account, as the auth foundation models it: an email address and a way out.
///
/// Signing out returns to the feed rather than to the sign-in page: the feed is public, so it is
/// somewhere useful to land, and the router's guard will send you to sign in the moment you ask
/// for anything that needs a session.
class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String? address = email;

    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: Text(
              address ?? 'Signed in',
              key: const Key('account-email'),
              style: theme.textTheme.bodyLarge,
            ),
            subtitle: const Text('Your account'),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('account-sign-out'),
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!context.mounted) return;
      context.go(kFeedPath);
    } on AuthFailure catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign-out failed. Please try again.')),
      );
    }
  }
}
