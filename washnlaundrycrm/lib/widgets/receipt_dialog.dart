import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';

class ReceiptDialog extends StatelessWidget {
  final OrderModel order;

  const ReceiptDialog({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shop Header
            const Text('LaundryBill Express', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
            const Text('Noida Sector 18 Branch • +91 98765 43210', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const Divider(height: 24),

            // Order Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ORDER NUMBER', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text('#${order.orderNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('CUSTOMER', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text(order.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(order.customerPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Garments List Table
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: order.items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${it.itemTitle} x${it.quantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('₹${it.totalPrice.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Totals Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Bill:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('₹${order.totalAmount.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
              ],
            ),
            const SizedBox(height: 16),

            // QR Code for Tracking
            QrImageView(
              data: 'https://app.laundrybill.com/track/${order.orderNumber}',
              version: QrVersions.auto,
              size: 100.0,
            ),
            const SizedBox(height: 6),
            const Text('Scan to Track Live Order Status', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareWhatsapp(order),
                    icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 16),
                    label: const Text('WhatsApp Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareWhatsapp(OrderModel order) async {
    final cleanPhone = order.customerPhone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent('Hello ${order.customerName},\nThank you for choosing LaundryBill!\nYour Order #${order.orderNumber} is processed.\nTotal: ₹${order.totalAmount.toInt()}\nThank you!');
    final url = Uri.parse('https://wa.me/91$cleanPhone?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
