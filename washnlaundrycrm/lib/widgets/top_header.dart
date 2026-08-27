import 'package:flutter/material.dart';

import 'sidebar_navigation.dart';

class TopHeader extends StatelessWidget {
  final VoidCallback onNewOrderPressed;

  /// The screen this header sits on. It used to always read "Dashboard", on
  /// Expenses and Payroll too.
  final String title;

  const TopHeader({
    super.key,
    required this.onNewOrderPressed,
    required this.title,
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
                narrow ? _iconOnlyNewOrderButton() : _labeledNewOrderButton(),
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

  Widget _labeledNewOrderButton() {
    return ElevatedButton.icon(
      onPressed: onNewOrderPressed,
      icon: const Icon(Icons.add, size: 16, color: Colors.white),
      label: const Text(
        'New Order',
        style: TextStyle(
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

  Widget _iconOnlyNewOrderButton() {
    return Tooltip(
      message: 'New Order',
      child: SizedBox(
        width: 38,
        height: 38,
        child: ElevatedButton(
          onPressed: onNewOrderPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A4FD6),
            padding: EdgeInsets.zero,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Icon(Icons.add, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
