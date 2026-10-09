import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

/// Displays a modal bottom sheet allowing users to switch between their accessible
/// shops / branches with role badges and active selection indicators.
void showShopSwitchModalSheet(BuildContext context) {
  final appProvider = Provider.of<AppProvider>(context, listen: false);
  final shops = appProvider.availableShops;
  final activeSlug = appProvider.activeTenantId ?? appProvider.shop?['slug'] as String?;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 20, color: Color(0xFF182C4F)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Switch Store / Branch',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF141A24),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Select the shop you want to manage. Your active session will switch instantly.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              if (shops.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No branches available to switch.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: shops.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1EFEA)),
                    itemBuilder: (_, index) {
                      final s = shops[index];
                      final slug = s['slug'] as String? ?? s['id']?.toString() ?? '';
                      final name = s['name'] as String? ?? 'Shop';
                      final role = (s['role'] as String? ?? '').toUpperCase();
                      final isSelected = slug == activeSlug;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        tileColor: isSelected ? const Color(0xFFEFF6FF) : null,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isSelected ? const Color(0xFF182C4F) : const Color(0xFFF1EFEA),
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 18,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? const Color(0xFF182C4F) : const Color(0xFF141A24),
                          ),
                        ),
                        subtitle: role.isNotEmpty
                            ? Text(
                                'Role: $role',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF2563EB))
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          if (slug != activeSlug) {
                            appProvider.switchShop(slug);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
