import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/order_model.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/receipt_dialog.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _customerName = 'Walk-in customer';
  String _customerPhone = '9876543210';

  final Map<String, int> _cartQuantities = {};
  final Map<String, bool> _expressToggles = {};

  final List<Map<String, dynamic>> _garments = [
    {'id': '1', 'name': 'Shirt', 'category': 'Ironing', 'price': 15.0, 'unit': 'per pc', 'icon': Icons.dry_cleaning_rounded, 'color': Color(0xFF3B82F6)},
    {'id': '2', 'name': 'T-Shirt', 'category': 'Wash & Iron', 'price': 12.0, 'unit': 'per pc', 'icon': Icons.checkroom_rounded, 'color': Color(0xFFF97316)},
    {'id': '3', 'name': 'Kurta', 'category': 'Wash & Iron', 'price': 20.0, 'unit': 'per pc', 'icon': Icons.strikethrough_s_rounded, 'color': Color(0xFF06B6D4)},
    {'id': '4', 'name': 'Suit (2 piece)', 'category': 'Dry Cleaning', 'price': 100.0, 'unit': 'per pc', 'icon': Icons.business_center_rounded, 'color': Color(0xFF64748B)},
    {'id': '5', 'name': 'Pant', 'category': 'Ironing', 'price': 18.0, 'unit': 'per pc', 'icon': Icons.airline_seat_legroom_extra_rounded, 'color': Color(0xFFD97706)},
    {'id': '6', 'name': 'Jeans', 'category': 'Wash & Fold', 'price': 20.0, 'unit': 'per pc', 'icon': Icons.checkroom_outlined, 'color': Color(0xFF2563EB)},
    {'id': '7', 'name': 'Shorts', 'category': 'Wash & Fold', 'price': 12.0, 'unit': 'per pc', 'icon': Icons.dry_cleaning_outlined, 'color': Color(0xFF10B981)},
    {'id': '8', 'name': 'Top / Kurti', 'category': 'Dry Cleaning', 'price': 15.0, 'unit': 'per pc', 'icon': Icons.woman_rounded, 'color': Color(0xFFEC4899)},
  ];

  final List<String> _categories = [
    'All', 'Ironing', 'Wash & Fold', 'Wash & Iron', 'Dry Cleaning', 'Household', 'Shoe Cleaning', 'Premium Laundry'
  ];

  double get _subtotal {
    double sum = 0.0;
    _cartQuantities.forEach((id, qty) {
      final g = _garments.firstWhere((item) => item['id'] == id, orElse: () => {});
      if (g.isNotEmpty) {
        double price = (g['price'] as double);
        if (_expressToggles[id] == true) price *= 1.5;
        sum += price * qty;
      }
    });
    return sum;
  }

  int get _totalItems => _cartQuantities.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final filteredItems = _garments.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),

          // Main Center View
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF475569)),
                        onPressed: () {
                          Provider.of<AppProvider>(context, listen: false).setNavIndex(0);
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'New Order',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF64748B)),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF1A4FD6),
                        child: const Text('AK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                ),

                // Search & Filter Row
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText: 'Search items or scan a tag...',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Filter Pills Row
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final cat = _categories[idx];
                            final isSel = cat == _selectedCategory;
                            return ChoiceChip(
                              label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF334155))),
                              selected: isSel,
                              selectedColor: const Color(0xFF1A4FD6),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Items Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.76,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, idx) {
                      final item = filteredItems[idx];
                      final id = item['id'] as String;
                      final qty = _cartQuantities[id] ?? 0;
                      final isExpress = _expressToggles[id] ?? false;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Garment Image / Placeholder Box
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(item['icon'] as IconData, size: 48, color: item['color'] as Color),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Name & Price
                            Text(item['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Row(
                              children: [
                                Text('₹${(item['price'] as double).toInt()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                const SizedBox(width: 4),
                                Text(item['unit'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Express Toggle Row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFF59E0B)),
                                      Text('EXPRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                  Switch(
                                    value: isExpress,
                                    activeColor: const Color(0xFF1A4FD6),
                                    onChanged: (val) => setState(() => _expressToggles[id] = val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Add to List / Counter Button
                            qty == 0
                                ? SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () => setState(() => _cartQuantities[id] = 1),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      child: const Text('+ Add to List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                    ),
                                  )
                                : Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 16, color: Color(0xFF1A4FD6)),
                                          onPressed: () => setState(() {
                                            if (qty > 1) _cartQuantities[id] = qty - 1;
                                            else _cartQuantities.remove(id);
                                          }),
                                        ),
                                        Text('$qty', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF1A4FD6)),
                                          onPressed: () => setState(() => _cartQuantities[id] = qty + 1),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Right Cart Panel Sidebar (Width: 320)
          Container(
            width: 320,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cart Header Title
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Text('Current order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$_totalItems', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Customer Selection Box
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: const Text('W', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const Text('Tap to add a customer', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                        ),
                      ],
                    ),
                  ),
                ),

                // Cart Items List / Empty State
                Expanded(
                  child: _cartQuantities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, size: 32, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 12),
                              const Text('No items yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const Text('Tap products to add them to the order', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: _cartQuantities.entries.map((e) {
                            final g = _garments.firstWhere((item) => item['id'] == e.key);
                            double price = (g['price'] as double);
                            if (_expressToggles[e.key] == true) price *= 1.5;
                            final itemTotal = price * e.value;

                            return ListTile(
                              title: Text(g['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              subtitle: Text('${e.value}x @ ₹${price.toInt()}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              trailing: Text('₹${itemTotal.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            );
                          }).toList(),
                        ),
                ),

                // Cart Summary Footer & Checkout Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          Text('₹${_subtotal.toInt()}', style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('₹${_subtotal.toInt()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _subtotal == 0
                              ? null
                              : () async {
                                  final provider = Provider.of<AppProvider>(context, listen: false);
                                  final orderNum = 'LB-${1000 + provider.orders.length + 1}';

                                  final cartItems = _cartQuantities.entries.map((e) {
                                    final g = _garments.firstWhere((item) => item['id'] == e.key);
                                    double price = (g['price'] as double);
                                    if (_expressToggles[e.key] == true) price *= 1.5;

                                    return OrderItemModel(
                                      itemTitle: g['name'] as String,
                                      serviceType: g['category'] as String,
                                      quantity: e.value,
                                      unitPrice: price,
                                      totalPrice: price * e.value,
                                    );
                                  }).toList();

                                  final payload = {
                                    'order_number': orderNum,
                                    'customer_name': _customerName,
                                    'customer_phone': _customerPhone,
                                    'status': 'WASHING',
                                    'payment_status': 'PAID',
                                    'payment_method': 'UPI',
                                    'total_amount': _subtotal,
                                    'paid_amount': _subtotal,
                                    'due_amount': 0.0,
                                    'express': false,
                                    'items': cartItems.map((i) => i.toJson()).toList(),
                                  };

                                  await provider.createNewOrder(payload);

                                  if (mounted) {
                                    setState(() {
                                      _cartQuantities.clear();
                                      _expressToggles.clear();
                                    });

                                    showDialog(
                                      context: context,
                                      builder: (_) => ReceiptDialog(
                                        order: OrderModel(
                                          id: 'ord-new',
                                          orderNumber: orderNum,
                                          customerName: _customerName,
                                          customerPhone: _customerPhone,
                                          status: 'WASHING',
                                          paymentStatus: 'PAID',
                                          paymentMethod: 'UPI',
                                          totalAmount: _subtotal,
                                          paidAmount: _subtotal,
                                          dueAmount: 0.0,
                                          express: false,
                                          createdAt: DateTime.now(),
                                          items: cartItems,
                                        ),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A4FD6),
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Checkout • ₹${_subtotal.toInt()}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
