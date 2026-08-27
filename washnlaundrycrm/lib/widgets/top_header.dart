import 'package:flutter/material.dart';

import 'sidebar_navigation.dart';

class TopHeader extends StatelessWidget {
  final VoidCallback onActionPressed;

  /// The screen this header sits on. It used to always read "Dashboard", on
  /// Expenses and Payroll too.
  final String title;

  /// The primary button's label and icon. Used to be hardcoded to "New
  /// Order" everywhere, including Expenses and Payroll, where clicking it
  /// dropped you into the New Order POS instead of doing anything relevant
  /// to that screen.
  final String actionLabel;
  final IconData actionIcon;

  const TopHeader({
    super.key,
    required this.onActionPressed,
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
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow =
            constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            Row(
              children: [
                // A "Pro · Active" plan badge used to sit here. There are no
                // plan tiers — `Shop.plan` was dropped in migration 0008 — so
                // it measured nothing. Removed rather than wired.
                narrow ? _iconOnlyActionButton() : _labeledActionButton(),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.help_outline_rounded,
                      color: Color(0xFF64748B), size: 20),
                  tooltip: 'Help',
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

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
        backgroundColor: const Color(0xFF1A4FD6),
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
            backgroundColor: const Color(0xFF1A4FD6),
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
