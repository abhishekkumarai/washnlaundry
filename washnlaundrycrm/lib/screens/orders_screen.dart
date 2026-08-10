import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/order_model.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/status_pill.dart';
import '../screens/order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedTab = 'All';
  OrderDateRange _timeFilter = OrderDateRange.allTime;
  String _searchQuery = '';
  OrderModel? _selectedOrderForDetails;

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
      _timeFilter != OrderDateRange.allTime;

  String get _selectedKey {
    for (final tab in _tabs) {
      if (tab['label'] == _selectedTab) return tab['key']!;
    }
    return 'ALL';
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedOrderForDetails != null) {
      return OrderDetailScreen(
        order: _selectedOrderForDetails!,
        onBack: () => setState(() => _selectedOrderForDetails = null),
      );
    }

    final provider = Provider.of<AppProvider>(context);

    final filteredOrders = provider.ordersFor(
      filter: _selectedKey,
      range: _timeFilter,
      search: _searchQuery,
    );

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
                        onPressed: () {},
                        icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF475569)),
                        label: const Text('Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
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
                        onPressed: () => context.read<AppProvider>().setNavIndex(1),
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
                                        onTap: () => setState(() => _selectedOrderForDetails = order),
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
                                                child: Text('₹${order.totalAmount.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
}
