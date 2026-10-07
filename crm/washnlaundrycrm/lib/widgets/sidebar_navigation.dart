import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/navigation.dart';
import '../utils/role_views.dart';
import 'brand_logo.dart';
import 'panel_card.dart';

/// Left navigation rail.
///
/// Above [railMinWidth], every screen wraps this in `AppShell`
/// (`lib/widgets/app_shell.dart`), which renders it as a persistent rail:
///   * >= [expandedMinWidth] — full 240px rail, honouring the user's toggle
///   * below that            — 72px icon rail, toggle ignored
///   * below [railMinWidth]  — 60px icon rail, tighter padding
///
/// Below [railMinWidth], `AppShell` drops the rail entirely in favour of a
/// slim hamburger bar that opens `AppDrawer`, which hosts this same widget
/// with [inDrawer] set — see that flag's doc for what changes in that mode.
class SidebarNavigation extends StatefulWidget {
  const SidebarNavigation({super.key, this.inDrawer = false});

  /// True when hosted inside [AppDrawer] rather than the persistent rail.
  /// Forces the full labeled (`expanded`) layout regardless of screen width,
  /// fills whatever width the enclosing `Drawer` gives it instead of a fixed
  /// rail width, drops the rail-only right border and collapse toggle (there
  /// is nothing to "collapse" inside a drawer — you just close it), and pops
  /// the drawer on nav-item tap.
  final bool inDrawer;

  static const double expandedMinWidth = 1080;
  static const double railMinWidth = 700;

  /// Below this, a screen's own content — tables, header actions — switches
  /// to its phone-width layout (cards instead of a table, icon-only instead
  /// of labeled buttons). Independent of the rail breakpoints above; kept
  /// here so every screen references one shared constant instead of its own
  /// private copy.
  static const double contentWideBreakpoint = 760;

  /// A second, wider threshold for content that only needs one stacking step
  /// — two side-by-side panels collapsing to one column — rather than a full
  /// table-to-card rebuild.
  static const double contentStackBreakpoint = 900;

  static const double expandedWidth = 240;
  static const double railWidth = 72;
  static const double narrowRailWidth = 60;

  static const _brandBlue = Color(0xFF182C4F);
  static const _ink = Color(0xFF141A24);
  static const _muted = Color(0xFF64748B);
  static const _disabled = Color(0xFFD9D5CB);

  // disabled: greyed out, marked "Soon", non-clickable
  static const List<Map<String, Object>> _navItems = [
    {
      'label': 'Dashboard',
      'icon': Icons.grid_view_rounded,
      'index': 0,
      'disabled': false
    },
    {
      'label': 'New Order',
      'icon': Icons.add_circle_outline_rounded,
      'index': 1,
      'disabled': false
    },
    {
      'label': 'Orders',
      'icon': Icons.shopping_bag_outlined,
      'index': 2,
      'disabled': false
    },
    {
      'label': 'Customers',
      'icon': Icons.people_outline_rounded,
      'index': 3,
      'disabled': false
    },
    {
      'label': 'Services',
      'icon': Icons.local_offer_outlined,
      'index': 4,
      'disabled': false
    },
    {
      'label': 'Staff',
      'icon': Icons.badge_outlined,
      'index': 5,
      'disabled': false
    },
    {
      'label': 'Attendance',
      'icon': Icons.calendar_today_rounded,
      'index': 6,
      'disabled': false
    },
    {
      'label': 'Payroll',
      'icon': Icons.credit_card_rounded,
      'index': 7,
      'disabled': false
    },
    {
      'label': 'Expenses',
      'icon': Icons.receipt_long_outlined,
      'index': 8,
      'disabled': false
    },
    {
      'label': 'Credits',
      'icon': Icons.savings_outlined,
      'index': 15,
      'disabled': false
    },
    {
      'label': 'Reports',
      'icon': Icons.bar_chart_rounded,
      'index': 9,
      'disabled': false
    },
    {
      'label': 'Scan',
      'icon': Icons.qr_code_scanner_rounded,
      'index': 11,
      'disabled': false
    },
    {
      'label': 'Settings',
      'icon': Icons.settings_outlined,
      'index': 13,
      'disabled': false
    },
    {
      'label': 'Chat',
      'icon': Icons.smart_toy_rounded,
      'index': 16,
      'disabled': false
    },
    {
      'label': 'Help',
      'icon': Icons.help_outline_rounded,
      'index': 14,
      'disabled': false
    },
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

    final canExpand = !widget.inDrawer && screenWidth >= expandedMinWidth;
    final expanded =
        widget.inDrawer || (canExpand && !provider.sidebarCollapsed);
    final narrow = !widget.inDrawer && screenWidth < railMinWidth;

    final width = widget.inDrawer
        ? double.infinity
        : expanded
            ? expandedWidth
            : narrow
                ? narrowRailWidth
                : railWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: widget.inDrawer
            ? null
            : const Border(right: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Column(
        children: [
          _brand(context, expanded: expanded, canExpand: canExpand),
          Expanded(
              child: _navList(provider, expanded: expanded, narrow: narrow)),
          _profileFooter(context, expanded: expanded),
        ],
      ),
    );
  }

