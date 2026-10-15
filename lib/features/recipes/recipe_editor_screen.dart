import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/recipe.dart';
import '../../data/repositories/recipe_repository.dart';
import 'recipe_providers.dart';

/// S4 in the product spec: one screen for creating and for editing.
///
/// The validation here mirrors the `CHECK` constraints in `supabase/migrations/004_...sql` —
/// a title of 1–120 characters, servings 1–100, times 0–1440 minutes, at most ten tags. That is
/// for the person typing, not for safety: the database refuses the same rows whatever the client
/// claims, and the client is assumed hostile.
///
/// There is no image field yet. Uploads need the storage bucket and its policies from migration
/// 005, which is a separate piece of work, so a recipe's photo is whatever the row already has.
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.initial});

  /// The recipe being edited, or null when this is a new one.
  final Recipe? initial;

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  static const List<String?> _difficulties = <String?>[
    null,
    'easy',
    'medium',
    'hard',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _servings;
  late final TextEditingController _prep;
  late final TextEditingController _cook;
  late final TextEditingController _tags;
  late final TextEditingController _ingredients;
  late final TextEditingController _steps;

  late String? _difficulty;
  late bool _isPublic;

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final Recipe? initial = widget.initial;

    _title = TextEditingController(text: initial?.title ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _servings = TextEditingController(text: _numberText(initial?.servings));
    _prep = TextEditingController(text: _numberText(initial?.prepMinutes));
    _cook = TextEditingController(text: _numberText(initial?.cookMinutes));
    _tags = TextEditingController(text: initial?.tags.join(', ') ?? '');
    _ingredients =
        TextEditingController(text: initial?.ingredients.join('\n') ?? '');
    _steps = TextEditingController(text: initial?.steps.join('\n') ?? '');
    _difficulty = initial?.difficulty;
    _isPublic = initial?.isPublic ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _servings.dispose();
    _prep.dispose();
    _cook.dispose();
    _tags.dispose();
    _ingredients.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final String? userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _error = 'Saving needs an account.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final RecipeDraft draft = RecipeDraft(
      authorId: userId,
      title: _title.text.trim(),
      description: _optional(_description.text),
      servings: int.tryParse(_servings.text.trim()),
      prepMinutes: int.tryParse(_prep.text.trim()),
      cookMinutes: int.tryParse(_cook.text.trim()),
      difficulty: _difficulty,
      tags: _commaSeparated(_tags.text),
      ingredients: _lines(_ingredients.text),
      steps: _lines(_steps.text),
      isPublic: _isPublic,
    );

    final Recipe? existing = widget.initial;

    try {
      final RecipeRepository repository = ref.read(recipeRepositoryProvider);
      final Recipe saved = existing == null
          ? await repository.create(draft)
          : await repository.update(existing.id, draft);

      // Everything that could have been showing the old version of this row, including the tag
      // chips: an edit is how a tag appears or disappears.
      ref.invalidate(feedProvider);
      ref.invalidate(feedTagsProvider);
      ref.invalidate(myRecipesProvider(saved.authorId));
      ref.invalidate(recipeByIdProvider(saved.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Saved “${saved.title}”'
                : 'Updated “${saved.title}”',
          ),
        ),
      );
      // Land on the recipe rather than back in a list: it is the thing the author just made.
      if (existing == null) {
        context.pushReplacement('/recipes/${saved.id}');
      } else {
        context.pop();
      }
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
        title: Text(_isEditing ? 'Edit recipe' : 'New recipe'),
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
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _field(
              controller: _title,
              label: 'Title',
              hint: 'Everyday dal',
              textInputAction: TextInputAction.next,
              validator: (value) => _validateTitle(value),
            ),
            const SizedBox(height: 16),
            _field(
              controller: _description,
              label: 'Description',
              hint: 'What it is, and when you make it',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _servings,
              label: 'Servings',
              hint: '4',
              keyboardType: TextInputType.number,
              validator: (value) => _validateNumber(
                value,
                min: 1,
                max: 100,
                message: 'Between 1 and 100',
              ),
            ),
            const SizedBox(height: 16),
            _field(
              controller: _prep,
              label: 'Prep minutes',
              hint: '10',
              keyboardType: TextInputType.number,
              validator: (value) => _validateNumber(
                value,
                min: 0,
                max: 1440,
                message: 'Between 0 and 1440',
              ),
            ),
            const SizedBox(height: 16),
            _field(
              controller: _cook,
              label: 'Cook minutes',
              hint: '35',
              keyboardType: TextInputType.number,
              validator: (value) => _validateNumber(
                value,
                min: 0,
                max: 1440,
                message: 'Between 0 and 1440',
              ),
            ),
            const SizedBox(height: 24),
            Text('Difficulty', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final String? option in _difficulties)
                  ChoiceChip(
                    label: Text(option ?? 'Not set'),
                    selected: _difficulty == option,
                    onSelected: (selected) =>
                        setState(() => _difficulty = selected ? option : null),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _field(
              controller: _tags,
              label: 'Tags',
              hint: 'vegetarian, weeknight',
              helper: 'Comma separated, up to ten',
              validator: (value) => _validateTags(value),
            ),
            const SizedBox(height: 16),
            _field(
              controller: _ingredients,
              label: 'Ingredients',
              hint: 'One per line',
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _steps,
              label: 'Steps',
              hint: 'One per line',
              maxLines: 6,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Anyone can see it'),
              subtitle: Text(
                _isPublic
                    ? 'It will show up in the feed.'
                    : 'Only you can see it.',
              ),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saveLabel()),
            ),
          ],
        ),
      ),
    );
  }

  String _saveLabel() {
    if (_saving) return 'Saving…';
    return _isEditing ? 'Save changes' : 'Save recipe';
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    int maxLines = 1,
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// `/recipes/:id/edit`: waits for the recipe, then hands it to the editor.
///
/// The editor takes a [Recipe] rather than an id because editing is an act on a value the person
/// can see; loading is the route's job, and it has the three states every screen in this app has.
class EditRecipeScreen extends ConsumerWidget {
  const EditRecipeScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Recipe?> recipe = ref.watch(recipeByIdProvider(recipeId));

    return recipe.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: CenteredMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load this recipe',
          message: '$error',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(recipeByIdProvider(recipeId)),
            child: const Text('Try again'),
          ),
        ),
      ),
      data: (recipe) => recipe == null
          ? Scaffold(
              appBar: AppBar(),
              body: const CenteredMessage(
                icon: Icons.help_outline,
                title: 'Recipe not available',
                message:
                    'It may have been deleted, or it is private to its author.',
              ),
            )
          // Keyed by id so switching recipes rebuilds the controllers instead of leaving the
          // previous recipe's text in the fields.
          : RecipeEditorScreen(
              key: ValueKey<String>(recipe.id),
              initial: recipe,
            ),
    );
  }
}

String? _optional(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _numberText(int? value) => value == null ? null : '$value';

/// One entry per line, because that is how people write ingredient lists in a text field.
List<String> _lines(String text) => text
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

/// Comma separated. Not truncated: an eleventh tag is a validation error the author can see and
/// fix, not something to silently throw away on their behalf.
List<String> _commaSeparated(String text) => text
    .split(',')
    .map((tag) => tag.trim())
    .where((tag) => tag.isNotEmpty)
    .toList(growable: false);

String? _validateTitle(String? value) {
  final String title = (value ?? '').trim();
  if (title.isEmpty) return 'Give the recipe a title';
  if (title.length > 120) return 'Keep the title to 120 characters';
  return null;
}

String? _validateNumber(
  String? value, {
  required int min,
  required int max,
  required String message,
}) {
  final String text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final int? parsed = int.tryParse(text);
  if (parsed == null || parsed < min || parsed > max) return message;
  return null;
}

String? _validateTags(String? value) {
  final List<String> tags = _commaSeparated(value ?? '');
  if (tags.length > 10) return 'At most ten tags';
  return null;
}
