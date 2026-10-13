import 'package:flutter/material.dart';

/// Responsive navigation scaffold.
///
/// Demo / Unverified (no Flutter SDK for compilation or render tests).
/// Uses responsive_framework breakpoints (mobile < 450, tablet 451-800, desktop > 801).
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final breakpoint = width > 800 ? 'DESKTOP' : width > 451 ? 'TABLET' : 'MOBILE';

    return Scaffold(
      body: Row(
        children: [
          // Navigation rail visible on tablet and desktop
          if (breakpoint != 'MOBILE')
            NavigationRail(
              extended: breakpoint == 'DESKTOP',
              selectedIndex: 0,
              onDestinationSelected: (i) {
                // Route selection — unverified without GoRouter integration.
              },
              labelType: breakpoint == 'DESKTOP'
                  ? NavigationRailLabelType.selected
                  : NavigationRailLabelType.all,
              leading: const Icon(Icons.restaurant),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.feed_outlined),
                  selectedIcon: Icon(Icons.feed),
                  label: Text('Feed'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: Text('Recipes'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
          Expanded(
            child: _PageBody(breakpoint: breakpoint),
          ),
        ],
      ),
      // Mobile bottom navigation
      bottomNavigationBar: breakpoint == 'MOBILE'
          ? BottomNavigationBar(
              currentIndex: 0,
              onTap: (i) {},
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.feed), label: 'Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu_book), label: 'Recipes',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }
}

class _PageBody extends StatelessWidget {
  final String breakpoint;
  const _PageBody({required this.breakpoint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FoodCircle — Responsive Shell',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Chip(label: Text('Breakpoint: $breakpoint')),
          const SizedBox(height: 24),
          const Expanded(
            child: Center(child: Text('Navigation scaffold active')),
          ),
        ],
      ),
    );
  }
}
