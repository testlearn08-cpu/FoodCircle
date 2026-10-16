import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/recipe_list.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/recipe.dart';

/// The public feed, with search and a tag filter on top of it (S2 and S5 of the product spec).
///
/// Reads [feedProvider] and [feedTagsProvider] and nothing else, so it works identically against
/// Supabase and against the in-memory repository — which is what the web preview and the widget
/// tests use.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Recipe>> feed = ref.watch(feedProvider);
    final FeedQuery query = ref.watch(feedQueryProvider);
    final AsyncValue<List<String>> tags = ref.watch(feedTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodCircle'),
        bottom: demoBannerOrNull(),
      ),
      body: Column(
        children: <Widget>[
          _SearchField(text: query.text),
          if (tags.valueOrNull?.isNotEmpty ?? false)
            _TagFilter(tags: tags.value!, selected: query.tag),
          Expanded(
            child: RecipeAsyncList(
              recipes: feed,
              // Tapping used to explain that the detail screen was not built. It is built now,
              // and it lives in this branch, so the shell stays put: `/feed/:id`.
              onTap: (recipe) => context.push('/feed/${recipe.id}'),
              onRefresh: () {
                ref.invalidate(feedTagsProvider);
                return ref.refresh(feedProvider.future);
              },
              onRetry: () => ref.invalidate(feedProvider),
              emptyIcon: query.isFiltered
                  ? Icons.search_off_outlined
                  : Icons.ramen_dining_outlined,
              emptyTitle:
                  query.isFiltered ? 'No recipes match' : 'Nothing here yet',
              emptyMessage: query.isFiltered
                  ? 'Nothing in the feed matches that. Try fewer words, or '
                      'a different tag.'
                  : 'Recipes shared publicly will show up here.',
              // An empty search result is a dead end unless there is a way back out of it.
              emptyAction: query.isFiltered
                  ? FilledButton.tonal(
                      onPressed: () {
                        ref.read(feedQueryProvider.notifier).state =
                            const FeedQuery();
                      },
                      child: const Text('Clear search'),
                    )
                  : null,
              errorTitle: 'Could not load the feed',
            ),
          ),
        ],
      ),
    );
  }
}

/// The search box. Owns nothing but its debounce timer: the query itself lives in
/// [feedQueryProvider], so the clear button, the empty state's "Clear search" and the field all
/// write to the same place instead of each keeping a copy.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.text});

  final String text;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  /// Typing should not mean one request per keystroke, but it should also not feel laggy: 300ms
  /// is about the point where a fast typist has stopped mid-word. Pressing enter skips the wait.
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  late final TextEditingController _controller =
      TextEditingController(text: widget.text);
  Timer? _debounce;

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Something else cleared the query (the empty state's button, or a future "reset filters"):
    // the field has to follow, or it would show a search that is no longer applied.
    if (widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _apply(String value) {
    _debounce?.cancel();
    final FeedQuery current = ref.read(feedQueryProvider);
    ref.read(feedQueryProvider.notifier).state = current.copyWith(text: value);
  }

  void _onChanged(String value) {
    // Rebuilds for the clear button's visibility; the query itself waits for the debounce.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _apply(value));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        onSubmitted: _apply,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search title or ingredients',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _controller.clear();
                    _apply('');
                  },
                ),
        ),
      ),
    );
  }
}

/// The tag filter, built from the tags actually present in the feed.
class _TagFilter extends ConsumerWidget {
  const _TagFilter({required this.tags, required this.selected});

  final List<String> tags;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: tags.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final String tag = tags[index];
          final bool isSelected = tag == selected;

          return ChoiceChip(
            label: Text('#$tag'),
            selected: isSelected,
            // Tapping the selected chip clears the filter, which is what the control implies.
            onSelected: (bool nowSelected) {
              ref.read(feedQueryProvider.notifier).state = ref
                  .read(feedQueryProvider)
                  .copyWith(tag: tag, clearTag: !nowSelected);
            },
          );
        },
      ),
    );
  }
}
