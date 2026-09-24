import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/credit_categories_panel.dart';
import '../widgets/sidebar_navigation.dart';

/// One entry in Settings' vertical tab list.
class _SettingsTab {
  final String slug;
  final IconData icon;
  final String title;

  /// Tabs that open a separate page in the real app get a chevron.
  final bool hasArrow;

  const _SettingsTab(this.slug, this.icon, this.title, {this.hasArrow = false});
}

class SettingsScreen extends StatefulWidget {
  /// Slug of the tab to open on (`/settings?tab=credit-categories`); unknown
  /// or missing falls back to Business profile.
  final String? initialTab;

  const SettingsScreen({super.key, this.initialTab});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const businessProfile = 'business-profile';
  static const creditCategories = 'credit-categories';

  /// Only [businessProfile] and [creditCategories] are built; the rest are
  /// listed for parity with the real app and show a "Not available yet" panel.
  static const _mainTabs = [
    _SettingsTab(businessProfile, Icons.storefront_outlined, 'Business profile'),
    _SettingsTab('tax-currency', Icons.attach_money_rounded, 'Tax & currency'),
    _SettingsTab('bank-details', Icons.account_balance_outlined, 'Bank details'),
    _SettingsTab('operations', Icons.tune_rounded, 'Operations'),
    _SettingsTab('preferences', Icons.palette_outlined, 'Preferences'),
    _SettingsTab(creditCategories, Icons.savings_outlined, 'Credit categories'),
  ];
  static const _accountTabs = [
    _SettingsTab('subscription', Icons.card_membership_outlined,
        'Subscription & billing',
        hasArrow: true),
    _SettingsTab('payment-history', Icons.receipt_outlined, 'Payment history',
        hasArrow: true),
    _SettingsTab('help', Icons.help_outline_rounded, 'Help & support',
        hasArrow: true),
  ];
  static const _allTabs = [..._mainTabs, ..._accountTabs];

  static String _validTab(String? slug) =>
      _allTabs.any((t) => t.slug == slug) ? slug! : businessProfile;

