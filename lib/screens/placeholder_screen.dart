import 'package:flutter/material.dart';

/// Body for a top-level destination that has no real screen yet.
///
/// Named `PlaceholderScreen` rather than `Placeholder` to avoid shadowing
/// Flutter's built-in `Placeholder` widget.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Not implemented yet',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
