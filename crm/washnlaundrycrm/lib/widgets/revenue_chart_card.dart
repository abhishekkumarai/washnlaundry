import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import 'panel_card.dart';

/// "Revenue — last 14 days".
///
/// Every bar used to be invented: the series was
/// `index == 13 ? revenueToday : (index % 3 == 0 ? 40.0 : 0.0)` and the axis
/// was hardcoded to days 16..29 whatever the date. It now plots
/// `revenue_series` from `/api/dashboard/stats/`, which has always been in the
/// payload.
class RevenueChartCard extends StatelessWidget {
  final bool collapsible;

  const RevenueChartCard({super.key, this.collapsible = false});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    final series = provider.revenueSeries;
    final days = series.map((p) => '${p.day}').toList();

    final double peak = series.isEmpty
        ? 0
        : series.map((p) => p.amount).reduce((a, b) => a > b ? a : b);
    final double total = series.fold(0.0, (sum, p) => sum + p.amount);

    // Headroom above the tallest bar so it never touches the container top.
    // The 350 floor keeps the axis readable on a quiet fortnight.
    final double maxY = peak > 300 ? (peak * 1.25) : 350.0;

    return PanelCard(
      title: 'Revenue',
      subtitle: 'Last 14 days',
      collapsible: collapsible,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // The total across the window — the subtitle says "last 14
          // days", so a single day's figure never belonged here.
          Text(
            formatRupees(total),
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            provider.revenueTodayChange == null
                ? '— vs prior'
                : '${provider.revenueTodayChange! >= 0 ? '▲' : '▼'} '
                    '${formatPercent(provider.revenueTodayChange!.abs())} vs prior',
            style: TextStyle(
                fontSize: 11,
                color: provider.revenueTodayChange == null
                    ? const Color(0xFF94A3B8)
                    : provider.revenueTodayChange! >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626)),
          ),
        ],
      ),
      child: series.isEmpty
          ? const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'No revenue recorded in the last 14 days',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          : ClipRect(
              child: SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: barTouchDataEnabled(series),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < days.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  days[index],
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value == 0)
                              return const Text('0',
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF94A3B8)));
                            final third = maxY / 3;
                            if ((value - third).abs() < (third * 0.2)) {
                              return Text(
                                  '${(third / 1000).toStringAsFixed(1)}k',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF94A3B8)));
                            }
                            if ((value - (third * 2)).abs() < (third * 0.2)) {
                              return Text(
                                  '${((third * 2) / 1000).toStringAsFixed(1)}k',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF94A3B8)));
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: getHorizontalLine,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(series.length, (index) {
                      final val = series[index].amount;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            // A day with no revenue still draws a stub, so the
                            // axis reads as 14 days rather than a gap.
                            toY: val == 0 ? 4 : val,
                            color: const Color(0xFF1A4FD6),
                            width: 12,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
    );
  }

  static FlLine getHorizontalLine(double value) {
    return const FlLine(
      color: Color(0xFFF1F5F9),
      strokeWidth: 1,
    );
  }

  BarTouchData barTouchDataEnabled(List<RevenueSeriesPointModel> series) {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        // The chart sits inside a ClipRect, so a tooltip drawn above the
        // tallest bar (or past the first/last one) would be cut off.
        fitInsideVertically: true,
        fitInsideHorizontally: true,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final point =
              group.x >= 0 && group.x < series.length ? series[group.x] : null;
          // The rod's height is floored at 4 for empty days, so report the
          // point's real amount rather than reading it back off the bar.
          final label = point == null ? '' : '${point.date}\n';
          final amount = point?.amount ?? rod.toY;
          return BarTooltipItem(
            '$label${formatRupees(amount)}',
            const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          );
        },
      ),
    );
  }
}
