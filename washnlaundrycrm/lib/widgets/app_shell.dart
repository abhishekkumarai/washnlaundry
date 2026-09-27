import 'package:flutter/material.dart';

import 'sidebar_navigation.dart';

/// Replaces the old `Row(children: [SidebarNavigation(), Expanded(child: body)])`
/// every screen used to build directly. Pair with [AppDrawer] on the same
/// [Scaffold]'s `drawer:` — see `sidebar_navigation.dart`'s doc comment for the
/// full breakpoint story.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final narrow =
        MediaQuery.sizeOf(context).width < SidebarNavigation.railMinWidth;
    if (!narrow) {
      // stretch: the page gets the full height. With the default centre
      // alignment a body shorter than the window (a bare scroll view, say)
      // was vertically centred, floating the page title mid-screen.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [const SidebarNavigation(), Expanded(child: body)],
      );
    }
    return Column(
      children: [
        _NarrowTopBar(onMenuPressed: () => Scaffold.of(context).openDrawer()),
        Expanded(child: body),
      ],
    );
  }
}

/// The rail's brand mark moves here below [SidebarNavigation.railMinWidth],
/// alongside the hamburger that opens [AppDrawer].
class _NarrowTopBar extends StatelessWidget {
  const _NarrowTopBar({required this.onMenuPressed});

  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    // Bottom excluded: this bar only ever sits at the top of the screen, and
    // a phone with gesture-nav padding would otherwise get an extra unwanted
    // gap here that belongs to whatever's below it instead.
    return SafeArea(
      bottom: false,
      child: Container(
        height: 44,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
              onPressed: onMenuPressed,
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1A4FD6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dry_cleaning_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full nav list in a `Drawer`, shown below [SidebarNavigation.railMinWidth]
/// instead of the persistent rail.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(
        child: SafeArea(child: SidebarNavigation(inDrawer: true)));
  }
}
