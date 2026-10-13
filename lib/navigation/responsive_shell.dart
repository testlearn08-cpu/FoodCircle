import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A single top-level navigation destination.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The FoodCircle top-level destinations, in branch order.
///
/// The rail and the bottom bar are both generated from this list, so the two
/// layouts cannot drift out of sync with each other or with the router.
const List<NavDestination> kNavigationDestinations = <NavDestination>[
  NavDestination(
    label: 'Feed',
    icon: Icons.feed_outlined,
    selectedIcon: Icons.feed,
  ),
  NavDestination(
    label: 'Recipes',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  NavDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

/// Mobile / tablet boundary. Widths <= this value use bottom navigation.
const double kMobileMaxWidth = 450;

/// Tablet / desktop boundary. Widths > this value use the extended rail.
const double kDesktopMinWidth = 800;

/// Responsive navigation scaffold.
///
/// Status: Implemented (file). Unverified — no Flutter SDK in the authoring
/// environment, so this has never been rendered. See DEVELOPMENT_STATUS.md.
///
/// Breakpoints (kept in step with the `Breakpoint` list in `lib/app.dart`):
/// mobile <= 450, tablet 451-800, desktop > 800.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key, required this.navigationShell});

  /// The router's shell for the current branch. Selecting a destination calls
  /// [StatefulNavigationShell.goBranch], which swaps the branch body while
  /// keeping this scaffold mounted.
  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Re-tapping the active destination pops that branch back to its root,
      // matching the behaviour users expect from a bottom bar / rail.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width <= kMobileMaxWidth;
    final isDesktop = width > kDesktopMinWidth;

    return Scaffold(
      body: Row(
        children: [
          // Navigation rail is shown on tablet and desktop only.
          if (!isMobile)
            NavigationRail(
              extended: isDesktop,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              // NavigationRail asserts that an extended rail uses either no
              // labels or NavigationRailLabelType.none; passing `selected`
              // here trips that assert on desktop widths.
              labelType: isDesktop ? null : NavigationRailLabelType.all,
              leading: const Icon(Icons.restaurant),
              destinations: [
                for (final destination in kNavigationDestinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          Expanded(child: navigationShell),
        ],
      ),
      // Mobile bottom navigation.
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: _onDestinationSelected,
              items: [
                for (final destination in kNavigationDestinations)
                  BottomNavigationBarItem(
                    icon: Icon(destination.icon),
                    activeIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            )
          : null,
    );
  }
}
