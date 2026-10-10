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
        'iconColor': const Color(0xFF182C4F),
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
        'subtextColor': const Color(0xFF182C4F),
        'icon': Icons.inventory_2_outlined,
        'iconBg': const Color(0xFFEFF6FF),
        'iconColor': const Color(0xFF182C4F),
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
        'iconBg': const Color(0xFFEFF6FF),
        'iconColor': const Color(0xFF2563EB),
      },
    ];

    // One inline row at every width. When the five cards fit at their minimum
    // width they share the row equally; below that the row scrolls sideways
    // instead of wrapping onto extra lines or squeezing the text.
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = cards.length * _minCardWidth + (cards.length - 1) * _gap;
        final fits = !constraints.hasBoundedWidth || constraints.maxWidth >= needed;

        Widget row(Widget Function(Map<String, dynamic>) wrap) => IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    wrap(cards[i]),
                  ],
                ],
              ),
            );

        if (fits) {
          return row((c) => Expanded(child: _buildCard(c)));
        }
        return SingleChildScrollView(
          key: const ValueKey('kpi-scroll'),
          scrollDirection: Axis.horizontal,
          child: row((c) => SizedBox(width: _scrollCardWidth, child: _buildCard(c))),
        );
      },
    );
  }

  /// Smallest a card may get while the five still share the row.
  static const double _minCardWidth = 112;

  /// Card width once the row scrolls (a little wider so labels stay readable).
  static const double _scrollCardWidth = 132;
  static const double _gap = 8;

  /// Compact card: icon + title on one line, the figure, then the delta. Text
  /// ellipsises and the figure scales down, so a long rupee amount or a long
  /// label can never overflow the card.
  Widget _buildCard(Map<String, dynamic> c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c['iconBg'] as Color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(c['icon'] as IconData,
                    size: 14, color: c['iconColor'] as Color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c['title'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              c['value'] as String,
              maxLines: 1,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: Color(0xFF141A24),
                  height: 1.1),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            c['subtext'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c['subtextColor'] as Color,
            ),
          ),
        ],
      ),
    );
  }
}
