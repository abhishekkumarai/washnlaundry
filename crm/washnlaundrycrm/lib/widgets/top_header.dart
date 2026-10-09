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

  void _showShopSwitchModal(BuildContext context, AppProvider appProvider, List<Map<String, dynamic>> shops, String? activeSlug) {
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

  Widget _buildShopSwitcher(BuildContext context) {
    AppProvider? appProvider;
    try {
      appProvider = Provider.of<AppProvider?>(context);
    } catch (_) {
      appProvider = null;
    }
    if (appProvider == null) {
      return const SizedBox.shrink();
    }
    final shops = appProvider.availableShops;
    final activeSlug = appProvider.activeTenantId ?? appProvider.shop?['slug'] as String?;
    final currentName = appProvider.shop?['name'] as String? ?? 'Store';

    if (shops.length <= 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

    return InkWell(
      onTap: () => _showShopSwitchModal(context, appProvider!, shops, activeSlug),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EFEA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E0D8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF182C4F)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                currentName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF182C4F),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
          ],
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
