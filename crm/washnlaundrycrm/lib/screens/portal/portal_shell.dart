import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/portal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_logo.dart';

/// Layout of every signed-in customer portal page: [PortalNavBar] on top
/// (Profile and Sign out live in its account menu), and Book · Orders as a
/// bottom bar on phones (links in the navbar on wide screens).
/// Deliberately not the CRM's sidebar: a customer never sees CRM sections.
class PortalShell extends StatelessWidget {
  const PortalShell(
      {super.key, required this.index, required this.child, this.title, this.showNav = true});

  /// 0 Book, 1 Orders, 2 Profile.
  final int index;
  final Widget child;

  /// A heading over the page (booking shows its own step titles instead).
  final String? title;

  /// Off for focused flows (booking past its first step), like a checkout.
  final bool showNav;

  static const _paths = ['/book', '/orders'];
  static const wide = 900.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= wide;
    final heading = title != null && index != 0;
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: heading
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Text(title!,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AppColors.ink)),
                ),
                Expanded(child: child),
              ])
            : child,
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PortalNavBar(index: index),
      body: body,
      bottomNavigationBar: isWide || !showNav
          ? null
          : NavigationBar(
              // Profile is in the navbar's menu, so on it neither tab is lit.
              selectedIndex: index.clamp(0, 1),
              indicatorColor: index > 1 ? Colors.transparent : null,
              onDestinationSelected: (i) => context.go(_paths[i]),
              backgroundColor: AppColors.card,
              height: 64,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.local_laundry_service_outlined), label: 'Book'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
              ],
            ),
    );
  }
}

/// The portal's top navbar on every signed-in page: logo, the laundry being
/// booked with (tap to change), Book · Orders links on wide screens, and an
/// account menu with Profile and Sign out.
class PortalNavBar extends StatelessWidget implements PreferredSizeWidget {
  const PortalNavBar({super.key, this.index, this.leading, this.choosingShop = false});

  /// The active section (0 Book, 1 Orders, 2 Profile), or null off-section.
  final int? index;

  /// Shown before the logo, e.g. a back arrow.
  final Widget? leading;

  /// On the laundry list itself: no laundry switcher, links or "Change
  /// laundry" (the page is the switcher; its back arrow returns to booking).
  final bool choosingShop;

  static const height = 60.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final portal = context.watch<PortalProvider>();
    final wide = MediaQuery.sizeOf(context).width >= PortalShell.wide;
    final hasShop = portal.shopSlug != null && !choosingShop;
    return Material(
      color: AppColors.card,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          // Everything but the account menu in one Expanded row, so the menu sits
          // at the right edge whatever the shop name's width.
          child: Row(children: [
            Expanded(
                child: Row(children: [
              if (leading != null) leading!,
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.go(hasShop ? '/book' : '/find'),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const BrandLogo(size: 30),
                    if (wide || !hasShop) ...[
                      const SizedBox(width: 8),
                      const Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'WashN', style: TextStyle(color: AppColors.ink)),
                          TextSpan(text: 'Laundry', style: TextStyle(color: AppColors.accent)),
                        ]),
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                      ),
                    ],
                  ]),
                ),
              ),
              if (hasShop) ...[
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: AppColors.border,
                ),
                Flexible(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.go('/find'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: Text(portal.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted),
                      ]),
                    ),
                  ),
                ),
              ],
              if (hasShop && wide) ...[
                const SizedBox(width: 24),
                _NavLink(label: 'Book', active: index == 0, onTap: () => context.go('/book')),
                _NavLink(label: 'Orders', active: index == 1, onTap: () => context.go('/orders')),
              ],
            ])),
            _AccountMenu(choosingShop: choosingShop),
          ]),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: PortalNavBar.height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? AppColors.ink : AppColors.muted)),
        ),
      );
}

/// The signed-in customer's menu: who they are, Profile, Change laundry, Sign out.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.choosingShop});

  final bool choosingShop;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasShop = context.watch<PortalProvider>().shopSlug != null;
    final email = auth.userEmail ?? '';
    final name = (auth.userName ?? '').trim();
    final initial = (name.isNotEmpty ? name : email).trim().isEmpty
        ? '?'
        : (name.isNotEmpty ? name : email)[0].toUpperCase();
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, PortalNavBar.height - 8),
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (v) {
        switch (v) {
          case 'profile':
            context.go('/profile');
          case 'change':
            context.go('/find');
          case 'signout':
            auth.signOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (name.isNotEmpty)
              Text(name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
            Text(email, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ]),
        ),
        const PopupMenuDivider(),
        if (hasShop)
          const PopupMenuItem(
            value: 'profile',
            child: _MenuRow(icon: Icons.person_outline, label: 'Profile'),
          ),
        if (!choosingShop)
          const PopupMenuItem(
            value: 'change',
            child: _MenuRow(icon: Icons.storefront_outlined, label: 'Change laundry'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'signout',
          child: _MenuRow(icon: Icons.logout_rounded, label: 'Sign out', danger: true),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accentSoft,
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.danger = false});

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return Row(children: [
      Icon(icon, size: 18, color: danger ? AppColors.danger : AppColors.muted),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(fontSize: 14, color: color)),
    ]);
  }
}

/// A flat, bordered panel (the portal's card).
class PortalPanel extends StatelessWidget {
  const PortalPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );
}

/// Centered single-column page for the steps before the shell (sign in, find, join).
class PortalPage extends StatelessWidget {
  const PortalPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        // The scroll view spans the window so its scrollbar sits at the window's
        // edge, not beside the column (as on the CRM login); minHeight keeps
        // short pages centred.
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Small caps label over a form field (the portal's field labels).
const portalFieldLabel = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF475569));

/// The portal's text field: white, hairline border, navy when focused.
InputDecoration portalField(String hint, {IconData? icon, String? prefix}) {
  OutlineInputBorder edge(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    prefixIcon: icon == null ? null : Icon(icon, size: 18, color: AppColors.muted),
    prefixText: prefix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    filled: true,
    fillColor: AppColors.card,
    border: edge(AppColors.border),
    enabledBorder: edge(AppColors.border),
    focusedBorder: edge(AppColors.primary, 1.5),
  );
}

/// Error text in the portal's danger colour, or nothing.
Widget portalError(String? message) => message == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(message, style: const TextStyle(color: AppColors.danger)),
      );

const portalStatusLabels = {
  'PLACED': 'Booked',
  'PROCESSING': 'Processing',
  'IRONING': 'Ironing',
  'READY': 'Ready',
  'OUT_FOR_DELIVERY': 'Out for delivery',
  'DELIVERED': 'Delivered',
  'CANCELLED': 'Cancelled',
};
