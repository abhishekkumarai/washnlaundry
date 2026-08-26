import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';
import '../utils/money.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  int _selectedTab = 0; // 0: All Staff, 1: Active, 2: Inactive
  String _searchQuery = '';
  bool _showInactive = false;

  static const _subTabTitles = ['All Staff', 'Active', 'Inactive'];

  /// Roster view-models rebuilt from the provider on each build, so adds and
  /// edits reflect what the backend actually stored.
  List<Map<String, dynamic>> _staffMembers = const [];

  void _syncFromProvider(AppProvider provider) {
    _staffMembers = provider.staff
        .map((s) => <String, dynamic>{
              'id': s.id,
              'name': s.name,
              'role': s.role,
              'phone': s.phone,
              'wage': s.monthlyWage,
              'status': s.status,
              'hasAppLogin': s.hasAppLogin,
            })
        .toList();
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

  Future<void> _toggleActive(
      BuildContext context, Map<String, dynamic> member) async {
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
          s['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          s['role']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          s['phone'].toString().contains(_searchQuery);

      bool matchesTab = true;
      switch (_selectedTab) {
        case 0: // Roster / All
          matchesTab = _showInactive || s['status'] == 'ACTIVE';
          break;
        case 1: // Active
          matchesTab = s['status'] == 'ACTIVE';
          break;
        case 2: // Inactive
          matchesTab = s['status'] != 'ACTIVE';
          break;
      }
      return matchesSearch && matchesTab;
    }).toList();
  }

  /// Add/edit dialog. Pass [existing] (a roster view-model) to edit that
  /// member; omit it to create a new one.
  void _showStaffModal(BuildContext context, {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    // The new-hire defaults are shop policy — they used to be a hardcoded
    // 'Washer' and 600 here, so every shop opened this form on ours.
    final shopDefaults = context.read<AppProvider>();
    final defaultRole = shopDefaults.defaultStaffRole;
    final defaultWage = shopDefaults.defaultMonthlyWage;

    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?['phone'] as String? ?? '');
    final roleCtrl = TextEditingController(
        text: existing?['role'] as String? ?? defaultRole);
    final wageCtrl = TextEditingController(
      text: ((existing?['wage'] as num?) ?? defaultWage).toStringAsFixed(0),
    );
    bool isActive = (existing?['status'] as String?) != 'INACTIVE';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isEdit ? 'Edit Staff Member' : 'Add Staff Member',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 20, color: Color(0xFF94A3B8)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: math.min(420.0, MediaQuery.sizeOf(ctx).width - 48),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Full Name *',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Ramesh Kumar',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Phone Number *',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+91 98765 43210',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Role / Designation',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: roleCtrl,
                              decoration: InputDecoration(
                                hintText: 'Head Washer / Ironer',
                                hintStyle: const TextStyle(
                                    fontSize: 13, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
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
                            Text('Monthly Wage (${Money.symbol})',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: wageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: defaultWage.toStringAsFixed(0),
                                hintStyle: const TextStyle(
                                    fontSize: 13, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isEdit)
                    Row(
                      children: [
                        Checkbox(
                          value: isActive,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (v) =>
                              setModalState(() => isActive = v ?? true),
                        ),
                        const Expanded(
                          child: Text(
                            'Active — uncheck to remove from the roster',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF334155)),
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
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final messenger = ScaffoldMessenger.of(context);
              final provider = context.read<AppProvider>();
              final payload = {
                'name': name,
                'role': roleCtrl.text.trim().isEmpty
                    ? defaultRole
                    : roleCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'monthly_wage': double.tryParse(wageCtrl.text) ?? defaultWage,
                if (isEdit) 'status': isActive ? 'ACTIVE' : 'INACTIVE',
              };
              final ok = isEdit
                  ? await provider.updateStaff(
                      existing['id'] as String, payload)
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
                      ? (isEdit
                          ? 'Updated "$name"'
                          : 'Added staff member "$name"')
                      : 'Could not save "$name": ${provider.error ?? 'unknown error'}'),
                  backgroundColor:
                      ok ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isEdit ? 'Save Changes' : 'Add Staff',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncFromProvider(context.watch<AppProvider>());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return Column(
              children: [
                narrow ? _narrowHeaderBar() : _wideHeaderBar(),

                // Sub-Tabs Bar (All Staff / Active / Inactive)
                //
                // ListView, not SingleChildScrollView(child: Row(...)): inside a
                // horizontal scroll view a Row gets an unbounded max-width
                // constraint and shrink-wraps to its content, and the parent
                // Column's default CrossAxisAlignment.center then centers that
                // narrow box — producing a large blank gap before "All Staff".
                // ListView's RenderViewport always fills the available width
                // instead, which is why orders_screen.dart's filter-chip row
                // uses the same pattern.
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _subTabTitles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) =>
                          _buildSubTab(i, _subTabTitles[i]),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _staffList(narrow),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _wideHeaderBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Text('Staff',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_staffMembers.length} members',
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(width: 16),

          // Search Box — flexes so the header can't overflow on a
          // narrow window; the fixed 220px version used to push the
          // Add Staff button off the edge.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: _searchField(),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // The label is part of the hit target, not just the box.
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _showInactive = !_showInactive),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _showInactive,
                    activeColor: const Color(0xFF1A4FD6),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) =>
                        setState(() => _showInactive = v ?? false),
                  ),
                  const SizedBox(width: 6),
                  const Text('Show Inactive',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF475569))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          ElevatedButton.icon(
            onPressed: () => _showStaffModal(context),
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text('Add Staff',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Below [SidebarNavigation.contentWideBreakpoint]: title+count+search+"Show Inactive"+Add Staff no
  /// longer fit in one row even with the search box's own `Expanded`. Stacks
  /// title+count+icon-only Add, then a full-width search field, then "Show
  /// Inactive" on its own row (it fits alone at phone width).
  Widget _narrowHeaderBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Staff',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_staffMembers.length} members',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
              SizedBox(
                width: 38,
                height: 38,
                child: ElevatedButton(
                  onPressed: () => _showStaffModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A4FD6),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Icon(Icons.add, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _searchField(),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _showInactive = !_showInactive),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _showInactive,
                  activeColor: const Color(0xFF1A4FD6),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) =>
                      setState(() => _showInactive = v ?? false),
                ),
                const SizedBox(width: 6),
                const Text('Show Inactive',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
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
          prefixIcon:
              Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 9),
        ),
      ),
    );
  }

  Widget _staffList(bool narrow) {
    return _filteredStaff.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_rounded,
                                      size: 36, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 16),
                                const Text('No staff members found',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                const Text(
                                    'Add your first staff member to get started.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _showStaffModal(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A4FD6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Add Staff',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: narrow
                                ? _staffCardList()
                                : Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Color(0xFFE2E8F0))),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                          flex: 3,
                                          child: Text('STAFF MEMBER',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8)))),
                                      Expanded(
                                          flex: 2,
                                          child: Text('ROLE',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8)))),
                                      Expanded(
                                          flex: 2,
                                          child: Text('PHONE',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8)))),
                                      Expanded(
                                          flex: 2,
                                          child: Text('MONTHLY WAGE',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8)))),
                                      Expanded(
                                          flex: 2,
                                          child: Text('STATUS',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8)))),
                                      SizedBox(width: 48),
                                    ],
                                  ),
                                ),

                                // Rows
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredStaff.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, idx) {
                                    final s = _filteredStaff[idx];
                                    final isActive = s['status'] == 'ACTIVE';
                                    final name = s['name'] as String;
                                    final isLast =
                                        idx == _filteredStaff.length - 1;

                                    // The whole row opens the edit sheet —
                                    // previously only the pencil responded,
                                    // so most of the table looked dead.
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _showStaffModal(context,
                                            existing: s),
                                        hoverColor: const Color(0xFFF8FAFC),
                                        borderRadius: isLast
                                            ? const BorderRadius.vertical(
                                                bottom: Radius.circular(16))
                                            : BorderRadius.zero,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 14),
                                          child: Row(
                                            children: [
                                              // Member Name & Avatar
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 18,
                                                      backgroundColor: isActive
                                                          ? const Color(
                                                              0xFFEEF2FF)
                                                          : const Color(
                                                              0xFFF1F5F9),
                                                      child: Text(
                                                        name.isEmpty
                                                            ? '?'
                                                            : name[0]
                                                                .toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFF1A4FD6)
                                                              : const Color(
                                                                  0xFF94A3B8),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            name,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                    0xFF0F172A)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Role — Align keeps the pill
                                              // hugging its label instead of
                                              // painting across the column.
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFF1F5F9),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6)),
                                                    child: Text(
                                                      s['role'] as String,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF475569)),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Phone
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  s['phone'] as String,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF64748B)),
                                                ),
                                              ),

                                              // Wage
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '${Money.symbol}${(s['wage'] as num).toInt()} / month',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF0F172A)),
                                                ),
                                              ),

                                              // Status Badge — also Align'd,
                                              // and now the control that
                                              // actually flips the status.
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Tooltip(
                                                    message: isActive
                                                        ? 'Mark $name inactive'
                                                        : 'Reactivate $name',
                                                    child: InkWell(
                                                      onTap: () =>
                                                          _toggleActive(
                                                              context, s),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 5),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFFECFDF5)
                                                              : const Color(
                                                                  0xFFFEF2F2),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.circle,
                                                                size: 6,
                                                                color: isActive
                                                                    ? const Color(
                                                                        0xFF10B981)
                                                                    : const Color(
                                                                        0xFFEF4444)),
                                                            const SizedBox(
                                                                width: 5),
                                                            Flexible(
                                                              child: Text(
                                                                isActive
                                                                    ? 'Active'
                                                                    : 'Inactive',
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: isActive
                                                                        ? const Color(
                                                                            0xFF10B981)
                                                                        : const Color(
                                                                            0xFFEF4444)),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              SizedBox(
                                                width: 48,
                                                child: PopupMenuButton<String>(
                                                  icon: const Icon(
                                                      Icons.more_horiz_rounded,
                                                      size: 18,
                                                      color: Color(0xFF64748B)),
                                                  tooltip: 'Actions',
                                                  splashRadius: 18,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10)),
                                                  onSelected: (value) {
                                                    if (value == 'edit') {
                                                      _showStaffModal(context,
                                                          existing: s);
                                                    } else if (value ==
                                                        'status') {
                                                      _toggleActive(context, s);
                                                    }
                                                  },
                                                  itemBuilder: (_) => [
                                                    const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              size: 16,
                                                              color: Color(
                                                                  0xFF64748B)),
                                                          SizedBox(width: 10),
                                                          Text('Edit details',
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      13)),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'status',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            isActive
                                                                ? Icons
                                                                    .person_off_outlined
                                                                : Icons
                                                                    .person_outline,
                                                            size: 16,
                                                            color: const Color(
                                                                0xFF64748B),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          Text(
                                                              isActive
                                                                  ? 'Mark inactive'
                                                                  : 'Reactivate',
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          13)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
  }

  /// Narrow-mode replacement for the table: the same 5 fixed-flex columns
  /// squeeze to unreadable slivers below [SidebarNavigation.contentWideBreakpoint], same bug class
  /// Orders' table had.
  Widget _staffCardList() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final s in _filteredStaff)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _staffCard(s),
            ),
        ],
      ),
    );
  }

  Widget _staffCard(Map<String, dynamic> s) {
    final isActive = s['status'] == 'ACTIVE';
    final name = s['name'] as String;
    return InkWell(
      onTap: () => _showStaffModal(context, existing: s),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isActive
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF1F5F9),
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? const Color(0xFF1A4FD6)
                            : const Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A))),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s['role'] as String,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded,
                        size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Actions',
                    splashRadius: 18,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showStaffModal(context, existing: s);
                      } else if (value == 'status') {
                        _toggleActive(context, s);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 10),
                            Text('Edit details', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.person_off_outlined
                                  : Icons.person_outline,
                              size: 16,
                              color: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 10),
                            Text(isActive ? 'Mark inactive' : 'Reactivate',
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _cardStat('Phone', s['phone'] as String)),
                Expanded(
                    child: _cardStat('Wage',
                        '${Money.symbol}${(s['wage'] as num).toInt()} / month')),
              ],
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: isActive ? 'Mark $name inactive' : 'Reactivate $name',
              child: InkWell(
                onTap: () => _toggleActive(context, s),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle,
                          size: 6,
                          color: isActive
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444)),
                      const SizedBox(width: 5),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildSubTab(int idx, String title) {
    final isSel = _selectedTab == idx;
    // InkWell, not GestureDetector — the latter gives no pointer cursor or
    // hover feedback on web, so the tabs read as static labels.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = idx),
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0xFFEEF2FF),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFEEF2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
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
      ),
    );
  }
}
