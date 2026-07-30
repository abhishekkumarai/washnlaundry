import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../models/order_model.dart';
import '../models/garment_model.dart';

class NewOrderDialog extends StatefulWidget {
  const NewOrderDialog({Key? key}) : super(key: key);

  @override
  State<NewOrderDialog> createState() => _NewOrderDialogState();
}

class _NewOrderDialogState extends State<NewOrderDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  /// Empty means "All". The category *is* the service — an item's price is
  /// fixed by the category it sits in, so this filters the grid rather than
  /// re-pricing the items.
  String _selectedCategory = '';
  final Map<String, int> _itemQuantities = {};
  bool _express = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    final categoryNames = <String>{
      for (final g in provider.garments) g.categoryName,
    }.toList();

    final visibleGarments = _selectedCategory.isEmpty
        ? provider.garments
        : provider.garments
            .where((g) => g.categoryName == _selectedCategory)
            .toList();

    // Calculate totals
    double subtotal = 0.0;
    List<OrderItemModel> selectedOrderItems = [];

    _itemQuantities.forEach((garmentId, qty) {
      if (qty > 0) {
        final matches = provider.garments.where((g) => g.id == garmentId);
        if (matches.isEmpty) return;
        final g = matches.first;
        final lineTotal = g.price * qty;
        subtotal += lineTotal;
        selectedOrderItems.add(OrderItemModel(
          itemTitle: g.name,
          serviceType: g.categoryName,
          quantity: qty,
          unit: g.unit,
          unitPrice: g.price,
          totalPrice: lineTotal,
        ));
      }
    });

    final totalAmount = subtotal + (_express ? 100.0 : 0.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 850,
        height: 620,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.dry_cleaning_rounded, color: Color(0xFF1A4FD6), size: 24),
                    SizedBox(width: 10),
                    Text('Fast POS Billing & New Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const Divider(height: 24),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Selection (Garments & Customer)
                  Expanded(
                    flex: 7,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Input
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name *',
                                    hintText: 'e.g. Aditya Sharma',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'WhatsApp Phone *',
                                    hintText: '9876543210',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Service Tabs
                          const Text('1. Processing Service', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: ['All', ...categoryNames].map((s) {
                              final value = s == 'All' ? '' : s;
                              final isSel = _selectedCategory == value;
                              return ChoiceChip(
                                label: Text(s, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : const Color(0xFF334155))),
                                selected: isSel,
                                selectedColor: const Color(0xFF1A4FD6),
                                backgroundColor: const Color(0xFFF1F5F9),
                                onSelected: (val) {
                                  if (val) setState(() => _selectedCategory = value);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Garments List Grid
                          const Text('2. Select Garment Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.5,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: visibleGarments.length,
                            itemBuilder: (context, idx) {
                              final g = visibleGarments[idx];
                              final qty = _itemQuantities[g.id] ?? 0;
                              final price = g.price;

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: qty > 0 ? const Color(0xFFEEF2FF) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: qty > 0 ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(g.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                                          Text('₹${price.toInt()} / ${g.unitShortLabel}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A4FD6))),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        if (qty > 0)
                                          IconButton(
                                            onPressed: () => setState(() => _itemQuantities[g.id] = qty - 1),
                                            icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF64748B)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        if (qty > 0)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text('$qty', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        IconButton(
                                          onPressed: () => setState(() => _itemQuantities[g.id] = qty + 1),
                                          icon: const Icon(Icons.add_circle, size: 22, color: Color(0xFF1A4FD6)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),
                  const VerticalDivider(width: 1),
                  const SizedBox(width: 16),

                  // Right Order Summary Sidebar
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 12),
                        
                        Expanded(
                          child: selectedOrderItems.isEmpty
                              ? const Center(child: Text('No garments selected', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))))
                              : ListView.builder(
                                  itemCount: selectedOrderItems.length,
                                  itemBuilder: (context, i) {
                                    final item = selectedOrderItems[i];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${item.itemTitle} x${item.quantity}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                          Text('₹${item.totalPrice.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // Express checkbox
                        CheckboxListTile(
                          title: const Text('Express 24H (+₹100)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          value: _express,
                          onChanged: (val) => setState(() => _express = val ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),

                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('₹${totalAmount.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                          ],
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: selectedOrderItems.isEmpty ? null : () => _handleCreateOrder(provider, selectedOrderItems, totalAmount),
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                            label: const Text('Generate Bill & Save Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A4FD6),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
    );
  }

  void _handleCreateOrder(AppProvider provider, List<OrderItemModel> items, double total) async {
    final name = _nameController.text.trim().isEmpty ? 'Walk-in Customer' : _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty ? '9876543210' : _phoneController.text.trim();
    final orderNum = 'LB-${1000 + provider.orders.length + 1}';

    final orderPayload = {
      'order_number': orderNum,
      'customer_name': name,
      'customer_phone': phone,
      'status': 'WASHING',
      'payment_status': 'PAID',
      'payment_method': 'UPI',
      'total_amount': total,
      'paid_amount': total,
      'due_amount': 0.0,
      'express': _express,
      'items': items.map((i) => i.toJson()).toList(),
    };

    final success = await provider.createNewOrder(orderPayload);
    if (!success) {
      final newOrder = OrderModel(
        id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
        orderNumber: orderNum,
        customerName: name,
        customerPhone: phone,
        status: 'WASHING',
        paymentStatus: 'PAID',
        paymentMethod: 'UPI',
        totalAmount: total,
        paidAmount: total,
        dueAmount: 0,
        express: _express,
        createdAt: DateTime.now(),
        items: items,
      );
      provider.addOrder(newOrder);
    }

    if (mounted) Navigator.pop(context);

    // Launch WhatsApp receipt
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent('Hello $name,\nThank you for choosing LaundryBill!\nYour Order #$orderNum has been created for ₹${total.toInt()}.\nThank you!');
    final url = Uri.parse('https://wa.me/91$cleanPhone?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
