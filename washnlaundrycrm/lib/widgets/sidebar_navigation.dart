import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // disabled: grayed out, shows "Coming Soon" tooltip, non-clickable
    final navItems = [
      {'label': 'Dashboard',    'icon': Icons.grid_view_rounded,           'index': 0,  'disabled': false},
      {'label': 'New Order',    'icon': Icons.add_circle_outline_rounded,  'index': 1,  'disabled': false},
      {'label': 'Orders',       'icon': Icons.shopping_bag_outlined,       'index': 2,  'disabled': false},
      {'label': 'Customers',    'icon': Icons.people_outline_rounded,      'index': 3,  'disabled': false},
      {'label': 'Services',     'icon': Icons.local_offer_outlined,        'index': 4,  'disabled': false},
      {'label': 'Staff',        'icon': Icons.badge_outlined,              'index': 5,  'disabled': false},
      {'label': 'Attendance',   'icon': Icons.calendar_today_rounded,      'index': 6,  'disabled': false},
      {'label': 'Payroll',      'icon': Icons.credit_card_rounded,         'index': 7,  'disabled': false},
      {'label': 'Expenses',     'icon': Icons.receipt_long_outlined,       'index': 8,  'disabled': false},
      {'label': 'Reports',      'icon': Icons.bar_chart_rounded,           'index': 9,  'disabled': false},
      {'label': 'Apps',         'icon': Icons.apps_rounded,                'index': 10, 'disabled': true},
      {'label': 'Scan',         'icon': Icons.qr_code_scanner_rounded,     'index': 11, 'disabled': false},
      {'label': 'Subscription', 'icon': Icons.workspace_premium_outlined,  'index': 12, 'disabled': true},
      {'label': 'Settings',     'icon': Icons.settings_outlined,           'index': 13, 'disabled': false},
    ];

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A4FD6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dry_cleaning_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                // Flexible + scaleDown so the wordmark never overflows the
                // fixed 240px rail, whatever the font metrics resolve to.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(text: 'WashN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                          TextSpan(text: 'Laundry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A4FD6), letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Nav Items List
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemBuilder: (context, index) {
                final item = navItems[index];
                final navIndex = item['index'] as int;
                final disabled = item['disabled'] as bool;
                final isSelected = !disabled && provider.currentNavIndex == navIndex;

                final tile = Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: disabled ? null : () => provider.setNavIndex(navIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 17,
                              color: disabled
                                  ? const Color(0xFFCBD5E1)
                                  : isSelected
                                      ? const Color(0xFF1A4FD6)
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: disabled
                                      ? const Color(0xFFCBD5E1)
                                      : isSelected
                                          ? const Color(0xFF1A4FD6)
                                          : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            if (disabled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Soon',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                // Group separator before Apps
                if (index == 10) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 12, top: 8, bottom: 4),
                        child: Text('MORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFCBD5E1), letterSpacing: 0.8)),
                      ),
                      tile,
                    ],
                  );
                }

                return tile;
              },
            ),
          ),

          // User Profile Footer
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: const Text('AK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('washing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Admin', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 17, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logged out of LaundryBill'),
                        backgroundColor: Color(0xFF64748B),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
