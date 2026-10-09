import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'sidebar_navigation.dart';

class TopHeader extends StatelessWidget {
  /// Null omits the primary button entirely — for a screen whose own body
  /// already has a dedicated control for the same action, so the header
  /// would otherwise render a second, redundant one. Expenses is the one
  /// case of this today: its in-page "Add Expense" button predates this
  /// header ever having an action at all, so the header doesn't get one.
  final VoidCallback? onActionPressed;

  /// The screen this header sits on. It used to always read "Dashboard", on
  /// Expenses and Payroll too.
  final String title;

  /// The primary button's label and icon. Used to be hardcoded to "New
  /// Order" everywhere, including Expenses and Payroll, where clicking it
  /// dropped you into the New Order POS instead of doing anything relevant
  /// to that screen. Unused when [onActionPressed] is null.
  final String actionLabel;
  final IconData actionIcon;

  const TopHeader({
    super.key,
    this.onActionPressed,
    required this.title,
    this.actionLabel = 'New Order',
    this.actionIcon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow =
            constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF141A24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildShopSwitcher(context),
                ],
              ),
            ),
            if (onActionPressed != null)
              narrow ? _iconOnlyActionButton() : _labeledActionButton(),
          ],
        );
      }),
    );
  }

  Widget _buildShopSwitcher(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final shops = appProvider.availableShops;
    final activeSlug = appProvider.activeTenantId ?? appProvider.shop?['slug'] as String?;

    if (shops.length <= 1) {
      final currentName = appProvider.shop?['name'] as String? ?? 'Store';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EFEA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              currentName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF182C4F),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFEA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: activeSlug,
          isDense: true,
          icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF182C4F)),
          items: shops.map((s) {
            final slug = s['slug'] as String? ?? s['id']?.toString() ?? '';
            final name = s['name'] as String? ?? 'Shop';
            final role = s['role'] as String? ?? '';
            return DropdownMenuItem<String>(
              value: slug,
              child: Text(
                role.isNotEmpty ? '$name ($role)' : name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF182C4F),
                ),
              ),
            );
          }).toList(),
          onChanged: (newSlug) {
            if (newSlug != null && newSlug != activeSlug) {
              appProvider.switchShop(newSlug);
            }
          },
        ),
      ),
    );
  }

  /// Only ever built when [onActionPressed] is non-null — see the call site.
  Widget _labeledActionButton() {
    return ElevatedButton.icon(
      onPressed: onActionPressed,
      icon: Icon(actionIcon, size: 16, color: Colors.white),
      label: Text(
        actionLabel,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF182C4F),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _iconOnlyActionButton() {
    return Tooltip(
      message: actionLabel,
      child: SizedBox(
        width: 38,
        height: 38,
        child: ElevatedButton(
          onPressed: onActionPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF182C4F),
            padding: EdgeInsets.zero,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Icon(actionIcon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
