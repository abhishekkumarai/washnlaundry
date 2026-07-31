import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// Left navigation rail.
///
/// Responsive by itself, which is what lets every screen stay a plain
/// `Row(children: [SidebarNavigation(), Expanded(...)])`:
///   * >= [expandedMinWidth] — full 240px rail, honouring the user's toggle
///   * below that            — 72px icon rail, toggle ignored
///   * below [railMinWidth]  — 60px icon rail, tighter padding
///
/// Navigation is never hidden entirely, so there is no width at which the app
/// becomes unnavigable.
class SidebarNavigation extends StatefulWidget {
  const SidebarNavigation({super.key});

  static const double expandedMinWidth = 1080;
  static const double railMinWidth = 700;

  static const double expandedWidth = 240;
  static const double railWidth = 72;
  static const double narrowRailWidth = 60;

  static const _brandBlue = Color(0xFF1A4FD6);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _disabled = Color(0xFFCBD5E1);

  // disabled: greyed out, marked "Soon", non-clickable
  static const List<Map<String, Object>> _navItems = [
    {'label': 'Dashboard', 'icon': Icons.grid_view_rounded, 'index': 0, 'disabled': false},
    {'label': 'New Order', 'icon': Icons.add_circle_outline_rounded, 'index': 1, 'disabled': false},
    {'label': 'Orders', 'icon': Icons.shopping_bag_outlined, 'index': 2, 'disabled': false},
    {'label': 'Customers', 'icon': Icons.people_outline_rounded, 'index': 3, 'disabled': false},
    {'label': 'Services', 'icon': Icons.local_offer_outlined, 'index': 4, 'disabled': false},
    {'label': 'Staff', 'icon': Icons.badge_outlined, 'index': 5, 'disabled': false},
    {'label': 'Attendance', 'icon': Icons.calendar_today_rounded, 'index': 6, 'disabled': false},
    {'label': 'Payroll', 'icon': Icons.credit_card_rounded, 'index': 7, 'disabled': false},
    {'label': 'Expenses', 'icon': Icons.receipt_long_outlined, 'index': 8, 'disabled': false},
    {'label': 'Reports', 'icon': Icons.bar_chart_rounded, 'index': 9, 'disabled': false},
    {'label': 'Apps', 'icon': Icons.apps_rounded, 'index': 10, 'disabled': true},
    {'label': 'Scan', 'icon': Icons.qr_code_scanner_rounded, 'index': 11, 'disabled': false},
    {'label': 'Subscription', 'icon': Icons.workspace_premium_outlined, 'index': 12, 'disabled': true},
    {'label': 'Settings', 'icon': Icons.settings_outlined, 'index': 13, 'disabled': true},
  ];

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  // Aliases so the build methods read the same as before the split.
  static const expandedMinWidth = SidebarNavigation.expandedMinWidth;
  static const railMinWidth = SidebarNavigation.railMinWidth;
  static const expandedWidth = SidebarNavigation.expandedWidth;
  static const railWidth = SidebarNavigation.railWidth;
  static const narrowRailWidth = SidebarNavigation.narrowRailWidth;
  static const _brandBlue = SidebarNavigation._brandBlue;
  static const _ink = SidebarNavigation._ink;
  static const _muted = SidebarNavigation._muted;
  static const _disabled = SidebarNavigation._disabled;
  static const _navItems = SidebarNavigation._navItems;

  // Its own controller: a visible Scrollbar must own exactly one ScrollPosition,
  // and the PrimaryScrollController is shared with the page behind it.
  final ScrollController _navScrollController = ScrollController();

