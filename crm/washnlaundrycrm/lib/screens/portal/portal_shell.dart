import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/portal_provider.dart';
import '../../theme/app_theme.dart';

/// Layout of every signed-in customer portal page: the shop's name on top and
/// Book · Orders · Profile as a bottom bar on phones, a rail on wide screens.
/// Deliberately not the CRM's sidebar: a customer never sees CRM sections.
class PortalShell extends StatelessWidget {
  const PortalShell(
      {super.key, required this.index, required this.child, this.title, this.showNav = true});

  /// 0 Book, 1 Orders, 2 Profile.
  final int index;
  final Widget child;
  final String? title;

  /// Off for focused flows (booking past its first step), like a checkout.
  final bool showNav;

  static const _paths = ['/book', '/orders', '/profile'];
  static const _wide = 900.0;

  @override
  Widget build(BuildContext context) {
    final portal = context.watch<PortalProvider>();
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: child,
      ),
    );
    void go(int i) => context.go(_paths[i]);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(portal.shopName, style: AppTypography.title),
            if (title != null)
              Text(title!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/find'),
            child: const Text('Change laundry'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: go,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: AppColors.card,
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.local_laundry_service_outlined), label: Text('Book')),
                    NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined), label: Text('Orders')),
                    NavigationRailDestination(
                        icon: Icon(Icons.person_outline), label: Text('Profile')),
                  ],
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide || !showNav
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: go,
              backgroundColor: AppColors.card,
              height: 64,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.local_laundry_service_outlined), label: 'Book'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
                NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            ),
    );
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
