import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../utils/csv.dart';
import '../utils/csv_download.dart';
import '../utils/navigation.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/status_pill.dart';
import 'customer_detail_screen.dart';
import '../utils/money.dart';

/// `/customers` in the live app — see LIVE_AUDIT.md "Customers".
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _searchQuery = '';
  CustomerModel? _selected;

  /// Which KPI card is acting as the active filter tab. 'all' means no
  /// extra filter beyond the search box.
  String _kpiFilter = 'all';

  /// Most recent order date per customer, keyed by both id and phone so a
  /// counter order written without a customer FK still matches on phone.
  Map<String, DateTime> _lastOrderIndex(AppProvider provider) {
    final index = <String, DateTime>{};
    void put(String key, DateTime when) {
      if (key.isEmpty) return;
      final existing = index[key];
      if (existing == null || when.isAfter(existing)) index[key] = when;
    }

    for (final o in provider.orders) {
      put(o.customerId, o.createdAt);
      put(o.customerPhone, o.createdAt);
    }
    return index;
  }

  DateTime? _lastOrderFor(CustomerModel c, Map<String, DateTime> index) =>
      index[c.id] ?? index[c.phone];

  bool _isActiveCustomer(CustomerModel c) => c.totalOrders > 0;

  bool _isNewCustomer(CustomerModel c) {
    final at = c.createdAt;
    if (at == null) return false;
    final now = DateTime.now();
    return at.year == now.year && at.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return CustomerDetailScreen(
        customer: _selected!,
        onBack: () => setState(() => _selected = null),
        onNewOrder: () {
          setState(() => _selected = null);
          context.goSection(1);
        },
      );
    }

    final provider = context.watch<AppProvider>();
    final customers = provider.customers;
    final lastOrders = _lastOrderIndex(provider);

    final q = _searchQuery.trim().toLowerCase();
    final filtered = customers.where((c) {
      final matchesSearch = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.area.toLowerCase().contains(q);
      final matchesTab = switch (_kpiFilter) {
        'active' => _isActiveCustomer(c),
        'new' => _isNewCustomer(c),
        _ => true,
      };
      return matchesSearch && matchesTab;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return Column(
              children: [
                narrow
                    ? _narrowHeader(context, customers.length, filtered)
                    : _header(context, customers.length, filtered),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kpiRow(customers),
                        const SizedBox(height: 20),
                        _table(filtered, lastOrders, provider, narrow),
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

  Widget _header(
      BuildContext context, int total, List<CustomerModel> filtered) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Text('Customers',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(width: 8),
          Text('$total Total',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const Spacer(),
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or email...',
                hintStyle:
                    const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton.icon(
            onPressed: () => _exportCustomersCsv(filtered),
            icon: const Icon(Icons.download_rounded,
                size: 16, color: Color(0xFF475569)),
            label: const Text('Export',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _showAddCustomer,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Below [SidebarNavigation.contentWideBreakpoint]: the fixed 260px search box, title, and 2
  /// buttons no longer fit in one row. Stacks title+icon-only Add, then a
  /// full-width search field, then Export on its own row (only one
  /// secondary action, so no need for a scrollable filter row like Orders').
  Widget _narrowHeader(
      BuildContext context, int total, List<CustomerModel> filtered) {
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
              const Expanded(
                child: Text('Customers',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
              ),
              Text('$total Total',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              const SizedBox(width: 8),
              SizedBox(
                width: 38,
                height: 38,
                child: FilledButton(
                  onPressed: _showAddCustomer,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A4FD6),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.add_rounded, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or email...',
                hintStyle:
                    const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _exportCustomersCsv(filtered),
            icon: const Icon(Icons.download_rounded,
                size: 16, color: Color(0xFF475569)),
            label: const Text('Export',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiRow(List<CustomerModel> customers) {
    // Counts always reflect every customer, not the tab-filtered subset —
    // otherwise selecting "Active" would immediately shrink its own count.
    final active = customers.where(_isActiveCustomer).length;
    final isNew = customers.where(_isNewCustomer).length;

    final cards = [
      _kpi('all', 'Total', '${customers.length}', Icons.people_outline_rounded,
          const Color(0xFF1A4FD6)),
      _kpi('active', 'Active', '$active', Icons.verified_user_outlined,
          const Color(0xFF10B981)),
      _kpi('new', 'New', '$isNew', Icons.person_add_alt_1_outlined,
          const Color(0xFFA855F7)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth < 640 ? 1 : 3;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in cards) SizedBox(width: width, child: c)],
        );
      },
    );
  }

  /// [tabKey] is one of 'all' / 'active' / 'new' — tapping a card makes it
  /// the active filter tab for the table below, same idea as the Orders
  /// screen's status chips.
  Widget _kpi(
      String tabKey, String label, String value, IconData icon, Color color) {
    final isSel = _kpiFilter == tabKey;
    return InkWell(
      onTap: () => setState(() => _kpiFilter = tabKey),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSel ? color : const Color(0xFFE2E8F0),
              width: isSel ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _table(
    List<CustomerModel> customers,
    Map<String, DateTime> lastOrders,
    AppProvider provider,
    bool narrow,
  ) {
    return Container(
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              switch (_kpiFilter) {
                'active' => 'Active customers',
                'new' => 'New customers',
                _ => 'All customers',
              },
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (customers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  provider.isLoading
                      ? 'Loading customers…'
                      : _searchQuery.trim().isNotEmpty
                          ? 'No customer matches "${_searchQuery.trim()}".'
                          : switch (_kpiFilter) {
                              'active' => 'No active customers yet.',
                              'new' => 'No new customers this month.',
                              _ => 'No customers yet. Add one to get started.',
                            },
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else if (narrow)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final c in customers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _customerCard(c, _lastOrderFor(c, lastOrders)),
                    ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: const Row(
                children: [
                  Expanded(flex: 4, child: _ColHead('CUSTOMER')),
                  Expanded(flex: 3, child: _ColHead('AREA')),
                  Expanded(flex: 2, child: _ColHead('ORDERS')),
                  Expanded(flex: 2, child: _ColHead('LIFETIME')),
                  Expanded(flex: 3, child: _ColHead('LAST ORDER')),
                  SizedBox(width: 68),
                ],
              ),
            ),
            for (final c in customers) _row(c, _lastOrderFor(c, lastOrders)),
          ],
        ],
      ),
    );
  }

  /// Narrow-mode replacement for [_row]: the same 5 fixed-flex columns
  /// squeeze to unreadable slivers below [SidebarNavigation.contentWideBreakpoint], same bug class
  /// Orders' table had — stacks avatar/name/phone on top, the remaining
  /// fields as a 2-line summary below.
  Widget _customerCard(CustomerModel c, DateTime? lastOrder) {
    return InkWell(
      onTap: () => setState(() => _selected = c),
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
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A4FD6)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A))),
                      Text(c.phone.isEmpty ? '—' : c.phone,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 20, color: Color(0xFF94A3B8)),
                  tooltip: 'Customer options',
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showCustomerDialog(existing: c);
                    } else if (action == 'delete') {
                      _showDeleteCustomerConfirm(c);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 15, color: Color(0xFF64748B)),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 15, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _cardStat('Area', c.area.trim().isEmpty ? '—' : c.area),
                ),
                Expanded(
                  child: _cardStat('Orders', '${c.totalOrders}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _cardStat('Lifetime',
                      '${Money.symbol}${c.totalSpent.toStringAsFixed(0)}'),
                ),
                Expanded(
                  child: _cardStat('Last Order',
                      lastOrder == null ? '—' : relativeTime(lastOrder)),
                ),
              ],
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

  Widget _row(CustomerModel c, DateTime? lastOrder) {
    return InkWell(
      onTap: () => setState(() => _selected = c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A4FD6)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A))),
                        Text(c.phone.isEmpty ? '—' : c.phone,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(c.area.trim().isEmpty ? '—' : c.area,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            ),
            Expanded(
              flex: 2,
              child: Text('${c.totalOrders}',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            ),
            Expanded(
              flex: 2,
              child: Text('${Money.symbol}${c.totalSpent.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
            ),
            Expanded(
              flex: 3,
              child: Text(lastOrder == null ? '—' : relativeTime(lastOrder),
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            ),
            SizedBox(
              width: 68,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Customer options',
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _showCustomerDialog(existing: c);
                      } else if (action == 'delete') {
                        _showDeleteCustomerConfirm(c);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 15, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Text('Edit', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 15, color: Color(0xFFDC2626)),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: Color(0xFFCBD5E1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCustomer() => _showCustomerDialog();

  /// Exports exactly what's on screen — the currently searched/tab-filtered
  /// rows, not the whole customer list — same convention as Orders' Export.
  void _exportCustomersCsv(List<CustomerModel> customers) {
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers to export.')),
      );
      return;
    }

    final rows = <List<Object?>>[
      const [
        'Name',
        'Phone',
        'Email',
        'Address',
        'Area',
        'Total Orders',
        'Total Spent',
        'Due Amount',
        'Avg Order Value',
        'Customer Since',
      ],
      for (final c in customers)
        [
          c.name,
          c.phone,
          c.email,
          c.address,
          c.area,
          c.totalOrders,
          c.totalSpent,
          c.dueAmount,
          c.avgOrderValue,
          c.createdAt == null
              ? ''
              : DateFormat('yyyy-MM-dd').format(c.createdAt!),
        ],
    ];

    final filename =
        'customers_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final ok = downloadCsv(filename, buildCsv(rows));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export is only available in the web app.')),
      );
    }
  }

  /// [existing] null adds a customer; non-null edits it in place. Same dialog
  /// either way — only the title, button label, and which provider call fires
  /// differ, the same shape `staff_screen.dart`'s `_showStaffModal` uses.
  ///
  /// Takes no `BuildContext`: a parameter of that name would shadow
  /// `State.context`, and then the `mounted` check below would be guarding a
  /// different context than the one the snackbar uses.
  Future<void> _showCustomerDialog({CustomerModel? existing}) async {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final areaController = TextEditingController(text: existing?.area ?? '');
    final provider = context.read<AppProvider>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        bool saving = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEdit ? 'Edit Customer' : 'Add Customer',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            content: SizedBox(
              width: math.min(420.0, MediaQuery.sizeOf(ctx).width - 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('Full Name', nameController, 'e.g. Ramesh Kumar'),
                  _field('Phone Number', phoneController, '+919876543210',
                      keyboard: TextInputType.phone),
                  _field('Email', emailController, 'name@example.com',
                      keyboard: TextInputType.emailAddress),
                  _field('Area / Locality', areaController,
                      'e.g. HBR Layout, Bengaluru'),
                  if (error != null) ...[
                    const SizedBox(height: 6),
                    Text(error!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFDC2626))),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final phone = phoneController.text.trim();
                        if (name.isEmpty || phone.isEmpty) {
                          setDialogState(() =>
                              error = 'Name and phone are both required.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        final payload = {
                          'name': name,
                          'phone': phone,
                          'email': emailController.text.trim(),
                          'area': areaController.text.trim(),
                        };
                        final ok = isEdit
                            ? await provider.updateCustomer(
                                existing.id, payload)
                            : await provider.addCustomer(payload);
                        if (!ctx.mounted) return;
                        if (ok) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            saving = false;
                            error = provider.error ??
                                'Could not ${isEdit ? 'save' : 'add'} the customer.';
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4FD6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  saving
                      ? 'Saving…'
                      : (isEdit ? 'Save Changes' : 'Add Customer'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isEdit ? 'Customer updated.' : 'Customer added.')),
      );
    }
  }

  Future<void> _showDeleteCustomerConfirm(CustomerModel c) async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Customer',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
        content: Text(
          'Are you sure you want to delete "${c.name}"? Their past orders keep '
          'their own record of the name and phone number, but the link to this '
          'customer will be gone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await provider.deleteCustomer(c.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Deleted "${c.name}".'
            : (provider.error ?? 'Could not delete the customer.')),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

const BoxDecoration _panel = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
);

class _ColHead extends StatelessWidget {
  final String text;

  const _ColHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        color: Color(0xFF64748B),
      ),
    );
  }
}