  late String _selectedTab = _validTab(widget.initialTab);

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Following a `?tab=` link while already on /settings rebuilds this same
    // State, so the new tab has to be picked up here rather than in initState.
    if (widget.initialTab != oldWidget.initialTab) {
      _selectedTab = _validTab(widget.initialTab);
    }
  }

  // Populated from the shop record once it loads — no hardcoded defaults, so
  // the form can never show one shop's details while saving to another.
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  bool _saving = false;

  /// Id of the shop currently loaded into the form, so we only overwrite the
  /// fields when a different shop arrives — never while the user is typing.
  String? _loadedShopId;

  void _hydrate(Map<String, dynamic>? shop) {
    if (shop == null) return;
    final id = shop['id']?.toString();
    if (id == _loadedShopId) return;
    _loadedShopId = id;

    _shopNameController.text = shop['name'] as String? ?? '';
    _phoneController.text = shop['phone'] as String? ?? '';
    _whatsappController.text = shop['whatsapp'] as String? ?? '';
    _emailController.text = shop['email'] as String? ?? '';
    _addressController.text = shop['address'] as String? ?? '';
    _cityController.text = shop['city'] as String? ?? '';
    _stateController.text = shop['state'] as String? ?? '';
    _pincodeController.text = shop['pin_code'] as String? ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _shopNameController,
      _phoneController,
      _whatsappController,
      _emailController,
      _addressController,
      _cityController,
      _stateController,
      _pincodeController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();

    setState(() => _saving = true);
    final ok = await provider.saveShop({
      'name': _shopNameController.text.trim(),
      'whatsapp': _whatsappController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'pin_code': _pincodeController.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Settings saved'
            : 'Could not save settings: ${provider.error ?? 'unknown error'}'),
        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<AppProvider>().shop;
    _hydrate(shop);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow =
                constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            if (narrow) {
              // Phone width: the 240px tab column would leave almost nothing
              // for the content, so the tabs become a scrolling chip row.
              return Column(
                children: [
                  _header(narrow: true),
                  _tabChips(),
                  Expanded(child: _content(narrow: true)),
                ],
              );
            }
            return Row(
              children: [
                _tabColumn(shop),
                Expanded(
                  child: Column(
                    children: [
                      _header(narrow: false),
                      Expanded(child: _content(narrow: false)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  _SettingsTab get _current =>
      _allTabs.firstWhere((t) => t.slug == _selectedTab);

  Widget _tabColumn(Map<String, dynamic>? shop) {
    final shopName = (shop?['name'] as String?) ?? '';
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Top User Card Header
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    shopName.isEmpty ? '?' : shopName[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A4FD6)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName.isEmpty ? 'Your shop' : shopName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A)),
                      ),
                      const Text('Admin',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Settings Tabs List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final tab in _mainTabs) _buildTabItem(tab),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                for (final tab in _accountTabs) _buildTabItem(tab),
                const SizedBox(height: 20),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.logout_rounded,
                        color: Color(0xFFEF4444), size: 18),
                    title: const Text('Sign Out',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444))),
                    // Same call as the sidebar's sign-out; router.dart's
                    // redirect then sends the app to /login. This used to
                    // only show a snackbar while staying signed in.
                    onTap: () => context.read<AuthProvider>().signOut(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SizedBox(
        height: 36,
        // ListView, not a Row in a SingleChildScrollView — same reason as
        // staff_screen.dart's sub-tabs: it fills the width instead of
        // shrink-wrapping and centering.
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _allTabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final tab = _allTabs[i];
            final isSel = tab.slug == _selectedTab;
            return ChoiceChip(
              key: ValueKey('settings-chip-${tab.slug}'),
              avatar: Icon(tab.icon,
                  size: 16,
                  color: isSel
                      ? const Color(0xFF1A4FD6)
                      : const Color(0xFF64748B)),
              label: Text(tab.title, style: const TextStyle(fontSize: 12)),
              selected: isSel,
              showCheckmark: false,
              selectedColor: const Color(0xFFEEF2FF),
              onSelected: (_) => setState(() => _selectedTab = tab.slug),
            );
          },
        ),
      ),
    );
  }

  Widget _header({required bool narrow}) {
    final isProfile = _selectedTab == businessProfile;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Text('Settings',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const Spacer(),
          // Only Business profile has a form to save; Credit categories
          // saves each change as it is made.
          if (isProfile)
            ElevatedButton(
              onPressed: _saving ? null : () => _save(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A4FD6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save changes',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _content({required bool narrow}) {
    final Widget child;
    switch (_selectedTab) {
      case businessProfile:
        child = _businessProfileForm();
        break;
      case creditCategories:
        child = const CreditCategoriesPanel();
        break;
      default:
        child = _notAvailable(_current);
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(narrow ? 16 : 32),
      child: Container(
        padding: EdgeInsets.all(narrow ? 18 : 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: child,
      ),
    );
  }

  Widget _notAvailable(_SettingsTab tab) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tab.title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(tab.icon, size: 20, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Not available yet.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _businessProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Business profile',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
        const Text(
            'Your shop identity, contact and location.',
            style: TextStyle(
                fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 24),

        // Shop Logo & Name Box
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1A4FD6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.storefront_rounded,
                  size: 28, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text('Shop Name',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _shopNameController,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Divider(height: 1),
        const SizedBox(height: 24),

        // Contact Information Section Header
        Row(
          children: const [
            Icon(Icons.phone_outlined,
                size: 18, color: Color(0xFF1A4FD6)),
            SizedBox(width: 8),
            Text('Contact Information',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 20),

        // Phone Number
        const Text('Phone Number',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          readOnly: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0))),
          ),
        ),
        const Text(
            'Registered phone number cannot be changed',
            style: TextStyle(
                fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 20),

        // WhatsApp Number
        const Text('WhatsApp Number',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextField(
          controller: _whatsappController,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            suffixIcon: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0))),
          ),
        ),
        const Text(
            'Defaults to your registered phone. You can update it anytime.',
            style: TextStyle(
                fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 20),

        // Email
        const Text('Email',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          readOnly: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            suffixIcon: const Icon(Icons.more_horiz_rounded,
                size: 18, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0))),
          ),
        ),
        const Text('Registered email cannot be changed',
            style: TextStyle(
                fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 32),
        const Divider(height: 1),
        const SizedBox(height: 24),

        // Location & Map Section
        Row(
          children: const [
            Icon(Icons.location_on_outlined,
                size: 18, color: Color(0xFF1A4FD6)),
            SizedBox(width: 8),
            Text('Store Location',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 16),

        // Map Box Container
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.map_rounded,
                        size: 44, color: Color(0xFF1A4FD6)),
                    SizedBox(height: 8),
                    Text(
                        "Tap 'Get Location' or drag the marker to set your shop address.",
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569))),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.near_me_rounded,
                      size: 16, color: Colors.white),
                  label: const Text('Get Location',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF1A4FD6),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Address
        const Text('Address',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFFCBD5E1))),
          ),
        ),
        const SizedBox(height: 16),

        // City & State Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text('City',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text('State',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _stateController,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // PIN Code
        const Text('PIN Code',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextField(
          controller: _pincodeController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFFCBD5E1))),
          ),
        ),
        const SizedBox(height: 20),

        // GPS Location Status Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('GPS Location',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
              SizedBox(height: 4),
              Text('No location captured yet',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabItem(_SettingsTab tab) {
    final isSel = _selectedTab == tab.slug;
    return Container(
      key: ValueKey('settings-tab-${tab.slug}'),
      margin: const EdgeInsets.only(bottom: 4),
      // The selected background lives on the Material rather than a plain
      // DecoratedBox, otherwise it hides the ListTile's own ink splashes.
      child: Material(
        color: isSel ? const Color(0xFFEEF2FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(tab.icon,
              size: 18,
              color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFF64748B)),
          title: Text(
            tab.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFF334155),
            ),
          ),
          trailing: tab.hasArrow
              ? const Icon(Icons.chevron_right_rounded,
                  size: 16, color: Color(0xFF94A3B8))
              : null,
          onTap: () => setState(() => _selectedTab = tab.slug),
        ),
      ),
    );
  }
}
