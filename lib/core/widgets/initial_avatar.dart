import 'package:flutter/material.dart';

/// A person's avatar when there is no image to show: the first letter of their name.
///
/// Both the recipe page's author line and the profile header use it, so the two cannot disagree
/// about what a nameless or image-less account looks like.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.radius = 20});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        _initialOf(name),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: radius,
        ),
      ),
    );
  }
}

String _initialOf(String name) {
  final String trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}
