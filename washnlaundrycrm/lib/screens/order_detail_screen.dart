import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onBack;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.onBack,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late String _currentStatus;
  late String _paymentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
    _paymentStatus = widget.order.paymentStatus;
  }

  int _getStepIndex() {
    final status = _currentStatus.toUpperCase();
    if (status == 'DELIVERED') return 4;
    if (status == 'OUT_FOR_DELIVERY') return 3;
    if (status == 'READY') return 2;
    if (status == 'WASHING' || status == 'PROCESSING') return 1;
    return 0; // PLACED / PENDING
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = _getStepIndex();
    final isPaid = _paymentStatus.toUpperCase() == 'PAID';

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
                      InkWell(
                        onTap: widget.onBack,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: const [
                              Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF1A4FD6)),
                              SizedBox(width: 6),
                              Text('Back to Orders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(height: 20, width: 1, color: const Color(0xFFCBD5E1)),
                      const SizedBox(width: 16),

                      Text('Order #${widget.order.orderNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _paymentStatus,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                        ),
                      ),
                      const Spacer(),

                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Printing thermal receipt...'), backgroundColor: Color(0xFF1A4FD6)),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 16, color: Color(0xFF475569)),
                        label: const Text('Print Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 10),

                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('WhatsApp receipt sent to customer!'), backgroundColor: Color(0xFF10B981)),
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        label: const Text('WhatsApp Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Scrollable Content Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Status Stepper Bar Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Order Progress Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  Text('Placed on July 29, 2026', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Stepper Row
                              Row(
                                children: [
                                  _buildStepItem('Placed', 0, stepIndex),
                                  _buildStepConnector(0 < stepIndex),
                                  _buildStepItem('Washing', 1, stepIndex),
                                  _buildStepConnector(1 < stepIndex),
                                  _buildStepItem('Ready', 2, stepIndex),
                                  _buildStepConnector(2 < stepIndex),
                                  _buildStepItem('Out for Delivery', 3, stepIndex),
                                  _buildStepConnector(3 < stepIndex),
                                  _buildStepItem('Delivered', 4, stepIndex),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Quick Status Advance Actions
                              Row(
                                children: [
                                  const Text('Update Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  const SizedBox(width: 10),
                                  _buildStatusActionButton('Washing', const Color(0xFF1A4FD6)),
                                  const SizedBox(width: 8),
                                  _buildStatusActionButton('Ready', const Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  _buildStatusActionButton('Delivered', const Color(0xFF0284C7)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Two Column Layout: Left Garment List + Right Customer & Invoice Box
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Garment Items Table)
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Order Items (${widget.order.items.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 16),

                                    // Table Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                                      child: Row(
                                        children: const [
                                          Expanded(flex: 3, child: Text('ITEM NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 2, child: Text('SERVICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 1, child: Text('QTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 1, child: Text('RATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 1, child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Item Rows
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: widget.order.items.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final item = widget.order.items[idx];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                                                      child: const Icon(Icons.dry_cleaning_rounded, size: 16, color: Color(0xFF1A4FD6)),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(item.itemTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                  ],
                                                ),
                                              ),
                                              Expanded(flex: 2, child: Text(item.serviceType, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                              Expanded(flex: 1, child: Text('${item.quantity} pcs', style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)))),
                                              Expanded(flex: 1, child: Text('₹${item.unitPrice.toInt()}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                              Expanded(flex: 1, child: Text('₹${item.totalPrice.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(),
                                    const SizedBox(height: 12),

                                    // Invoice Calculations Summary
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Subtotal', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                        Text('₹${widget.order.totalAmount.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Text('Express Delivery Fee (1.5x)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                        Text('₹0', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Text('Tax (GST Included)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                        Text('₹0', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        Text('₹${widget.order.totalAmount.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Right Column (Customer & Payment Summary)
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  // Customer Details Card
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Customer Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: const Color(0xFFEEF2FF),
                                              child: Text(widget.order.customerName[0], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(widget.order.customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                Text(widget.order.customerPhone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(),
                                        const SizedBox(height: 12),

                                        const Text('Delivery Address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                        const SizedBox(height: 4),
                                        const Text('Hbr layout, Bengaluru - 560064', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Payment Action Card
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Payment Balance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                            Text(
                                              _paymentStatus,
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text('₹${widget.order.totalAmount.toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 16),

                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _paymentStatus = isPaid ? 'UNPAID' : 'PAID';
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isPaid ? const Color(0xFF64748B) : const Color(0xFF10B981),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            child: Text(
                                              isPaid ? 'Mark as Unpaid' : 'Collect Payment (Mark Paid)',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildStepItem(String title, int stepIndex, int currentActiveIndex) {
    final isDone = stepIndex <= currentActiveIndex;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF1A4FD6) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.circle_outlined,
            size: 16,
            color: isDone ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: TextStyle(fontSize: 11, fontWeight: isDone ? FontWeight.bold : FontWeight.normal, color: isDone ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 20),
        color: isActive ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildStatusActionButton(String statusLabel, Color color) {
    return OutlinedButton(
      onPressed: () {
        setState(() => _currentStatus = statusLabel);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $statusLabel!'), backgroundColor: color),
        );
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
