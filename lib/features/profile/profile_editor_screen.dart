import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/recipe_repository.dart';
import '../recipes/recipe_providers.dart';

/// S6's other half: changing the profile the app shows you as.
///
/// What is editable is name, username and bio. What is not, and why:
///
/// - the **email**, because it lives on the `auth.users` row, not on `profiles`, and changing it
///   is a confirmation flow rather than a text field;
/// - the **avatar**, because there is no bucket for avatars — migration 005's is recipe images —
///   and a field that cannot be saved is worse than no field.
///
/// The limits below are the client's own: migration 001 declares `username TEXT UNIQUE NOT NULL`
/// and nothing else about these columns, so there is no `CHECK` to mirror and no second opinion
/// to give. They are recorded as inferences in `docs/handoff/RECONCILIATION.md`, and lengthening
/// one is a change here plus, if the handoff ever specifies them, a migration.
class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key, required this.initial});

  /// The profile as the screen below it is showing it. Editing is an act on a value a person can
  /// see; loading is the route's job (see [EditProfileScreen]).
  final Profile initial;

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  static const int _maxUsername = 30;
  static const int _maxDisplayName = 80;
  static const int _maxBio = 2000;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _bio;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(
      text: widget.initial.displayName ?? '',
    );
    _username = TextEditingController(text: widget.initial.username);
    _bio = TextEditingController(text: widget.initial.bio ?? '');
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final ProfileDraft draft = ProfileDraft(
      id: widget.initial.id,
      username: _username.text.trim(),
      displayName: _optional(_displayName.text),
      bio: _optional(_bio.text),
    );

    try {
      final Profile saved = await ref
          .read(recipeRepositoryProvider)
          .updateProfile(draft);

      // A profile is denormalised into every recipe read through the feed — `_withAuthors`
      // copies the author's name onto each row — so the lists showing the old name have to be
      // re-fetched, not only this page.
      ref.invalidate(profileByIdProvider(saved.id));
      ref.invalidate(feedProvider);
      ref.invalidate(myRecipesProvider(saved.id));

      if (!mounted) return;
      context.pop();
    } on ProfileUpdateFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = failure.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        bottom: demoBannerOrNull(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            if (_error != null) ...<Widget>[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    key: const Key('profile-edit-error'),
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const Key('profile-edit-display-name'),
              controller: _displayName,
              maxLength: _maxDisplayName,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: _validateDisplayName,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'Ana',
                helperText: 'Shown on your recipes. Blank falls back to your '
                    'username.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('profile-edit-username'),
              controller: _username,
              maxLength: _maxUsername,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: _validateUsername,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'ana_cooks',
                helperText: 'Unique, and shown next to your name.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('profile-edit-bio'),
              controller: _bio,
              maxLines: 4,
              maxLength: _maxBio,
              validator: _validateBio,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Cooks for four, most days.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('profile-edit-save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save profile'),
            ),
          ],
        ),
      ),
    );
  }

  /// The `maxLength` on each field stops a person typing past the limit; these validators catch
  /// anything that arrives another way. Both, because a form is not the only way a value reaches
  /// a field.
  String? _validateDisplayName(String? value) {
    final name = value?.trim() ?? '';
    // Blank is allowed: `display_name` is nullable and `Profile.name` falls back to the username.
    if (name.length > _maxDisplayName) {
      return 'Keep it under $_maxDisplayName characters';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'Choose a username';
    if (username.length > _maxUsername) {
      return 'Keep it under $_maxUsername characters';
    }
    return null;
  }

  String? _validateBio(String? value) {
    if ((value ?? '').trim().length > _maxBio) {
      return 'Keep it under $_maxBio characters';
    }
    return null;
  }

  /// Blank becomes null rather than an empty string, so the column means one thing: `''` and
  /// absent should not both exist, or `Profile.name` would have two falsey shapes to fall back on.
  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// `/profile/edit`: waits for the profile, then hands it to the editor.
///
/// The same three states every screen in this app has, plus the one this route adds: a profile
/// row that does not exist is not something to edit, so it says so instead of showing a form
/// that could not save.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      // Reachable only by pumping the screen directly: the router's guard sends a signed-out
      // visitor to sign-in before this builds.
      return Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: const CenteredMessage(
          icon: Icons.person_outline,
          title: 'Not signed in',
          message: 'There is no profile to edit without an account.',
        ),
      );
    }

    final AsyncValue<Profile?> profile = ref.watch(profileByIdProvider(userId));

    return profile.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: CenteredMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load your profile',
          message: '$error',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(profileByIdProvider(userId)),
            child: const Text('Try again'),
          ),
        ),
      ),
      data: (profile) => profile == null
          ? Scaffold(
              appBar: AppBar(title: const Text('Edit profile')),
              body: const CenteredMessage(
                icon: Icons.person_off_outlined,
                title: 'No profile row',
                message: 'The row that holds your name and bio does not exist, '
                    'so there is nothing to edit. The signup trigger normally '
                    'creates it.',
              ),
            )
          : ProfileEditorScreen(initial: profile),
    );
  }
}
