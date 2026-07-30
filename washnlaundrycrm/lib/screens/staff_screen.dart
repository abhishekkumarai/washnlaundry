import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  int _selectedTab = 0; // 0: Roster, 1: App Logins
  String _searchQuery = '';
  bool _showInactive = false;

  /// Roster view-models rebuilt from the provider on each build, so adds and
  /// edits reflect what the backend actually stored.
  List<Map<String, dynamic>> _staffMembers = const [];

  /// Team-login seats the current plan grants. Falls back to the Pro+ figure
  /// if the shop hasn't loaded yet.
  int _loginLimit = 4;

  void _syncFromProvider(AppProvider provider) {
    _staffMembers = provider.staff
        .map((s) => <String, dynamic>{
              'id': s.id,
              'name': s.name,
              'role': s.role,
              'phone': s.phone,
              'wage': s.dailyWage,
              'status': s.status,
              'isDriver': s.isDeliveryAgent,
              'hasAppLogin': s.hasAppLogin,
            })
        .toList();
    _loginLimit = (provider.shop?['team_login_limit'] as num?)?.toInt() ?? 4;
  }

  Future<void> _patchStaff(
    BuildContext context,
    Map<String, dynamic> member,
    Map<String, dynamic> changes,
    String successMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();
    final ok = await provider.updateStaff(member['id'] as String, changes);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok
            ? successMessage
            : 'Could not update ${member['name']}: ${provider.error ?? 'unknown error'}'),
        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFDC2626),
      ),
    );
  }

  /// Grant or revoke access to the Staff / Delivery Agent app, refusing to
  /// exceed the plan's seat count.
  Future<void> _toggleAppLogin(BuildContext context, Map<String, dynamic> member) async {
    final granting = !(member['hasAppLogin'] as bool);
    final used = _staffMembers.where((m) => m['hasAppLogin'] == true).length;

    if (granting && used >= _loginLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your plan includes $_loginLimit team logins. '
              'Revoke one or upgrade to add more.'),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
      return;
    }

    await _patchStaff(
      context,
      member,
      {'has_app_login': granting},
      granting
          ? 'App access granted to ${member['name']}'
          : 'App access revoked for ${member['name']}',
    );
  }

  Future<void> _toggleActive(BuildContext context, Map<String, dynamic> member) async {
    final activating = member['status'] != 'ACTIVE';
    await _patchStaff(
      context,
      member,
      {'status': activating ? 'ACTIVE' : 'INACTIVE'},
      activating
          ? '${member['name']} reactivated'
          : '${member['name']} marked inactive',
    );
  }

  List<Map<String, dynamic>> get _filteredStaff {
    return _staffMembers.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s['role'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s['phone'].toString().contains(_searchQuery);
      final matchesInactive = _showInactive || s['status'] == 'ACTIVE';
      return matchesSearch && matchesInactive;
    }).toList();
  }

  /// Add/edit dialog. Pass [existing] (a roster view-model) to edit that
  /// member; omit it to create a new one.
  void _showStaffModal(BuildContext context, {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] as String? ?? '');
    final roleCtrl = TextEditingController(text: existing?['role'] as String? ?? 'Washer');
    final wageCtrl = TextEditingController(
      text: ((existing?['wage'] as num?) ?? 600).toStringAsFixed(0),
    );
    bool isDeliveryAgent = (existing?['isDriver'] as bool?) ?? false;
    bool isActive = (existing?['status'] as String?) != 'INACTIVE';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isEdit ? 'Edit Staff Member' : 'Add Staff Member', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Full Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Ramesh Kumar',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Phone Number *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+91 98765 43210',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Role / Designation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: roleCtrl,
                              decoration: InputDecoration(
                                hintText: 'Head Washer / Ironer',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Daily Wage (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: wageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '600',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Checkbox(
                        value: isDeliveryAgent,
                        activeColor: const Color(0xFF1A4FD6),
                        onChanged: (v) => setModalState(() => isDeliveryAgent = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'Mark as Delivery Agent / Driver',
                          style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                  if (isEdit)
                    Row(
                      children: [
                        Checkbox(
                          value: isActive,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (v) => setModalState(() => isActive = v ?? true),
                        ),
                        const Expanded(
                          child: Text(
                            'Active — uncheck to remove from the roster',
                            style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final messenger = ScaffoldMessenger.of(context);
              final provider = context.read<AppProvider>();
              final payload = {
                'name': name,
                'role': roleCtrl.text.trim().isEmpty ? 'Washer' : roleCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'daily_wage': double.tryParse(wageCtrl.text) ?? 600.0,
                'is_delivery_agent': isDeliveryAgent,
                if (isEdit) 'status': isActive ? 'ACTIVE' : 'INACTIVE',
              };
              final ok = isEdit
                  ? await provider.updateStaff(existing['id'] as String, payload)
                  : await provider.addStaff({
                      ...payload,
                      'status': 'ACTIVE',
                      'has_app_login': false,
                    });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? (isEdit ? 'Updated "$name"' : 'Added staff member "$name"')
                      : 'Could not save "$name": ${provider.error ?? 'unknown error'}'),
                  backgroundColor:
                      ok ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isEdit ? 'Save Changes' : 'Add Staff', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncFromProvider(context.watch<AppProvider>());

    final activeCount = _staffMembers.where((s) => s['status'] == 'ACTIVE').length;
    final inactiveCount = _staffMembers.length - activeCount;
    final appLoginsCount = _staffMembers.where((s) => s['hasAppLogin'] == true).length;
    final driverCount = _staffMembers.where((s) => s['isDriver'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                // Header Bar
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Text('Staff', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      Text('${_staffMembers.length} members', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      const Spacer(),

                      // Search Box
                      Container(
                        width: 220,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search staff...',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      Row(
                        children: [
                          Checkbox(
                            value: _showInactive,
                            activeColor: const Color(0xFF1A4FD6),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) => setState(() => _showInactive = v ?? false),
                          ),
                          const Text('Show Inactive', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        ],
                      ),
                      const SizedBox(width: 14),

                      ElevatedButton.icon(
                        onPressed: () => _showStaffModal(context),
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text('+ Add Staff', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A4FD6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sub-Tabs Bar (Roster / App Logins)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      _buildSubTab(0, 'Roster'),
                      const SizedBox(width: 8),
                      _buildSubTab(1, 'App Logins'),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top 4 KPI Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                icon: Icons.people_outline_rounded,
                                iconBg: const Color(0xFFEEF2FF),
                                iconColor: const Color(0xFF1A4FD6),
                                val: '$activeCount',
                                label: 'Active staff',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiCard(
                                icon: Icons.person_off_outlined,
                                iconBg: const Color(0xFFF1F5F9),
                                iconColor: const Color(0xFF64748B),
                                val: '$inactiveCount',
                                label: 'Inactive',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiCard(
                                icon: Icons.smartphone_rounded,
                                iconBg: const Color(0xFFF3E8FF),
                                iconColor: const Color(0xFFA855F7),
                                val: '$appLoginsCount',
                                label: 'App logins · of $_loginLimit on plan',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiCard(
                                icon: Icons.location_on_outlined,
                                iconBg: const Color(0xFFE0F2FE),
                                iconColor: const Color(0xFF0284C7),
                                val: '$driverCount',
                                label: 'Delivery agents',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        if (_selectedTab == 1)
                          _buildAppLoginsTab(context)
                        else
                        // Staff Grid / List
                        _filteredStaff.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 60),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.people_outline_rounded, size: 36, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('No staff members found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 4),
                                    const Text('Add your first staff member to get started.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => _showStaffModal(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1A4FD6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    // Table Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(flex: 3, child: Text('STAFF MEMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 2, child: Text('ROLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 2, child: Text('PHONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 2, child: Text('DAILY WAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          SizedBox(width: 48),
                                        ],
                                      ),
                                    ),

                                    // Rows
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _filteredStaff.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final s = _filteredStaff[idx];
                                        final isActive = s['status'] == 'ACTIVE';

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                          child: Row(
                                            children: [
                                              // Member Name & Avatar
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 18,
                                                      backgroundColor: const Color(0xFFEEF2FF),
                                                      child: Text(
                                                        s['name'][0],
                                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(s['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                        if (s['isDriver'] == true)
                                                          const Text('Delivery Agent', style: TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Role
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                                  child: Text(s['role'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                                ),
                                              ),

                                              // Phone
                                              Expanded(
                                                flex: 2,
                                                child: Text(s['phone'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                              ),

                                              // Wage
                                              Expanded(
                                                flex: 2,
                                                child: Text('₹${(s['wage'] as double).toInt()} / day', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                              ),

                                              // Status Badge
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.circle, size: 6, color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                                      const SizedBox(width: 4),
                                                      Text(isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                                tooltip: 'Edit',
                                                onPressed: () => _showStaffModal(context, existing: s),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "App Logins" tab: who can sign into the Staff / Delivery Agent apps, and
  /// how many of the plan's seats that uses. Previously this tab rendered the
  /// roster verbatim, so it did nothing at all.
  Widget _buildAppLoginsTab(BuildContext context) {
    final withAccess = _staffMembers.where((m) => m['hasAppLogin'] == true).toList();
    final used = withAccess.length;
    final remaining = (_loginLimit - used).clamp(0, _loginLimit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seat usage
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Team logins',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Who can sign in to the Staff and Delivery Agent apps',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Text('$used of $_loginLimit used',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: remaining == 0 ? const Color(0xFFD97706) : const Color(0xFF0F172A),
                      )),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: _loginLimit == 0 ? 0 : used / _loginLimit,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation(
                    remaining == 0 ? const Color(0xFFD97706) : const Color(0xFF1A4FD6),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                remaining == 0
                    ? 'All seats in use. Revoke one to grant access to someone else.'
                    : '$remaining seat${remaining == 1 ? '' : 's'} remaining on your plan.',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Per-member access
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('STAFF MEMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                    Expanded(flex: 3, child: Text('APP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                    Expanded(flex: 2, child: Text('ACCESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                  ],
                ),
              ),
              if (_filteredStaff.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('No staff members found',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredStaff.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final member = _filteredStaff[idx];
                    final hasAccess = member['hasAppLogin'] == true;
                    final isAgent = member['isDriver'] == true;
                    final name = member['name'] as String;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFEEF2FF),
                                  child: Text(
                                    name.isEmpty ? '?' : name[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      Text(member['role'] as String,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Icon(
                                  isAgent ? Icons.local_shipping_outlined : Icons.point_of_sale_outlined,
                                  size: 15,
                                  color: const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    isAgent ? 'Delivery Agent app' : 'Staff app',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Switch(
                                  value: hasAccess,
                                  activeThumbColor: const Color(0xFF1A4FD6),
                                  onChanged: (_) => _toggleAppLogin(context, member),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasAccess ? 'Enabled' : 'No access',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: hasAccess ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTab(int idx, String title) {
    final isSel = _selectedTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFEEF2FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
            color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String val,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
