import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'panel_card.dart';

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
    final shop = context.watch<AppProvider>().shop;
    final ownerName = (shop?['owner_name'] as String?)?.trim() ?? '';
    final shopName = (shop?['name'] as String?)?.trim() ?? '';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          Row(
            children: [
              // A "Pro · Active" plan badge used to sit here. There are no
              // plan tiers — `Shop.plan` was dropped in migration 0008 — so it
              // measured nothing. Removed rather than wired.
              ElevatedButton.icon(
                onPressed: onNewOrderPressed,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'New Order',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4FD6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF64748B), size: 20),
                tooltip: 'Help',
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: ownerName.isEmpty ? 'Your shop' : ownerName,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(
                    initialsFor(ownerName.isEmpty ? shopName : ownerName),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
