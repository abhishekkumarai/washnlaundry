import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'panel_card.dart';

/// "Needs attention": the four things that should pull the owner into action.
class NeedsAttentionCard extends StatelessWidget {
  const NeedsAttentionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final data =
        provider.stats['needs_attention'] as Map<String, dynamic>? ?? const {};

    int count(String key) => (data[key] as num?)?.toInt() ?? 0;
    final outstanding = formatRupees(data['unpaid_outstanding']);

    return PanelCard(
      title: 'Needs attention',
      child: Column(
        children: [
          StatRow(
            icon: Icons.event_available_rounded,
            iconColor: const Color(0xFF1A4FD6),
            iconBackground: const Color(0xFFEEF2FF),
            label: 'Scheduled ahead',
            caption: 'Booked for a later day',
            value: '${count('scheduled_ahead')}',
          ),
          StatRow(
            icon: Icons.schedule_rounded,
            iconColor: const Color(0xFFD97706),
            iconBackground: const Color(0xFFFEF3C7),
            label: 'Overdue orders',
            caption: 'Past scheduled window',
            value: '${count('overdue_orders')}',
            valueColor: const Color(0xFFD97706),
          ),
          StatRow(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBackground: const Color(0xFFFEE2E2),
            label: 'Unpaid invoices',
            caption: '$outstanding outstanding',
            value: '${count('unpaid_invoices')}',
            valueColor: const Color(0xFFDC2626),
          ),
          StatRow(
            icon: Icons.inventory_2_rounded,
            iconColor: const Color(0xFF0284C7),
            iconBackground: const Color(0xFFE0F2FE),
            label: 'Online orders',
            caption: 'From public page',
            value: '${count('online_orders')}',
          ),
        ],
      ),
    );
  }
}

/// "Order channels": where today's orders came in from.
class OrderChannelsCard extends StatelessWidget {
  const OrderChannelsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final data =
        provider.stats['order_channels'] as Map<String, dynamic>? ?? const {};

    int count(String key) => (data[key] as num?)?.toInt() ?? 0;

    const channels = [
      ('store_pickup', 'Store Pickup'),
      ('home_pickup', 'Home Pickup'),
      ('home_delivery', 'Home Delivery'),
      ('online', 'Online'),
    ];

    final total = channels.fold<int>(0, (sum, c) => sum + count(c.$1));

    return PanelCard(
      title: 'Order channels',
      trailing: const Text(
        'today',
        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      ),
      child: Column(
        children: [
          for (final (key, label) in channels)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF334155)),
                      ),
                      Text(
                        '${count(key)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : count(key) / total,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFF1A4FD6)),
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

/// "Staff attendance": today's present / absent / leave split.
class StaffAttendanceCard extends StatelessWidget {
  const StaffAttendanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final data =
        provider.stats['staff_attendance'] as Map<String, dynamic>? ?? const {};

    int count(String key) => (data[key] as num?)?.toInt() ?? 0;

    return PanelCard(
      title: 'Staff attendance',
      child: Column(
        children: [
          Row(
            children: [
              _tile('Present', count('present'), const Color(0xFF10B981)),
              _tile('Absent', count('absent'), const Color(0xFFDC2626)),
              _tile('Leave', count('leave'), const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Total staff: ${count('total_staff')}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
