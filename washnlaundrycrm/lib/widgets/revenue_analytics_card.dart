import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/navigation.dart';
import 'panel_card.dart';

/// "Revenue Analytics — This month overview": collection progress bar plus the
/// sales / collected / uncollected / expenses / net profit breakdown.
class RevenueAnalyticsCard extends StatelessWidget {
  const RevenueAnalyticsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final analytics =
        provider.stats['revenue_analytics'] as Map<String, dynamic>? ??
            const {};

    final progress =
        (analytics['collection_progress'] as num?)?.toDouble() ?? 0;
    final netProfit = (analytics['net_profit'] as num?)?.toDouble() ?? 0;

    return PanelCard(
      title: 'Revenue Analytics',
      subtitle: 'This month overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COLLECTION PROGRESS',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.7,
                ),
              ),
              Text(
                '${progress.toStringAsFixed(progress % 1 == 0 ? 0 : 1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4FD6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1A4FD6)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatRupees(analytics['collected'])} collected',
                style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
              ),
              Text(
                '${formatRupees(analytics['uncollected'])} pending',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _figure('Sales', formatRupees(analytics['sales']),
                  const Color(0xFF0F172A)),
              _figure('Collected', formatRupees(analytics['collected']),
                  const Color(0xFF10B981)),
              _figure('Uncollected', formatRupees(analytics['uncollected']),
                  const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              _figure(
                'Monthly Expenses',
                formatRupees(analytics['expenses']),
                const Color(0xFFDC2626),
              ),
              _figure(
                'Net Profit',
                formatRupees(netProfit),
                netProfit >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFDC2626),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.goSection(9),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Full Reports',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A4FD6),
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward, size: 12, color: Color(0xFF1A4FD6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _figure(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
