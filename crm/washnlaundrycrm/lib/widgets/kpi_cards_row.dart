import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'panel_card.dart';

class KpiCardsRow extends StatelessWidget {
  const KpiCardsRow({Key? key}) : super(key: key);

  static const _muted = Color(0xFF94A3B8);
  static const _up = Color(0xFF10B981);
  static const _down = Color(0xFFDC2626);

  /// "▲ 12% vs yesterday", or "— vs yesterday" when there is nothing to
  /// compare against. A missing comparison is not a 0% change, which is the
  /// same rule [formatPercent] enforces across the rest of the dashboard.
  static String _changeLabel(double? change) {
    if (change == null) return '— vs yesterday';
    final arrow = change >= 0 ? '▲' : '▼';
    return '$arrow ${formatPercent(change.abs())} vs yesterday';
  }

  static Color _changeColor(double? change) {
    if (change == null) return _muted;
    return change >= 0 ? _up : _down;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    final cards = [
      {
        'title': 'Orders today',
        'value': '${provider.ordersToday}',
        'subtext': _changeLabel(provider.ordersTodayChange),
        'subtextColor': _changeColor(provider.ordersTodayChange),
        'icon': Icons.inventory_2_outlined,
        'iconBg': const Color(0xFFEFF6FF),
        'iconColor': const Color(0xFF1A4FD6),
      },
      {
        'title': 'Revenue today',
        'value': formatRupees(provider.revenueToday),
        'subtext': _changeLabel(provider.revenueTodayChange),
        'subtextColor': _changeColor(provider.revenueTodayChange),
        'icon': Icons.attach_money_rounded,
        'iconBg': const Color(0xFFECFDF5),
        'iconColor': const Color(0xFF10B981),
      },
      {
        'title': 'Ready for pickup',
        'value': '${provider.readyForPickup}',
        'subtext': '• live in queue',
        'subtextColor': const Color(0xFF1A4FD6),
        'icon': Icons.inventory_2_outlined,
        'iconBg': const Color(0xFFEFF6FF),
        'iconColor': const Color(0xFF1A4FD6),
      },
      {
        'title': 'Overdue',
        'value': '${provider.overdueCount}',
        'subtext': 'needs action',
        'subtextColor': const Color(0xFFD97706),
        'icon': Icons.access_time_rounded,
        'iconBg': const Color(0xFFFFFBEB),
        'iconColor': const Color(0xFFD97706),
      },
      {
        'title': 'Customers',
        'value': '${provider.customersTotal}',
        'subtext': '+${provider.customersNewToday ?? 0} new today',
        'subtextColor': (provider.customersNewToday ?? 0) > 0 ? _up : _muted,
        'icon': Icons.credit_card_outlined,
        'iconBg': const Color(0xFFF3E8FF),
        'iconColor': const Color(0xFFA855F7),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 5;
        if (constraints.maxWidth < 1100 && constraints.maxWidth >= 700) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth < 700) {
          crossAxisCount = 1;
        }

        if (crossAxisCount == 5) {
          return Row(
            children: cards
                .map((c) => Expanded(
                        child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildCard(c),
                    )))
                .toList(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(
                    width: (constraints.maxWidth - (crossAxisCount - 1) * 12) /
                        crossAxisCount,
                    child: _buildCard(c),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildCard(Map<String, dynamic> c) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c['iconBg'] as Color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(c['icon'] as IconData,
                    size: 18, color: c['iconColor'] as Color),
              ),
              Text(
                c['title'] as String,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            c['value'] as String,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                height: 1.1),
          ),
          const SizedBox(height: 8),
          Text(
            c['subtext'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c['subtextColor'] as Color,
            ),
          ),
        ],
      ),
    );
  }
}