  Widget _brand(BuildContext context,
      {required bool expanded, required bool canExpand}) {
    const mark = BrandLogo(size: 40);

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
                icon: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
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
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'WashN',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.5),
                    ),
                    TextSpan(
                      text: 'Laundry',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _brandBlue,
                          letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!widget.inDrawer)
            IconButton(
              tooltip: 'Collapse sidebar',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => context.read<AppProvider>().toggleSidebar(),
              icon: const Icon(Icons.chevron_left_rounded,
                  color: Color(0xFF94A3B8)),
            ),
        ],
      ),
    );
  }

  Widget _navList(AppProvider provider,
      {required bool expanded, required bool narrow}) {
    // Staff (non-owner) only get the day-to-day screens; see `staffRoutes` in
    // router.dart and IsOwner in the backend's api/auth.py.
    const staffNav = {1, 2, 3, 11};
    var items = provider.role == 'staff'
        ? _navItems.where((i) => staffNav.contains(i['index'])).toList()
        : _navItems;
    // Views hidden for the signed-in role in assets/config/role_views.json.
    final authRole = context.signedInRole;
    items = items
        .where((i) => !RoleViews.isLabelHidden(authRole, i['label'] as String))
        .toList();
    // Scrollbar so it's discoverable that the rail scrolls when 14 items don't
    // fit a short window.
    return Scrollbar(
      controller: _navScrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _navScrollController,
        primary: false,
        itemCount: items.length,
        padding:
            EdgeInsets.symmetric(horizontal: expanded ? 10 : 6, vertical: 4),
        itemBuilder: (context, index) {
          final item = items[index];
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
          if (navIndex == 10) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (expanded)
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 8, bottom: 4),
                    child: Text(
                      'MORE',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _disabled,
                          letterSpacing: 0.8),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFF1EFEA)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFEA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Soon',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8)),
                  ),
                ),
            ],
          )
        : Center(
            child: Icon(item['icon'] as IconData,
                size: narrow ? 18 : 19, color: iconColor));

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: disabled
              ? null
              : () {
                  if (navIndex == 14) {
                    if (widget.inDrawer) Navigator.of(context).maybePop();
                    _showHelpDialog(context);
                  } else {
                    context.goSection(navIndex);
                    if (widget.inDrawer) Navigator.of(context).maybePop();
                  }
                },
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
    // router.dart's redirect reacts to AuthProvider.isSignedIn flipping and
    // sends the app back to /login — true for a real Google session or a
    // Demo Mode one, since AuthProvider.signOut() clears either.
    void signOut() {
      context.read<AuthProvider?>()?.signOut();
    }

    // The shop from `/api/shops/` or customer session from AuthProvider.
    final auth = context.watch<AuthProvider?>();
    // The signed-in role (AppProvider.role is "owner" for customers).
    final isCustomer = auth?.role == 'customer';
    final shop = context.watch<AppProvider>().shop;
    final shopName = (shop?['name'] as String?)?.trim() ?? '';
    final ownerName = (shop?['owner_name'] as String?)?.trim() ?? '';

    final title = isCustomer
        ? (auth?.userName?.isNotEmpty == true
            ? auth!.userName!
            : (auth?.me?['customer']?['name'] as String?) ?? 'Customer')
        : (shopName.isEmpty ? 'Your shop' : shopName);
    final subtitle = isCustomer
        ? (auth?.userEmail ?? 'Customer')
        : (ownerName.isEmpty ? 'Admin' : ownerName);
    final avatarSource = isCustomer ? title : (ownerName.isEmpty ? shopName : ownerName);

    void openProfile() => context.go('/profile');

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFEFF6FF),
      child: Text(
        initialsFor(avatarSource),
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: _brandBlue),
      ),
    );

    return Container(
      padding:
          EdgeInsets.fromLTRB(expanded ? 12 : 6, 12, expanded ? 12 : 6, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1EFEA))),
      ),
      child: expanded
          ? Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: openProfile,
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        avatar,
                        const SizedBox(width: 10),
                        Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _ink),
                      ),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout_rounded,
                      size: 17, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: signOut,
                ),
              ],
            )
          : Column(
              children: [
                Tooltip(
                  message: subtitle.isEmpty ? title : '$title · $subtitle',
                  child: InkWell(
                    onTap: openProfile,
                    customBorder: const CircleBorder(),
                    child: avatar,
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                  padding: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(),
                  onPressed: signOut,
                ),
              ],
            ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_rounded,
                    color: _brandBlue, size: 22),
                SizedBox(width: 10),
                Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 20, color: Color(0xFF94A3B8)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need help managing your laundry CRM or POS?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get in touch with support or find answers to common questions about orders, customers, payroll, and billing.',
              style: TextStyle(
                fontSize: 13,
                color: _muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _helpContactRow(
              icon: Icons.email_outlined,
              label: 'Email Support',
              value: 'support@washnlaundry.com',
            ),
            const SizedBox(height: 10),
            _helpContactRow(
              icon: Icons.phone_outlined,
              label: 'Phone Support',
              value: '+91 80 4567 8900',
            ),
            const SizedBox(height: 10),
            _helpContactRow(
              icon: Icons.schedule_outlined,
              label: 'Hours',
              value: 'Mon – Sat, 9:00 AM – 8:00 PM',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Close',
              style: TextStyle(
                color: _brandBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
