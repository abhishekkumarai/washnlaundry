import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order_model.dart';
import '../utils/money.dart';

class ReceiptDialog extends StatefulWidget {
  final OrderModel order;
  final Map<String, dynamic>? shop;

  const ReceiptDialog({Key? key, required this.order, required this.shop})
      : super(key: key);

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  String get _shopName =>
      (widget.shop?['name'] as String?)?.trim().isNotEmpty == true
          ? widget.shop!['name'] as String
          : 'LaundryBill';

  String get _shopSubtitle {
    final address = (widget.shop?['address'] as String?)?.trim() ?? '';
    final city = (widget.shop?['city'] as String?)?.trim() ?? '';
    final includeCity =
        city.isNotEmpty && !address.toLowerCase().contains(city.toLowerCase());
    final where = [
      if (address.isNotEmpty) address,
      if (includeCity) city,
    ].join(', ');

    final phone = (widget.shop?['phone'] as String?)?.trim() ?? '';
    return [
      if (where.isNotEmpty) where,
      if (phone.isNotEmpty) phone,
    ].join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _shopSubtitle;
    final order = widget.order;

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
                              fontWeight: FontWeight.w600,
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

            // Item List Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              color: const Color(0xFFF1F5F9),
              child: Row(
                children: const [
                  Expanded(
                      flex: 3,
                      child: Text('ITEM',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569)))),
                  Expanded(
                      flex: 1,
                      child: Text('QTY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569)))),
                  Expanded(
                      flex: 2,
                      child: Text('PRICE',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Items (capped height with scroll)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: order.items.length,
                itemBuilder: (ctx, i) {
                  final it = order.items[i];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text(it.itemTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 1,
                            child: Text('${it.quantity}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 2,
                            child: Text(
                                '${Money.symbol}${it.totalPrice.toInt()}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 16),

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
                const Spacer(),
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
}
