import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/role_views.dart';
import '../models/order_model.dart';
import '../utils/navigation.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_shell.dart';
import '../widgets/order_calendar_heatmap.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/status_pill.dart';
import '../widgets/load_state.dart';
import '../utils/money.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedTab = 'All';
  int _currentPage = 1;
  static const int _pageSize = 15;
  OrderDateRange _timeFilter = OrderDateRange.allTime;

  /// Set when the user picks "Custom range..." from the date menu. Takes
  /// over from [_timeFilter] (which is forced back to [OrderDateRange.allTime]
  /// whenever this is non-null) rather than living inside the enum, since a
  /// custom range carries data the enum's fixed presets don't.
  DateTimeRange? _customRange;

  String _searchQuery = '';

  /// Extra dimensions the status chips and date dropdown don't cover — the
  /// "Filters" button used to be `onPressed: () {}`. Mirrors the real app's
  /// own "Filter Orders" dialog: Attention Needed, Order Source, Order
  /// Type, Service type, Status (Status writes back into [_selectedTab]
  /// rather than forking a second copy of the same state).
  bool _overdueOnly = false;
  bool _unpaidDuesOnly = false;

  /// 'all' / 'online' / 'inshop'.
  String _orderSource = 'all';

  /// One of [DeliveryType]'s values, or null for "All Types". Excludes
  /// `online` — the real dialog puts that under Order Source instead.
  String? _orderType;

  /// A category name from Services, or null for "All service types".
  String? _serviceType;

  int get _extraFilterCount =>
      (_overdueOnly ? 1 : 0) +
      (_unpaidDuesOnly ? 1 : 0) +
      (_orderSource != 'all' ? 1 : 0) +
      (_orderType != null ? 1 : 0) +
      (_serviceType != null ? 1 : 0);

  /// The live app's 11 chips. 'key' is what the provider filters on — every
  /// chip must map to one, or it silently falls through and shows every order.
  static const List<Map<String, String>> _tabs = [
    {'label': 'All', 'key': 'ALL'},
    {'label': 'Placed', 'key': OrderStatus.placed},
    {'label': 'Processing', 'key': OrderStatus.processing},
    {'label': 'Ready', 'key': OrderStatus.ready},
    {'label': 'Out for delivery', 'key': OrderStatus.outForDelivery},
    {'label': 'Partial', 'key': 'PARTIAL'},
    {'label': 'Delivered', 'key': OrderStatus.delivered},
    {'label': 'Cancelled', 'key': OrderStatus.cancelled},
    {'label': 'Overdue Orders', 'key': 'OVERDUE'},
    {'label': 'Scheduled', 'key': 'SCHEDULED'},
    {'label': 'Unpaid Dues', 'key': 'UNPAID'},
  ];

  static Color _tabColor(String key) {
    switch (key) {
      case 'ALL':
        return const Color(0xFF182C4F);
      case 'PARTIAL':
        return const Color(0xFFD97706);
      case 'OVERDUE':
        return const Color(0xFFDC2626);
      case 'SCHEDULED':
        return const Color(0xFF2563EB);
      case 'UNPAID':
        return const Color(0xFFEA580C);
      default:
        return statusColor(key);
    }
  }

  /// True when any of the three controls is narrowing the list — including the
  /// date range, which decides whether "no orders" means "empty shop" or
  /// "nothing matched".
  bool get _hasActiveFilter =>
      _selectedTab != 'All' ||
      _searchQuery.isNotEmpty ||
      _timeFilter != OrderDateRange.allTime ||
      _customRange != null ||
      _extraFilterCount > 0;

  String get _selectedKey {
    for (final tab in _tabs) {
      if (tab['label'] == _selectedTab) return tab['key']!;
    }
    return 'ALL';
  }

  /// What the date button shows, and what the empty-state message names.
  String get _dateFilterLabel {
    if (_customRange != null) {
      final fmt = DateFormat('MMM d');
      final start = fmt.format(_customRange!.start);
      final end = fmt.format(_customRange!.end);
      return start == end ? start : '$start – $end';
    }
    return _timeFilter.label;
  }

  bool _withinCustomRange(DateTime when) {
    final range = _customRange;
    if (range == null) return true;
    final day = DateTime(when.year, when.month, when.day);
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  Future<void> _openDateMenu(BuildContext buttonContext) async {
    final button = buttonContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selection = await showMenu<String>(
      context: buttonContext,
      position: position,
      items: [
        ...OrderDateRange.values.map((r) => PopupMenuItem(
              value: r.name,
              child: Text(r.label),
            )),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'custom',
          child: Text('Custom range...'),
        ),
      ],
    );
    if (selection == null || !mounted) return;

    if (selection == 'custom') {
      final picked = await AppDatePicker.pickDateRange(
        context: context,
        initialRange: _customRange,
      );
      if (picked != null) {
        setState(() {
          _customRange = picked;
          _timeFilter = OrderDateRange.allTime;
        });
      }
      return;
    }

    setState(() {
      _timeFilter = OrderDateRange.values.firstWhere((r) => r.name == selection);
      _customRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    final filteredOrders = provider
        .ordersFor(
          filter: _selectedKey,
          range: _timeFilter,
          search: _searchQuery,
        )
        .where((o) =>
            _withinCustomRange(o.createdAt) &&
            (!_overdueOnly || o.isOverdue) &&
            (!_unpaidDuesOnly || o.paymentStatus == PaymentStatus.unpaid) &&
            (_orderSource == 'all' ||
                (_orderSource == 'online' && o.source == 'PUBLIC_PAGE') ||
                (_orderSource == 'inshop' && o.source == 'WEB')) &&
            (_orderType == null || o.deliveryType == _orderType) &&
            (_serviceType == null ||
                o.items.any((i) => i.serviceType == _serviceType)))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return _body(provider, filteredOrders, narrow);
          },
        ),
      ),
    );
  }

  Widget _body(
      AppProvider provider, List<OrderModel> filteredOrders, bool narrow) {
    if (provider.hasError && provider.orders.isEmpty) {
      return ErrorState(
        statusCode: provider.error != null && provider.error!.contains('not found') ? 404 : 500,
        title: 'Error loading orders',
        message: provider.error!,
        onRetry: () => provider.refresh(),
        onHome: () => context.goSection(0),
      );
    }
    if (provider.isLoading && provider.orders.isEmpty) {
      return const LoadingState();
    }

    final totalCount = filteredOrders.length;
    final totalPages = (totalCount / _pageSize).ceil().clamp(1, 99999);
    final safePage = _currentPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final pagedOrders = totalCount > 0
        ? filteredOrders.skip(startIndex).take(_pageSize).toList()
        : <OrderModel>[];

    return Column(
      children: [
        narrow
            ? _narrowHeaderBar(provider, filteredOrders)
            : _wideHeaderBar(provider, filteredOrders),

        // Filter Tabs Scrollable Row
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final tab = _tabs[idx];
                final isSel = tab['label'] == _selectedTab;
                return ChoiceChip(
                  avatar: CircleAvatar(
                    radius: 3,
                    backgroundColor:
                        isSel ? Colors.white : _tabColor(tab['key']!),
                  ),
                  label: Text(
                    tab['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  selected: isSel,
                  selectedColor: const Color(0xFF182C4F),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                      color: isSel
                          ? const Color(0xFF182C4F)
                          : const Color(0xFFE4E0D8)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  onSelected: (_) => setState(() {
                    _selectedTab = tab['label']!;
                    _currentPage = 1;
                  }),
                );
              },
            ),
          ),
        ),

        // Orders Table Container
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 16.0 : 20.0),
            child: Container(
              decoration: narrow
                  ? null
                  : BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E0D8)),
                    ),
              child: Column(
                children: [
                  // Table Header — column labels don't apply to the
                  // narrow-mode card list below.
                  if (!narrow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F7F5),
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16)),
                        border: Border(
                            bottom: BorderSide(color: Color(0xFFE4E0D8))),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                              flex: 2,
                              child: Text('ORDER',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF94A3B8)))),
                          Expanded(
                              flex: 2,
                              child: Text(
                                  provider.role == 'customer' ? 'ITEMS' : 'CUSTOMER',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF94A3B8)))),
                          const Expanded(
                              flex: 2,
                              child: Text('TYPE',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF94A3B8)))),
                          const Expanded(
                              flex: 2,
                              child: Text('STATUS',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF94A3B8)))),
                          const Expanded(
                              flex: 2,
                              child: Text('PAYMENT',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF94A3B8)))),
                          const Expanded(
                              flex: 1,
                              child: Text('TOTAL',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF94A3B8)))),
                          const Expanded(
                              flex: 1,
                              child: Text('UPDATED',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF94A3B8)))),
                        ],
                      ),
                    ),

                  // Table Rows / Empty State
                  Expanded(
                    child: filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_bag_outlined,
                                    size: 40, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                const Text('No orders found',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF141A24))),
                                Text(
                                  _hasActiveFilter
                                      ? 'No orders match "$_selectedTab"'
                                          '${_timeFilter == OrderDateRange.allTime && _customRange == null ? '' : ' in $_dateFilterLabel'}.'
                                      : provider.role == 'customer'
                                          ? 'Book a pickup to get started with WashNLaundry.'
                                          : 'Create a new order to get started.',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                                if (provider.role == 'customer' && !_hasActiveFilter) ...[
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () => context.go('/my/book'),
                                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                                    label: const Text('Book a pickup'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF182C4F),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: narrow
                                ? const EdgeInsets.only(top: 12, bottom: 4)
                                : EdgeInsets.zero,
                            itemCount: pagedOrders.length,
                            separatorBuilder: (_, __) => narrow
                                ? const SizedBox(height: 12)
                                : const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final order = pagedOrders[idx];
                              final isCustomer = provider.role == 'customer';
                              if (narrow) return _orderCard(order, isCustomer: isCustomer);
                              final targetPath = isCustomer
                                  ? '/my/orders/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}'
                                  : '/orders/${order.id}';
                              return InkWell(
                                onTap: () => context.go(targetPath),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  child: _orderRow(order, isCustomer: isCustomer),
                                ),
                              );
                            },
                          ),
                  ),

                  // Table Footer
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: narrow ? 12 : 20, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            totalCount == 0
                                ? 'Showing 0 orders'
                                : 'Showing ${startIndex + 1}–${math.min(startIndex + pagedOrders.length, totalCount)} of $totalCount',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
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
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                                onPressed: safePage > 1
                                    ? () => setState(
                                        () => _currentPage = safePage - 1)
                                    : null,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
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
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                                onPressed: safePage < totalPages
                                    ? () => setState(
                                        () => _currentPage = safePage + 1)
                                    : null,
                              ),
                            ],
                          )
                        else
                          const Text('Page 1 of 1',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// The wide-mode table row's content (7 flex-matched columns) — unchanged
  /// from before the phone layout existed.
  Widget _orderRow(OrderModel order, {bool isCustomer = false}) {
    final initial =
        order.customerName.isEmpty ? '?' : order.customerName[0].toUpperCase();
    return Row(
      children: [
        // ORDER
        Expanded(
          flex: 2,
          child: Text('#${order.orderNumber}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF182C4F))),
        ),

        // CUSTOMER / ITEMS
        Expanded(
          flex: 2,
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFEFF6FF),
                child: isCustomer
                    ? const Icon(Icons.dry_cleaning_rounded, size: 14, color: Color(0xFF182C4F))
                    : Text(initial,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF182C4F))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCustomer
                          ? (order.items.isNotEmpty
                              ? order.items.map((i) => '${i.quantity} × ${i.itemTitle}').join(', ')
                              : 'Laundry order')
                          : order.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A24)),
                    ),
                    Text('${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
        ),

        // TYPE
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      order.deliveryTypeLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              if (order.scheduledDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 11,
                        color: order.isOverdue
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          DateFormat('EEE, MMM d').format(order.scheduledDate!),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: order.isOverdue
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // STATUS
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(status: order.status),
          ),
        ),

        // PAYMENT
        Expanded(
          flex: 2,
          child: Text(
            order.paymentStatusLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: paymentColor(order.paymentStatus),
            ),
          ),
        ),

        // TOTAL
        Expanded(
          flex: 1,
          child: Text('${Money.symbol}${order.totalAmount.toInt()}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
        ),

        // UPDATED
        Expanded(
          flex: 1,
          child: Text(
            relativeTime(order.createdAt),
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }

  /// The narrow-mode card replacing one table row — order # + status pill,
  /// customer, delivery type/schedule, payment + total, updated time.
  Widget _orderCard(OrderModel order, {bool isCustomer = false}) {
    final initial =
        order.customerName.isEmpty ? '?' : order.customerName[0].toUpperCase();
    final targetPath = isCustomer
        ? '/my/orders/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}'
        : '/orders/${order.id}';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.go(targetPath),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${order.orderNumber}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF182C4F))),
                StatusPill(status: order.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: isCustomer
                      ? const Icon(Icons.dry_cleaning_rounded, size: 13, color: Color(0xFF182C4F))
                      : Text(initial,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF182C4F))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      isCustomer
                          ? (order.items.isNotEmpty
                              ? order.items.map((i) => '${i.quantity} × ${i.itemTitle}').join(', ')
                              : 'Laundry order')
                          : order.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF141A24))),
                ),
                Text(
                    '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(order.deliveryTypeLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF475569))),
                ),
                if (order.scheduledDate != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '· ${DateFormat('EEE, MMM d').format(order.scheduledDate!)}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: order.isOverdue
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.paymentStatusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: paymentColor(order.paymentStatus))),
                Text('${Money.symbol}${order.totalAmount.toInt()}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF141A24))),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Updated ${relativeTime(order.createdAt)}',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ),
          ],
        ),
      ),
    );
  }

  /// The wide-mode header — title/count, date dropdown, a 240px search box,
  /// Filters, Export, New Order — all in one unwrapped Row. Unchanged from
  /// before the phone layout existed.
  Widget _wideHeaderBar(AppProvider provider, List<OrderModel> filteredOrders) {
    final isCustomer = provider.role == 'customer';
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Row(
        children: [
          Row(
            children: [
              const Text('Orders',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF141A24))),
              const SizedBox(width: 8),
              Text('${filteredOrders.length} Total',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          const Spacer(),
          _dateDropdown(),
          if (!isCustomer) ...[
            const SizedBox(width: 8),
            _calendarHeatmapButton(provider),
          ],
          const SizedBox(width: 8),

          // Search Input Box
          Container(
            width: 200,
            height: 38,
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
                    onChanged: (val) => setState(() => _searchQuery = val),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: isCustomer
                          ? 'Search by order ID or item...'
                          : 'Search by order ID, phone, or name...',
                      hintStyle:
                          const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_isCustomerView) ...[
            const SizedBox(width: 8),
            _filtersButton(),
          ],
          const SizedBox(width: 8),
          _newOrderButton(iconOnly: false, isCustomer: isCustomer),
        ],
      ),
    );
  }

  /// The narrow-mode header — the same controls, stacked instead of
  /// unwrapped: title + icon-only New Order, a full-width search box, then
  /// the date/Filters/Export controls in their own horizontal scroll (same
  /// pattern the status tabs below already use).
  Widget _narrowHeaderBar(AppProvider provider, List<OrderModel> filteredOrders) {
    final isCustomer = provider.role == 'customer';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Orders',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF141A24))),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${filteredOrders.length} Total',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 70,
                child: Container(
                  height: 38,
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
                          onChanged: (val) => setState(() => _searchQuery = val),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: isCustomer
                                ? 'Search by order ID or item...'
                                : 'Search by order ID, phone, or name...',
                            hintStyle:
                                const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
              Expanded(
                flex: 30,
                child: SizedBox(
                  height: 38,
                  child: _newOrderButton(iconOnly: true, isCustomer: isCustomer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _dateDropdown(),
                if (!isCustomer) ...[
                  const SizedBox(width: 8),
                  _calendarHeatmapButton(provider),
                ],
                if (!_isCustomerView) ...[
                  const SizedBox(width: 8),
                  _filtersButton(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateDropdown() {
    return Builder(
      builder: (buttonContext) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDateMenu(buttonContext),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE4E0D8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: Color(0xFF334155)),
              const SizedBox(width: 8),
              Text(
                _dateFilterLabel,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down,
                  size: 18, color: Color(0xFF334155)),
            ],
          ),
        ),
      ),
    );
  }

  /// Every order's day → how many landed on it, across the whole shop
  /// (not the current status/date filters) so the heatmap always reads as
  /// absolute daily volume rather than shifting under whatever's selected.
  Map<DateTime, int> _orderCountsByDay(AppProvider provider) {
    final counts = <DateTime, int>{};
    for (final o in provider.orders) {
      final day = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _openCalendarHeatmap(AppProvider provider) async {
    final picked = await OrderCalendarHeatmap.pickDay(
      context: context,
      countsByDay: _orderCountsByDay(provider),
      initialFocusedDay: _customRange?.start,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = DateTimeRange(start: picked, end: picked);
      _timeFilter = OrderDateRange.allTime;
    });
  }

  Widget _calendarHeatmapButton(AppProvider provider) {
    return Container(
      height: 38,
      width: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.calendar_view_month_rounded,
            size: 18, color: Color(0xFF334155)),
        tooltip: 'Orders calendar',
        onPressed: () => _openCalendarHeatmap(provider),
      ),
    );
  }

  /// The signed-in role (customers load the owner's data, so AppProvider.role
  /// can't tell).
  bool get _isCustomerView =>
      context.signedInRoleOnce == 'customer';

  Widget _filtersButton() {
    return OutlinedButton.icon(
      onPressed: _showFiltersDialog,
      icon: Icon(Icons.tune_rounded,
          size: 16,
          color: _extraFilterCount > 0
              ? const Color(0xFF182C4F)
              : const Color(0xFF475569)),
      label: Text(
        _extraFilterCount > 0 ? 'Filters ($_extraFilterCount)' : 'Filters',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _extraFilterCount > 0
                ? const Color(0xFF182C4F)
                : const Color(0xFF334155)),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
            color: _extraFilterCount > 0
                ? const Color(0xFF182C4F)
                : const Color(0xFFE4E0D8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  /// `iconOnly` drops the label for the narrow header, matching the same
  /// icon-plus treatment New Order's phone header already uses.
  Widget _newOrderButton({required bool iconOnly, bool isCustomer = false}) {
    final label = isCustomer ? 'Book Pickup' : 'New Order';
    final icon = isCustomer ? Icons.calendar_today_outlined : Icons.add;
    final VoidCallback onTap = isCustomer
        ? () => context.go('/my/book')
        : () => context.goSection(1);

    if (iconOnly) {
      return SizedBox(
        width: 38,
        height: 38,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF182C4F),
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF182C4F),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// The "Filter Orders" dialog: Attention
  /// Needed, Order Source, Order Type, Service type, Status. Edits a scratch
  /// copy of everything — including Status, which otherwise writes straight
  /// into [_selectedTab] — so Cancel truly cancels.
  ///
  /// Two adaptations from the live version: "Partially Delivered" isn't a
  /// status this app tracks (no per-item partial-delivery concept in the
  /// data model), so the Status list keeps "Out for Delivery" instead, which
  /// is real here. And service categories are read live from
  /// `provider.categories` rather than a fixed list, since ours can differ
  /// shop to shop.
  Future<void> _showFiltersDialog() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    var overdueOnly = _overdueOnly;
    var unpaidDuesOnly = _unpaidDuesOnly;
    var orderSource = _orderSource;
    var orderType = _orderType;
    var serviceType = _serviceType;

    final statusOptions = _tabs
        .where((t) =>
            t['key'] == 'ALL' ||
            OrderStatus.progression.contains(t['key']) ||
            t['key'] == OrderStatus.cancelled)
        .toList();
    var statusKey = statusOptions.any((t) => t['key'] == _selectedKey)
        ? _selectedKey
        : 'ALL';

    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Expanded(
                  child: Text('Filter Orders',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A24))),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: math.min(400.0, MediaQuery.sizeOf(ctx).width - 48),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ATTENTION NEEDED',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _optionCard(
                            icon: Icons.warning_amber_rounded,
                            iconColor: const Color(0xFFDC2626),
                            title: 'Overdue Orders',
                            subtitle: 'Past expected delivery',
                            selected: overdueOnly,
                            onTap: () => setDialogState(
                                () => overdueOnly = !overdueOnly),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _optionCard(
                            icon: Icons.receipt_long_rounded,
                            iconColor: const Color(0xFFEA580C),
                            title: 'Unpaid Dues',
                            subtitle: 'Balance not collected',
                            selected: unpaidDuesOnly,
                            onTap: () => setDialogState(
                                () => unpaidDuesOnly = !unpaidDuesOnly),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('ORDER SOURCE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _optionCard(
                            icon: Icons.filter_list_rounded,
                            title: 'All',
                            subtitle: 'All sources',
                            selected: orderSource == 'all',
                            onTap: () =>
                                setDialogState(() => orderSource = 'all'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _optionCard(
                            icon: Icons.public_rounded,
                            title: 'Online',
                            subtitle: 'From public page',
                            selected: orderSource == 'online',
                            onTap: () =>
                                setDialogState(() => orderSource = 'online'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _optionCard(
                            icon: Icons.storefront_rounded,
                            title: 'In-shop',
                            subtitle: 'POS / counter',
                            selected: orderSource == 'inshop',
                            onTap: () =>
                                setDialogState(() => orderSource = 'inshop'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('ORDER TYPE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _optionCard(
                            icon: Icons.filter_list_rounded,
                            title: 'All Types',
                            subtitle: 'Show all orders',
                            selected: orderType == null,
                            onTap: () => setDialogState(() => orderType = null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _optionCard(
                            icon: Icons.storefront_rounded,
                            title: 'Walk-In',
                            subtitle: 'Customer picks up',
                            selected: orderType == DeliveryType.storePickup,
                            onTap: () => setDialogState(
                                () => orderType = DeliveryType.storePickup),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _optionCard(
                            icon: Icons.local_shipping_rounded,
                            title: 'Home Delivery',
                            subtitle: 'Deliver to customer',
                            selected: orderType == DeliveryType.homeDelivery,
                            onTap: () => setDialogState(
                                () => orderType = DeliveryType.homeDelivery),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _optionCard(
                            icon: Icons.home_rounded,
                            title: 'Pickup & Delivery',
                            subtitle: 'We pick up and deliver',
                            selected: orderType == DeliveryType.homePickup,
                            onTap: () => setDialogState(
                                () => orderType = DeliveryType.homePickup),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('SERVICE TYPE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE4E0D8)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: serviceType,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF141A24)),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('All service types')),
                            for (final c in provider.categories)
                              DropdownMenuItem<String?>(
                                  value: c.name, child: Text(c.name)),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => serviceType = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('STATUS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    for (final tab in statusOptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _statusRadio(
                          tab['label']!,
                          statusKey == tab['key'],
                          () => setDialogState(() => statusKey = tab['key']!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              // A single Row so `Spacer` has the bounded Flex ancestor it
              // needs — `AlertDialog.actions` lays its children out in an
              // `OverflowBar`, which doesn't support flex children directly.
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => setDialogState(() {
                        overdueOnly = false;
                        unpaidDuesOnly = false;
                        orderSource = 'all';
                        orderType = null;
                        serviceType = null;
                        statusKey = 'ALL';
                      }),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE4E0D8)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reset',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF182C4F),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Apply Filters',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (applied == true && mounted) {
      setState(() {
        _overdueOnly = overdueOnly;
        _unpaidDuesOnly = unpaidDuesOnly;
        _orderSource = orderSource;
        _orderType = orderType;
        _serviceType = serviceType;
        _selectedTab =
            statusOptions.firstWhere((t) => t['key'] == statusKey)['label']!;
      });
    }
  }

  Widget _optionCard({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  selected ? const Color(0xFF182C4F) : const Color(0xFFE4E0D8),
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 18,
                color: selected
                    ? const Color(0xFF182C4F)
                    : (iconColor ?? const Color(0xFF64748B))),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? const Color(0xFF182C4F)
                        : const Color(0xFF141A24))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _statusRadio(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  selected ? const Color(0xFF182C4F) : const Color(0xFFE4E0D8)),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color:
                  selected ? const Color(0xFF182C4F) : const Color(0xFFD9D5CB),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFF182C4F)
                        : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }
}
