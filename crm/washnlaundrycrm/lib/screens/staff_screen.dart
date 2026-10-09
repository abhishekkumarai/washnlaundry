import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_shell.dart';
import '../widgets/error_dialog.dart';
import '../widgets/sidebar_navigation.dart';
import '../utils/money.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  int _selectedTab = 0; // 0: All Staff, 1: Active, 2: Inactive
  int _currentPage = 1;
  static const int _pageSize = 15;
  String _searchQuery = '';

  /// Column the table is sorted by (a roster view-model key), or null for the
  /// backend's own order. Tapping a header sorts by it ascending; tapping the
  /// same header again flips the direction.
  String? _sortKey;
  bool _sortAscending = true;

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
              'email': s.email,
              'wage': s.monthlyWage,
              'status': s.status,
              'hasAppLogin': s.hasAppLogin,
              'startDate': s.startDate,
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
    final rows = _staffMembers.where((s) {
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
        case 0: // All Staff
          matchesTab = true;
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
    // No column picked: keep the backend's own order.
    if (_sortKey != null) rows.sort(_compareRows);
    return rows;
  }

  int _compareRows(Map<String, dynamic> a, Map<String, dynamic> b) {
    final key = _sortKey!;
    final int result;
    if (key == 'wage') {
      result = (a['wage'] as num).compareTo(b['wage'] as num);
    } else {
      result = a[key]
          .toString()
          .toLowerCase()
          .compareTo(b[key].toString().toLowerCase());
    }
    // Ties fall back to name so equal wages/roles/statuses don't shuffle.
    final ordered = result != 0
        ? result
        : a['name'].toString().toLowerCase().compareTo(
            b['name'].toString().toLowerCase());
    return _sortAscending ? ordered : -ordered;
  }

  void _toggleSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
    });
  }

  /// A table header that sorts the roster by [key] when tapped, with an arrow
  /// showing the active column and direction.
  Widget _sortHeader(String label, String key) {
    final active = _sortKey == key;
    final color = active ? const Color(0xFF182C4F) : const Color(0xFF94A3B8);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        key: ValueKey('staff-sort-$key'),
        onTap: () => _toggleSort(key),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
              const SizedBox(width: 3),
              Icon(
                active
                    ? (_sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 12,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
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
    final emailCtrl =
        TextEditingController(text: existing?['email'] as String? ?? '');
    final roleCtrl = TextEditingController(
        text: existing?['role'] as String? ?? defaultRole);
    final wageCtrl = TextEditingController(
      text: ((existing?['wage'] as num?) ?? defaultWage).toStringAsFixed(0),
    );
    // Defaults to Inactive on add per shop requirements, or hydrated from existing status.
    bool isActive = isEdit ? ((existing['status'] as String?) != 'INACTIVE') : false;
    // New hires default to joining today — almost always right, and still
    // editable before saving. An edit leaves an already-unset date alone
    // rather than backfilling one that was never actually recorded.
    DateTime? startDate =
        existing?['startDate'] as DateTime? ?? (isEdit ? null : DateTime.now());

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
                    color: Color(0xFF141A24))),
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
                  const Text('Phone Number (10 digits only, no ISD code) *',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: '9876543210',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Sign-in email (Google)',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Leave blank for no CRM access',
                      helperText:
                          'Staff see orders, customers and scanning. Role '
                          '"Owner" or "Manager" sees everything.',
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
                  const Text('Start Date',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await AppDatePicker.pickDate(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2015),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setModalState(() => startDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_rounded,
                            size: 16, color: Color(0xFF182C4F)),
                        label: Text(
                          startDate == null
                              ? 'Not set'
                              : DateFormat('d MMM yyyy').format(startDate!),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF182C4F)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF182C4F)),
                          backgroundColor: const Color(0xFFEFF6FF),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (startDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Color(0xFF94A3B8)),
                          tooltip: 'Clear start date',
                          onPressed: () =>
                              setModalState(() => startDate = null),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Status',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => setModalState(() => isActive = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1EFEA),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD9D5CB),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isActive
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 16,
                                color: isActive
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '1. Active',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => setModalState(() => isActive = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: !isActive
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFF1EFEA),
                            border: Border.all(
                              color: !isActive
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD9D5CB),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                !isActive
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 16,
                                color: !isActive
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '2. Inactive',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: !isActive
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
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

              final phone = phoneCtrl.text.trim();
              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                await showErrorDialog(
                  ctx,
                  title: 'Invalid Mobile Number',
                  message: 'Mobile number must be exactly 10 digits starting with 6-9 (no ISD / country code or leading 0).',
                );
                return;
              }

              final messenger = ScaffoldMessenger.of(context);
              final provider = context.read<AppProvider>();
              final payload = {
                'name': name,
                'role': roleCtrl.text.trim().isEmpty
                    ? defaultRole
                    : roleCtrl.text.trim(),
                'phone': phone,
                'email': emailCtrl.text.trim().toLowerCase(),
                // A sign-in email is what grants CRM access (api/auth.py).
                'has_app_login': emailCtrl.text.trim().isNotEmpty,
                'monthly_wage': double.tryParse(wageCtrl.text) ?? defaultWage,
                // Sent explicitly (even as null) so clearing an already-set
                // date actually persists, not just skips the field.
                'start_date':
                    startDate == null ? null : AppProvider.dateKey(startDate!),
                'status': isActive ? 'ACTIVE' : 'INACTIVE',
              };
              final ok = isEdit
                  ? await provider.updateStaff(
                      existing['id'] as String, payload)
                  : await provider.addStaff({
                      ...payload,
                      'has_app_login': false,
                    });
              if (!ctx.mounted) return;
              if (ok) {
                Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(isEdit
                        ? 'Updated "$name"'
                        : 'Added staff member "$name"'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              } else {
                // The dialog used to close unconditionally here, discarding
                // whatever the user had typed, with only a SnackBar (easy to
                // miss, and gone once the dialog's gone) explaining why. A
                // popup instead — and the dialog stays open behind it — so
                // the failure is impossible to miss and nothing is lost.
                await showErrorDialog(
                  ctx,
                  title: 'Could not save "$name"',
                  message: provider.error ?? 'Unknown error.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF182C4F),
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
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return Column(
              children: [
                narrow ? _narrowHeaderBar() : _wideHeaderBar(),
                _subTabsBar(narrow),

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
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Row(
        children: [
          const Text('Staff',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_staffMembers.length} members',
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subTabsBar(bool narrow) {
    if (narrow) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < _subTabTitles.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _buildSubTab(i, _subTabTitles[i]),
              ],
            ],
          ),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: _searchField(),
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
              backgroundColor: const Color(0xFF182C4F),
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

  /// Below [SidebarNavigation.contentWideBreakpoint]: title+count+search+Add Staff no
  /// longer fit in one row even with the search box's own `Expanded`. Stacks
  /// title+count+icon-only Add, then a full-width search field.
  Widget _narrowHeaderBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
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
                      color: Color(0xFF141A24))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_staffMembers.length} members',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 70,
                child: _searchField(),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 30,
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _showStaffModal(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF182C4F),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.add, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F5),
        border: Border.all(color: const Color(0xFFE4E0D8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 18, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 1;
              }),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Search staff...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
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
                                  Border.all(color: const Color(0xFFE4E0D8)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1EFEA),
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
                                        color: Color(0xFF141A24))),
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
                                    backgroundColor: const Color(0xFF182C4F),
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
                        : Builder(
                            builder: (context) {
                              final totalCount = _filteredStaff.length;
                              final totalPages =
                                  (totalCount / _pageSize).ceil().clamp(1, 99999);
                              final safePage = _currentPage.clamp(1, totalPages);
                              final startIndex = (safePage - 1) * _pageSize;
                              final pagedStaff = totalCount > 0
                                  ? _filteredStaff
                                      .skip(startIndex)
                                      .take(_pageSize)
                                      .toList()
                                  : <Map<String, dynamic>>[];

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: const Color(0xFFE4E0D8)),
                                ),
                                child: Column(
                                  children: [
                                    narrow
                                        ? _staffCardList(pagedStaff)
                                        : Column(
                                            children: [
                                              // Table Header
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 14),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFF8F7F5),
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                          top: Radius.circular(
                                                              16)),
                                                  border: Border(
                                                      bottom: BorderSide(
                                                          color:
                                                              Color(0xFFE4E0D8))),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                        flex: 3,
                                                        child: _sortHeader(
                                                            'STAFF MEMBER',
                                                            'name')),
                                                    Expanded(
                                                        flex: 2,
                                                        child: _sortHeader(
                                                            'ROLE', 'role')),
                                                    Expanded(
                                                        flex: 2,
                                                        child: _sortHeader(
                                                            'PHONE', 'phone')),
                                                    Expanded(
                                                        flex: 2,
                                                        child: _sortHeader(
                                                            'MONTHLY WAGE',
                                                            'wage')),
                                                    Expanded(
                                                        flex: 3,
                                                        child: _sortHeader(
                                                            'STATUS',
                                                            'status')),
                                                    const SizedBox(width: 48),
                                                  ],
                                                ),
                                              ),

                                              // Rows
                                              ListView.separated(
                                                shrinkWrap: true,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                itemCount: pagedStaff.length,
                                                separatorBuilder: (_, __) =>
                                                    const Divider(height: 1),
                                                itemBuilder: (context, idx) {
                                                  final s = pagedStaff[idx];
                                                  final isActive =
                                                      s['status'] == 'ACTIVE';
                                                  final name =
                                                      s['name'] as String;
                                                  final isLast = idx ==
                                                      pagedStaff.length - 1;

                                    // The whole row opens the edit sheet —
                                    // previously only the pencil responded,
                                    // so most of the table looked dead.
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _showStaffModal(context,
                                            existing: s),
                                        hoverColor: const Color(0xFFF8F7F5),
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
                                                              0xFFEFF6FF)
                                                          : const Color(
                                                              0xFFF1EFEA),
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
                                                                  0xFF182C4F)
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
                                                                    0xFF141A24)),
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
                                                            0xFFF1EFEA),
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
                                                      color: Color(0xFF141A24)),
                                                ),
                                              ),

                                              // Status toggle switch (Active / Inactive)
                                              Expanded(
                                                flex: 3,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: _buildStatusToggle(
                                                      context, s),
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
                            _staffFooter(totalCount, startIndex,
                                pagedStaff.length, safePage, totalPages),
                          ],
                        ),
                      );
                    },
                  );
  }

  /// Narrow-mode replacement for the table: the same 5 fixed-flex columns
  /// squeeze to unreadable slivers below [SidebarNavigation.contentWideBreakpoint], same bug class
  /// Orders' table had.
  Widget _staffCardList(List<Map<String, dynamic>> staffList) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final s in staffList)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _staffCard(s),
            ),
        ],
      ),
    );
  }

  Widget _staffFooter(int totalCount, int startIndex, int pagedCount,
      int safePage, int totalPages) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Text(
            totalCount == 0
                ? 'Showing 0 staff'
                : 'Showing ${startIndex + 1}–${math.min(startIndex + pagedCount, totalCount)} of $totalCount',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          if (totalPages > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  iconSize: 20,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: safePage > 1
                      ? () => setState(() => _currentPage = safePage - 1)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'Page $safePage of $totalPages',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF141A24)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  iconSize: 20,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: safePage < totalPages
                      ? () => setState(() => _currentPage = safePage + 1)
                      : null,
                ),
              ],
            )
          else
            const Text('Page 1 of 1',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // Status column control: one switch that flips the member between Active
  // and Inactive through the same _toggleActive path the row menu uses.
  Widget _buildStatusToggle(
      BuildContext context, Map<String, dynamic> member) {
    final isActive = member['status'] == 'ACTIVE';
    final name = member['name'] as String;
    return Tooltip(
      message: isActive ? 'Mark $name inactive' : 'Reactivate $name',
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: isActive,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF10B981),
                // Off is faded (same as the app theme's switches).
                inactiveThumbColor: Colors.white.withValues(alpha: 0.7),
                inactiveTrackColor:
                    const Color(0xFFD9D5CB).withValues(alpha: 0.6),
                trackOutlineColor:
                    WidgetStateProperty.all(Colors.transparent),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (_) => _toggleActive(context, member),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
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
          border: Border.all(color: const Color(0xFFE4E0D8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isActive
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF1EFEA),
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? const Color(0xFF182C4F)
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
                              color: Color(0xFF141A24))),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1EFEA),
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
            const Divider(height: 1, color: Color(0xFFF1EFEA)),
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
            _buildStatusToggle(context, s),
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
                color: Color(0xFF141A24))),
      ],
    );
  }

  Widget _buildSubTab(int idx, String title) {
    final isSel = _selectedTab == idx;
    // InkWell, not GestureDetector — the latter gives no pointer cursor or
    // hover feedback on web, so the tabs read as static labels.
    return Material(
      // Keyed because the Status column's switch labels reuse the same
      // "Active"/"Inactive" text, so text alone can't pick out a tab.
      key: ValueKey('staff-subtab-$title'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _selectedTab = idx;
          _currentPage = 1;
        }),
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0xFFEFF6FF),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    isSel ? const Color(0xFF182C4F) : const Color(0xFFE4E0D8)),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
              color: isSel ? const Color(0xFF182C4F) : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}