  @override
  void dispose() {
    _navScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final screenWidth = MediaQuery.sizeOf(context).width;

    final canExpand = screenWidth >= expandedMinWidth;
    final expanded = canExpand && !provider.sidebarCollapsed;
    final narrow = screenWidth < railMinWidth;

    final width = expanded
        ? expandedWidth
        : narrow
            ? narrowRailWidth
            : railWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          _brand(context, expanded: expanded, canExpand: canExpand),
          Expanded(child: _navList(provider, expanded: expanded, narrow: narrow)),
          _profileFooter(context, expanded: expanded),
        ],
      ),
    );
  }

  Widget _brand(BuildContext context, {required bool expanded, required bool canExpand}) {
    final mark = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _brandBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.dry_cleaning_rounded, color: Colors.white, size: 22),
    );

    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
        child: Column(
          children: [
            mark,
            if (canExpand)
              IconButton(
                tooltip: 'Expand sidebar',
                iconSize: 16,
                padding: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(),
                onPressed: () => context.read<AppProvider>().toggleSidebar(),
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'WashN',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5),
                    ),
                    TextSpan(
                      text: 'Laundry',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _brandBlue, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Collapse sidebar',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => context.read<AppProvider>().toggleSidebar(),
            icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _navList(AppProvider provider, {required bool expanded, required bool narrow}) {
    // Scrollbar so it's discoverable that the rail scrolls when 14 items don't
    // fit a short window.
    return Scrollbar(
      controller: _navScrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _navScrollController,
        primary: false,
      itemCount: _navItems.length,
      padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 6, vertical: 4),
      itemBuilder: (context, index) {
        final item = _navItems[index];
        final navIndex = item['index'] as int;
        final disabled = item['disabled'] as bool;
        final isSelected = !disabled && provider.currentNavIndex == navIndex;

        final tile = _navTile(
          context,
          item: item,
          isSelected: isSelected,
          disabled: disabled,
          expanded: expanded,
          narrow: narrow,
        );

        // Group separator before "Apps".
        if (index == 10) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (expanded)
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 8, bottom: 4),
                  child: Text(
                    'MORE',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _disabled, letterSpacing: 0.8),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),
              tile,
            ],
          );
        }
          return tile;
        },
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required Map<String, Object> item,
    required bool isSelected,
    required bool disabled,
    required bool expanded,
    required bool narrow,
  }) {
    final label = item['label'] as String;
    final navIndex = item['index'] as int;

    final iconColor = disabled
        ? _disabled
        : isSelected
            ? _brandBlue
            : _muted;

    final content = expanded
        ? Row(
            children: [
              Icon(item['icon'] as IconData, size: 17, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: disabled
                        ? _disabled
                        : isSelected
                            ? _brandBlue
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
          )
        : Center(child: Icon(item['icon'] as IconData, size: narrow ? 18 : 19, color: iconColor));

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
          onTap: disabled ? null : () => context.read<AppProvider>().setNavIndex(navIndex),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 4,
              vertical: expanded ? 9 : 11,
            ),
            child: content,
          ),
        ),
      ),
    );

    // Collapsed tiles lose their label, so the tooltip carries it.
    if (expanded) return tile;
    return Tooltip(
      message: disabled ? '$label (coming soon)' : label,
      waitDuration: const Duration(milliseconds: 400),
      child: tile,
    );
  }

  Widget _profileFooter(BuildContext context, {required bool expanded}) {
    void signOut() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out of LaundryBill'),
          backgroundColor: _muted,
          duration: Duration(seconds: 2),
        ),
      );
    }

    const avatar = CircleAvatar(
      radius: 18,
      backgroundColor: Color(0xFFEEF2FF),
      child: Text(
        'AK',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brandBlue),
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(expanded ? 12 : 6, 12, expanded ? 12 : 6, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: expanded
          ? Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('washing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _ink)),
                      Text('Admin', style: TextStyle(fontSize: 11, color: _muted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout_rounded, size: 17, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: signOut,
                ),
              ],
            )
          : Column(
              children: [
                const Tooltip(message: 'washing · Admin', child: avatar),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF94A3B8)),
                  padding: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(),
                  onPressed: signOut,
                ),
              ],
            ),
    );
  }
}
