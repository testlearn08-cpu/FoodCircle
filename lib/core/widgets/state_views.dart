import 'package:flutter/material.dart';

import '../config/env.dart';

/// Says plainly that this build is not connected to anything, because a demo that looks real is
/// worse than a demo that says it is a demo.
///
/// Designed to be an `AppBar.bottom`: the feed, "my recipes" and a recipe's own page all carry
/// it, so a screenshot of any of them is honest about where its data came from.
class DemoModeBanner extends StatelessWidget implements PreferredSizeWidget {
  const DemoModeBanner({super.key});

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

/// The empty / "could not load" / "nothing here" view, used by every screen that can fail.
///
/// Scrollable even when the content fits, so a [RefreshIndicator] above it keeps working: on an
/// empty or failed screen a pull is the gesture people reach for first, and it should not be the
/// one that does nothing.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({
    super.key,
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

/// The banner for a build with no backend, or nothing when the build has one.
PreferredSizeWidget? demoBannerOrNull() =>
    Env.isConfigured ? null : const DemoModeBanner();
