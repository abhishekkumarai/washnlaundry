import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/order_model.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/new_order_dialog.dart';
import '../screens/order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedTab = 'All';
  String _timeFilter = 'All time';
  String _searchQuery = '';
  OrderModel? _selectedOrderForDetails;

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'All', 'color': Color(0xFF1A4FD6)},
    {'label': 'Placed', 'color': Color(0xFF64748B)},
    {'label': 'Processing', 'color': Color(0xFF1A4FD6)},
    {'label': 'Ready', 'color': Color(0xFF10B981)},
    {'label': 'Out for delivery', 'color': Color(0xFF0284C7)},
    {'label': 'Partial', 'color': Color(0xFFF59E0B)},
    {'label': 'Delivered', 'color': Color(0xFF10B981)},
    {'label': 'Cancelled', 'color': Color(0xFFEF4444)},
    {'label': 'Overdue Orders', 'color': Color(0xFFDC2626)},
    {'label': 'Scheduled', 'color': Color(0xFF8B5CF6)},
    {'label': 'Unpaid Dues', 'color': Color(0xFFEA580C)},
  ];

  @override
  Widget build(BuildContext context) {
    if (_selectedOrderForDetails != null) {
      return OrderDetailScreen(
        order: _selectedOrderForDetails!,
        onBack: () => setState(() => _selectedOrderForDetails = null),
      );
    }

    final provider = Provider.of<AppProvider>(context);

    final filteredOrders = provider.orders.where((o) {
      final matchesSearch = _searchQuery.isEmpty ||
          o.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.customerPhone.contains(_searchQuery);

      bool matchesTab = true;
      if (_selectedTab == 'Placed' || _selectedTab == 'Processing') {
        matchesTab = o.status.toUpperCase() == 'PENDING' || o.status.toUpperCase() == 'WASHING' || o.status.toUpperCase() == 'PROCESSING';
      } else if (_selectedTab == 'Ready') {
        matchesTab = o.status.toUpperCase() == 'READY';
      } else if (_selectedTab == 'Delivered') {
        matchesTab = o.status.toUpperCase() == 'DELIVERED';
      } else if (_selectedTab == 'Unpaid Dues') {
        matchesTab = o.paymentStatus.toUpperCase() != 'PAID';
      }

      return matchesSearch && matchesTab;
    }).toList();

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
                          child: DropdownButton<String>(
                            value: _timeFilter,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            items: ['All time', 'Today', 'This Week', 'This Month'].map((t) {
                              return DropdownMenuItem(value: t, child: Text(t));
                            }).toList(),
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
                        onPressed: () => showDialog(context: context, builder: (_) => const NewOrderDialog()),
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
                            backgroundColor: isSel ? Colors.white : (tab['color'] as Color),
                          ),
                          label: Text(
                            tab['label'] as String,
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
                          onSelected: (_) => setState(() => _selectedTab = tab['label'] as String),
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
                                      children: const [
                                        Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFF94A3B8)),
                                        SizedBox(height: 12),
                                        Text('No orders found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        Text('Create a new order to get started.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: filteredOrders.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final order = filteredOrders[idx];
                                      final isDelivered = order.status.toUpperCase() == 'DELIVERED';
                                      final isPaid = order.paymentStatus.toUpperCase() == 'PAID';

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
                                                      child: Text(order.customerName[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(order.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                        Text('${order.items.length} items', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // TYPE
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                                                    SizedBox(width: 6),
                                                    Text('delivery home', style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                                                  ],
                                                ),
                                              ),

                                              // STATUS
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isDelivered ? const Color(0xFFECFDF5) : const Color(0xFFEEF2FF),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      order.status,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDelivered ? const Color(0xFF10B981) : const Color(0xFF1A4FD6),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // PAYMENT
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  order.paymentStatus,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                  ),
                                                ),
                                              ),

                                              // TOTAL
                                              Expanded(
                                                flex: 1,
                                                child: Text('₹${order.totalAmount.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                              ),

                                              // UPDATED
                                              const Expanded(
                                                flex: 1,
                                                child: Text('7h ago', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
                                Text('Showing ${filteredOrders.length}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
