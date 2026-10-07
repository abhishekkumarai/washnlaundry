import 'package:flutter/material.dart';

import '../models/order_model.dart';

/// Colour key for order status, shared by the Orders table and the dashboard's
/// Recent activity so the two can never drift apart.
Color statusColor(String status) {
  switch (status) {
    case OrderStatus.placed:
      return const Color(0xFF64748B);
    case OrderStatus.processing:
    case OrderStatus.ironing:
      return const Color(0xFF0284C7);
    case OrderStatus.ready:
      return const Color(0xFF182C4F);
    case OrderStatus.outForDelivery:
      return const Color(0xFFD97706);
    case OrderStatus.delivered:
      return const Color(0xFF10B981);
    case OrderStatus.cancelled:
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF64748B);
  }
}

Color paymentColor(String payment) {
  switch (payment) {
    case PaymentStatus.paid:
      return const Color(0xFF10B981);
    case PaymentStatus.partial:
      return const Color(0xFFD97706);
    default:
      return const Color(0xFFDC2626);
  }
}

/// Dot + label pill. Always renders the human label, never the raw enum.
class StatusPill extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusPill({super.key, required this.status, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 5, color: color),
          const SizedBox(width: 5),
          Text(
            OrderStatus.label(status),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Relative time, matching how the live app writes the UPDATED column
/// ("Yesterday", "7h ago").
String relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}
