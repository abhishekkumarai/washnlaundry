import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../utils/navigation.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/status_pill.dart';
import '../widgets/load_state.dart';
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

  /// The list renders this many customers at a time, with a "Show more"
  /// button, so a shop with thousands of customers doesn't build every row at
  /// once. It resets to one page whenever the search or the tab filter changes.
  static const _pageSize = 50;
  int _visibleCount = _pageSize;

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
        'owing' => provider.deliveredDuesForCustomer(c) > 0,
        _ => true,
      };
      return matchesSearch && matchesTab;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (provider.hasError && provider.customers.isEmpty) {
              return ErrorState(
                statusCode: provider.error != null &&
                        provider.error!.contains('not found')
                    ? 404
                    : 500,
                title: 'Error loading customers',
                message: provider.error!,
                onRetry: () => provider.refresh(),
                onHome: () => context.goSection(0),
              );
            }
            if (provider.isLoading && provider.customers.isEmpty) {
              return const LoadingState();
            }

            final narrow =
                constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
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
                        _kpiRow(customers, provider),
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
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Row(
        children: [
          const Text('Customers',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
          const SizedBox(width: 8),
          Text('$total Total',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const Spacer(),
          SizedBox(
            width: 260,
            height: 38,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EFEA),
                borderRadius: BorderRadius.circular(10),
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
                        _visibleCount = _pageSize;
                      }),
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: 'Search by name, phone, or email...',
                        hintStyle:
                            TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _showAddCustomer,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF182C4F),
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
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
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
                        color: Color(0xFF141A24))),
              ),
              Text('$total Total',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 70,
                child: SizedBox(
                  height: 38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1EFEA),
                      borderRadius: BorderRadius.circular(10),
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
                              _visibleCount = _pageSize;
                            }),
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: 'Search by name, phone, or email...',
                              hintStyle: TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 30,
                child: SizedBox(
                  height: 38,
                  child: FilledButton(
                    onPressed: _showAddCustomer,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF182C4F),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Icon(Icons.add_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiRow(List<CustomerModel> customers, AppProvider provider) {
    // Counts always reflect every customer, not the tab-filtered subset —
    // otherwise selecting "Active" would immediately shrink its own count.
    final active = customers.where(_isActiveCustomer).length;
    final isNew = customers.where(_isNewCustomer).length;
    final totalDeliveredDues = provider.totalDeliveredDues;
    final owingCustomersCount = provider.customersWithDeliveredDuesCount;

    final cards = [
      (bool c) => _kpi('all', 'Total', '${customers.length}',
          Icons.people_outline_rounded, const Color(0xFF182C4F),
          compact: c),
      (bool c) => _kpi('active', 'Active', '$active',
          Icons.verified_user_outlined, const Color(0xFF10B981),
          compact: c),
      (bool c) => _kpi('new', 'New', '$isNew', Icons.person_add_alt_1_outlined,
          const Color(0xFF2563EB),
          compact: c),
      (bool c) => _kpi(
            'owing',
            'Amount Owed',
            '${Money.symbol}${totalDeliveredDues.toStringAsFixed(0)}',
            Icons.account_balance_wallet_outlined,
            const Color(0xFFDC2626),
            subtitle:
                owingCustomersCount > 0 ? '$owingCustomersCount owing' : null,
            compact: c,
          ),
    ];

    // The four cards hold one short figure each, so they always sit inline in
    // a single row; narrow screens get a compact card instead of wrapping.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final gap = compact ? 8.0 : 16.0;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: cards[i](compact)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// [tabKey] is one of 'all' / 'active' / 'new' / 'owing' — tapping a card makes it
  /// the active filter tab for the table below, same idea as the Orders
  /// screen's status chips.
  Widget _kpi(
      String tabKey, String label, String value, IconData icon, Color color,
      {String? subtitle, bool compact = false}) {
    final isSel = _kpiFilter == tabKey;
    return InkWell(
      onTap: () => setState(() {
        _kpiFilter = tabKey;
        _visibleCount = _pageSize;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSel ? color : const Color(0xFFE4E0D8),
              width: isSel ? 1.5 : 1),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF141A24))),
                  ),
                  if (subtitle != null)
                    Text(subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color)),
                ],
              )
            : Row(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B))),
                            if (subtitle != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(value,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF141A24))),
                      ],
                    ),
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
    final total = customers.length;
    if (total > _visibleCount) customers = customers.sublist(0, _visibleCount);
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
                'owing' => 'Customers with delivered dues',
                _ => 'All customers',
              },
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E0D8)),
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
                              'owing' => 'No customers with delivered dues.',
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
                      child: _customerCard(
                          c, _lastOrderFor(c, lastOrders), provider),
                    ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8F7F5),
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
            for (final c in customers)
              _row(c, _lastOrderFor(c, lastOrders), provider),
          ],
          if (total > customers.length) _showMoreBar(customers.length, total),
        ],
      ),
    );
  }

  /// Footer under a windowed list: how many are showing, and a button for
  /// the next page.
  Widget _showMoreBar(int shown, int total) {
    final totalPages = (total / _pageSize).ceil().clamp(1, 99999);
    final currentPage = (shown / _pageSize).ceil().clamp(1, totalPages);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Showing $shown of $total',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              if (totalPages > 1)
                Text('(Page $currentPage of $totalPages)',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (shown < total)
                OutlinedButton(
                  onPressed: () => setState(() => _visibleCount += _pageSize),
                  child: Text(
                      'Show ${total - shown < _pageSize ? total - shown : _pageSize} more'),
                ),
              if (shown > _pageSize) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _visibleCount = _pageSize),
                  child: const Text('Reset page'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Narrow-mode replacement for [_row]: the same 5 fixed-flex columns
  /// squeeze to unreadable slivers below [SidebarNavigation.contentWideBreakpoint], same bug class
  /// Orders' table had — stacks avatar/name/phone on top, the remaining
  /// fields as a 2-line summary below.
  Widget _customerCard(
      CustomerModel c, DateTime? lastOrder, AppProvider provider) {
    final dues = provider.deliveredDuesForCustomer(c);
    return InkWell(
      onTap: () => setState(() => _selected = c),
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
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF182C4F)),
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
                              color: Color(0xFF141A24))),
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
            if (dues > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Text(
                      'Delivered Due: ${Money.symbol}${dues.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1EFEA)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child:
                      _cardStat('Area', c.area.trim().isEmpty ? '—' : c.area),
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
                color: Color(0xFF141A24))),
      ],
    );
  }

  Widget _row(CustomerModel c, DateTime? lastOrder, AppProvider provider) {
    final dues = provider.deliveredDuesForCustomer(c);
    return InkWell(
      onTap: () => setState(() => _selected = c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF182C4F)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(c.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF141A24))),
                            ),
                            if (dues > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFFCA5A5)),
                                ),
                                child: Text(
                                  '${Money.symbol}${dues.toStringAsFixed(0)} due',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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
                      color: Color(0xFF141A24))),
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
                      size: 20, color: Color(0xFFD9D5CB)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCustomer() => _showCustomerDialog();

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
                    color: Color(0xFF141A24))),
            content: SizedBox(
              width: math.min(420.0, MediaQuery.sizeOf(ctx).width - 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('Full Name', nameController, 'e.g. Ramesh Kumar'),
                  _field(
                    'Phone Number (10 digits, no ISD code)',
                    phoneController,
                    '9876543210',
                    keyboard: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
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
                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                          setDialogState(() => error =
                              'Mobile number must be exactly 10 digits starting with 6-9 (no ISD / country code or leading 0).');
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
                  backgroundColor: const Color(0xFF182C4F),
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
                color: Color(0xFF141A24))),
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
    List<TextInputFormatter>? inputFormatters,
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
            inputFormatters: inputFormatters,
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
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFE4E0D8))),
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
