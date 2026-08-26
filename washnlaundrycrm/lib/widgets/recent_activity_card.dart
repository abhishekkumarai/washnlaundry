import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../utils/navigation.dart';
import 'panel_card.dart';
import 'status_pill.dart';
import 'receipt_dialog.dart';

/// "Recent activity" — the live app renders this as a table with
/// TIME · ORDER · CUSTOMER · TYPE · PAYMENT · STATUS.
class RecentActivityCard extends StatelessWidget {
  final int limit;

  const RecentActivityCard({super.key, this.limit = 8});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final orders = provider.filteredOrders.take(limit).toList();

    return PanelCard(
      title: 'Recent activity',
      trailing: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${provider.filteredOrders.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.goSection(2),
            child: const Text(
              'View all',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A4FD6),
              ),
            ),
          ),
        ],
      ),
      child: orders.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No orders yet',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  _headerRow(),
                  const SizedBox(height: 4),
                  for (final order in orders) _dataRow(context, order),
                ],
              ),
            ),
    );
  }

  Widget _headerRow() {
    const style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Color(0xFF94A3B8),
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: const [
          SizedBox(width: 58, child: Text('TIME', style: style)),
          SizedBox(width: 118, child: Text('ORDER', style: style)),
          SizedBox(width: 170, child: Text('CUSTOMER', style: style)),
          SizedBox(width: 12),
          SizedBox(width: 110, child: Text('TYPE', style: style)),
          SizedBox(width: 80, child: Text('PAYMENT', style: style)),
          SizedBox(width: 110, child: Text('STATUS', style: style)),
          SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _dataRow(BuildContext context, OrderModel order) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0xFFF8FAFC),
        onTap: () => context.go('/orders/${order.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                child: Text(
                  DateFormat('HH:mm').format(order.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              SizedBox(
                width: 118,
                child: Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A4FD6),
                  ),
                ),
              ),
              SizedBox(
                width: 170,
                child: Text(
                  order.customerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        order.deliveryTypeLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  order.paymentStatusLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: paymentColor(order.paymentStatus),
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor(order.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            size: 5, color: statusColor(order.status)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            order.statusLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: statusColor(order.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Receipt',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ReceiptDialog(
                      order: order,
                      shop: context.read<AppProvider>().shop,
                    ),
                  ),
                  icon: const Icon(Icons.receipt_outlined,
                      size: 17, color: Color(0xFF1A4FD6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
