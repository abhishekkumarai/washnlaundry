import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../utils/money.dart';

class ReceiptDialog extends StatelessWidget {
  final OrderModel order;

  /// The shop profile from `/api/shops/`. The header used to be hardcoded to a
  /// Noida branch that has nothing to do with the seeded shop.
  ///
  /// Required — still nullable, because the shop may not have loaded yet, but
  /// callers must pass it deliberately. Three of the four call sites used to
  /// omit it and silently print the 'LaundryBill' fallback with no address or
  /// phone on the receipt.
  final Map<String, dynamic>? shop;

  const ReceiptDialog({Key? key, required this.order, required this.shop})
      : super(key: key);

  String get _shopName => (shop?['name'] as String?)?.trim().isNotEmpty == true
      ? shop!['name'] as String
      : 'LaundryBill';

  /// "Hbr layout, Bengaluru • +91 98765 43210" — whichever parts we have.
  String get _shopSubtitle {
    final address = (shop?['address'] as String?)?.trim() ?? '';
    final city = (shop?['city'] as String?)?.trim() ?? '';
    // The seeded address already ends in the city, which rendered as
    // "Hbr layout, Bengaluru, Bengaluru".
    final includeCity =
        city.isNotEmpty && !address.toLowerCase().contains(city.toLowerCase());
    final where = [
      if (address.isNotEmpty) address,
      if (includeCity) city,
    ].join(', ');

    final phone = (shop?['phone'] as String?)?.trim() ?? '';
    return [
      if (where.isNotEmpty) where,
      if (phone.isNotEmpty) phone,
    ].join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _shopSubtitle;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: math.min(420.0, MediaQuery.sizeOf(context).width - 48),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shop Header
            Text(_shopName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A4FD6))),
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const Divider(height: 24),

            // Order Info
            // Both columns flex — a long customer name used to overflow the
            // 372px content width rather than eliding.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ORDER NUMBER',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8))),
                      Text('#${order.orderNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('CUSTOMER',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(order.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A))),
                      if (order.customerPhone.isNotEmpty)
                        Text(order.customerPhone,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
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
                        Text('${it.itemTitle} x${it.quantity}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('${Money.symbol}${it.totalPrice.toInt()}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
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
                const Text('Total Bill:',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('${Money.symbol}${order.totalAmount.toInt()}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A4FD6))),
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
            const Text('Scan to Track Live Order Status',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    // No phone means a walk-in with nothing to message. It used
                    // to fall back to a hardcoded number and bill a stranger.
                    onPressed: order.customerPhone.isEmpty
                        ? null
                        : () => _shareWhatsapp(order),
                    icon: const Icon(Icons.chat_rounded,
                        color: Colors.white, size: 16),
                    label: const Text('WhatsApp Bill',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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
    final msg = Uri.encodeComponent(
        'Hello ${order.customerName},\nThank you for choosing LaundryBill!\nYour Order #${order.orderNumber} is processed.\nTotal: ${Money.symbol}${order.totalAmount.toInt()}\nThank you!');
    final url = Uri.parse('https://wa.me/91$cleanPhone?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
