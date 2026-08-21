import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/order_model.dart';
import '../utils/navigation.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/status_pill.dart';
import '../utils/money.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedTab = 'All';
  OrderDateRange _timeFilter = OrderDateRange.allTime;
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
        return const Color(0xFF1A4FD6);
      case 'PARTIAL':
        return const Color(0xFFD97706);
      case 'OVERDUE':
        return const Color(0xFFDC2626);
      case 'SCHEDULED':
        return const Color(0xFF8B5CF6);
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
      _extraFilterCount > 0;

  String get _selectedKey {
    for (final tab in _tabs) {
      if (tab['label'] == _selectedTab) return tab['key']!;
    }
    return 'ALL';
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
            (!_overdueOnly || o.isOverdue) &&
            (!_unpaidDuesOnly || o.paymentStatus == PaymentStatus.unpaid) &&
            (_orderSource == 'all' ||
                (_orderSource == 'online' && o.source == 'PUBLIC_PAGE') ||
                (_orderSource == 'inshop' && o.source == 'WEB')) &&
            (_orderType == null || o.deliveryType == _orderType) &&
            (_serviceType == null || o.items.any((i) => i.serviceType == _serviceType)))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),

          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          const Text('Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(width: 8),
                          Text('${provider.orders.length} Total', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                      const Spacer(),

                      // Time Filter Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<OrderDateRange>(
                            value: _timeFilter,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            items: OrderDateRange.values
                                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _timeFilter = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Search Input Box
                      Container(
                        width: 240,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText: 'Search by order ID, phone, or name...',
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      OutlinedButton.icon(
                        onPressed: _showFiltersDialog,
                        icon: Icon(Icons.tune_rounded, size: 16, color: _extraFilterCount > 0 ? const Color(0xFF1A4FD6) : const Color(0xFF475569)),
                        label: Text(
                          _extraFilterCount > 0 ? 'Filters ($_extraFilterCount)' : 'Filters',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _extraFilterCount > 0 ? const Color(0xFF1A4FD6) : const Color(0xFF334155)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _extraFilterCount > 0 ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),

                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF475569)),
                        label: const Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),

                      ElevatedButton.icon(
                        onPressed: () => context.goSection(1),
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text('New Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A4FD6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

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
                            backgroundColor: isSel ? Colors.white : _tabColor(tab['key']!),
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
                          selectedColor: const Color(0xFF1A4FD6),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (_) => setState(() => _selectedTab = tab['label']!),
                        );
                      },
                    ),
                  ),
                ),

                // Orders Table Container
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Container(
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
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: Row(
                              children: const [
                                Expanded(flex: 2, child: Text('ORDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                Expanded(flex: 2, child: Text('CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                Expanded(flex: 2, child: Text('TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                Expanded(flex: 2, child: Text('PAYMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                Expanded(flex: 1, child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                Expanded(flex: 1, child: Text('UPDATED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
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
                                        const Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFF94A3B8)),
                                        const SizedBox(height: 12),
                                        const Text('No orders found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        Text(
                                          _hasActiveFilter
                                              ? 'No orders match "$_selectedTab"'
                                                  '${_timeFilter == OrderDateRange.allTime ? '' : ' in ${_timeFilter.label}'}.'
                                              : 'Create a new order to get started.',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: filteredOrders.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final order = filteredOrders[idx];
                                      final initial = order.customerName.isEmpty
                                          ? '?'
                                          : order.customerName[0].toUpperCase();

                                      return InkWell(
                                        onTap: () => context.go('/orders/${order.id}'),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                          child: Row(
                                            children: [
                                              // ORDER
                                              Expanded(
                                                flex: 2,
                                                child: Text('#${order.orderNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                              ),

                                              // CUSTOMER
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: const Color(0xFFEEF2FF),
                                                      child: Text(initial, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          order.customerName,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                        ),
                                                        Text('${order.items.length} items', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
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
                                                            style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
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
                                                child: Text('${Money.symbol}${order.totalAmount.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          // Table Footer
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  filteredOrders.length == provider.orders.length
                                      ? 'Showing ${filteredOrders.length}'
                                      : 'Showing ${filteredOrders.length} of ${provider.orders.length}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                                const Text('No more orders', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
            ),
          ),
        ],
      ),
    );
  }

  /// Matches the real app's own "Filter Orders" dialog section-for-section
  /// (compared side by side against `app.laundrybill.com/orders`): Attention
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
    var statusKey = statusOptions.any((t) => t['key'] == _selectedKey) ? _selectedKey : 'ALL';

    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Expanded(
                  child: Text('Filter Orders',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ATTENTION NEEDED',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
                            onTap: () => setDialogState(() => overdueOnly = !overdueOnly),
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
                            onTap: () => setDialogState(() => unpaidDuesOnly = !unpaidDuesOnly),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('ORDER SOURCE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _optionCard(
                            icon: Icons.filter_list_rounded,
                            title: 'All',
                            subtitle: 'All sources',
                            selected: orderSource == 'all',
                            onTap: () => setDialogState(() => orderSource = 'all'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _optionCard(
                            icon: Icons.public_rounded,
                            title: 'Online',
                            subtitle: 'From public page',
                            selected: orderSource == 'online',
                            onTap: () => setDialogState(() => orderSource = 'online'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _optionCard(
                            icon: Icons.storefront_rounded,
                            title: 'In-shop',
                            subtitle: 'POS / counter',
                            selected: orderSource == 'inshop',
                            onTap: () => setDialogState(() => orderSource = 'inshop'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('ORDER TYPE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
                            title: 'Shop Pickup',
                            subtitle: 'Customer picks up',
                            selected: orderType == DeliveryType.storePickup,
                            onTap: () => setDialogState(() => orderType = DeliveryType.storePickup),
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
                            onTap: () => setDialogState(() => orderType = DeliveryType.homeDelivery),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _optionCard(
                            icon: Icons.home_rounded,
                            title: 'Pickup & Delivery',
                            subtitle: 'We pick up and deliver',
                            selected: orderType == DeliveryType.homePickup,
                            onTap: () => setDialogState(() => orderType = DeliveryType.homePickup),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('SERVICE TYPE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: serviceType,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('All service types')),
                            for (final c in provider.categories)
                              DropdownMenuItem<String?>(value: c.name, child: Text(c.name)),
                          ],
                          onChanged: (v) => setDialogState(() => serviceType = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('STATUS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reset', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A4FD6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
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
        _selectedTab = statusOptions.firstWhere((t) => t['key'] == statusKey)['label']!;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0), width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: selected ? const Color(0xFF1A4FD6) : (iconColor ?? const Color(0xFF64748B))),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? const Color(0xFF1A4FD6) : const Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _statusRadio(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? const Color(0xFF1A4FD6) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? const Color(0xFF1A4FD6) : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }
}
