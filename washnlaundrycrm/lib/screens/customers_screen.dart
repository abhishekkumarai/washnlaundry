import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';

class CustomerEntry {
  final int id;
  final String name;
  final String phone;
  final String area;
  final int ordersCount;
  final double lifetimeSpent;
  final String lastOrder;

  CustomerEntry({
    required this.id,
    required this.name,
    required this.phone,
    required this.area,
    required this.ordersCount,
    required this.lifetimeSpent,
    required this.lastOrder,
  });
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _searchQuery = '';

  final List<CustomerEntry> _customCustomers = [
    CustomerEntry(
      id: 1,
      name: 'Me',
      phone: '+914277905904',
      area: '—',
      ordersCount: 1,
      lifetimeSpent: 250.0,
      lastOrder: '8h ago',
    ),
  ];

  void _showCustomerDetailsModal(BuildContext context, CustomerEntry customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF1A4FD6),
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('${customer.phone} · ${customer.area}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // KPI Stats Grid
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailCard('Total Orders', '${customer.ordersCount}', Icons.shopping_bag_outlined, const Color(0xFF1A4FD6)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDetailCard('Lifetime Spent', '₹${customer.lifetimeSpent.toInt()}', Icons.account_balance_wallet_outlined, const Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDetailCard('Last Order', customer.lastOrder, Icons.access_time_rounded, const Color(0xFFA855F7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Customer Details Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Customer ID', 'CUST-${customer.id}'),
                          const Divider(height: 16),
                          _buildDetailRow('Phone Number', customer.phone),
                          const Divider(height: 16),
                          _buildDetailRow('Address / Locality', customer.area),
                          const Divider(height: 16),
                          _buildDetailRow('Member Since', 'July 2026'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF10B981)),
                            label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: const Text('Create Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A4FD6),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  void _showAddCustomerModal(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final areaController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Add New Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Customer Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Customer name',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              const Text('Phone Number *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+919876543210',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              const Text('Area / Locality', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: areaController,
                decoration: InputDecoration(
                  hintText: 'e.g. Hbr layout, Bengaluru',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty && phoneController.text.trim().isNotEmpty) {
                setState(() {
                  _customCustomers.add(
                    CustomerEntry(
                      id: _customCustomers.length + 1,
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      area: areaController.text.trim().isEmpty ? '—' : areaController.text.trim(),
                      ordersCount: 0,
                      lifetimeSpent: 0.0,
                      lastOrder: 'Just now',
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Merge backend order customers into display list
    final allDisplayCustomers = [..._customCustomers];
    for (var o in provider.orders) {
      if (!allDisplayCustomers.any((c) => c.phone == o.customerPhone)) {
        allDisplayCustomers.add(
          CustomerEntry(
            id: allDisplayCustomers.length + 1,
            name: o.customerName,
            phone: o.customerPhone,
            area: 'Hbr layout',
            ordersCount: 1,
            lifetimeSpent: o.totalAmount,
            lastOrder: '7h ago',
          ),
        );
      }
    }

    final filteredCustomers = allDisplayCustomers.where((c) {
      return _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.phone.contains(_searchQuery) ||
          c.area.toLowerCase().contains(_searchQuery.toLowerCase());
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
                          const Text('Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(width: 8),
                          Text('${allDisplayCustomers.length} Total', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                      const Spacer(),

                      // Search Bar
                      Container(
                        width: 260,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText: 'Search by name, phone, or email...',
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

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
                        onPressed: () => _showAddCustomerModal(context),
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A4FD6),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top 3 KPI Cards Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiSummaryCard(
                                icon: Icons.people_outline_rounded,
                                iconBg: const Color(0xFFEEF2FF),
                                iconColor: const Color(0xFF1A4FD6),
                                value: '${allDisplayCustomers.length}',
                                title: 'Total',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiSummaryCard(
                                icon: Icons.person_outline_rounded,
                                iconBg: const Color(0xFFECFDF5),
                                iconColor: const Color(0xFF10B981),
                                value: '${allDisplayCustomers.length}',
                                title: 'Active',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiSummaryCard(
                                icon: Icons.person_add_alt_1_outlined,
                                iconBg: const Color(0xFFF3E8FF),
                                iconColor: const Color(0xFFA855F7),
                                value: '${allDisplayCustomers.length}',
                                title: 'New',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section Header
                        const Text('All customers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 16),

                        // Customers Table Container
                        Container(
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
                                    Expanded(flex: 3, child: Text('CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                    Expanded(flex: 2, child: Text('AREA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                    Expanded(flex: 2, child: Text('ORDERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                    Expanded(flex: 2, child: Text('LIFETIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                    Expanded(flex: 2, child: Text('LAST ORDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                    SizedBox(width: 24),
                                  ],
                                ),
                              ),

                              // Customer Rows
                              filteredCustomers.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(vertical: 40),
                                      child: Column(
                                        children: const [
                                          Icon(Icons.people_outline_rounded, size: 36, color: Color(0xFF94A3B8)),
                                          SizedBox(height: 8),
                                          Text('No customers found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: filteredCustomers.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final c = filteredCustomers[idx];
                                        return InkWell(
                                          onTap: () => _showCustomerDetailsModal(context, c),
                                          hoverColor: const Color(0xFFF8FAFC),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                            child: Row(
                                              children: [
                                                // CUSTOMER
                                                Expanded(
                                                  flex: 3,
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 16,
                                                        backgroundColor: const Color(0xFFEEF2FF),
                                                        child: Text(
                                                          c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                          Text(c.phone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // AREA
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    c.area,
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                  ),
                                                ),

                                                // ORDERS
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '${c.ordersCount}',
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                                                  ),
                                                ),

                                                // LIFETIME
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '₹${c.lifetimeSpent.toInt()}',
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                  ),
                                                ),

                                                // LAST ORDER
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    c.lastOrder,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                  ),
                                                ),

                                                const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }
}
