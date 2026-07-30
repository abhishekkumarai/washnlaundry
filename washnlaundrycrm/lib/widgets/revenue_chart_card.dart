import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class RevenueChartCard extends StatelessWidget {
  const RevenueChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Days 16 through 29
    final days = List.generate(14, (index) => (16 + index).toString());

    // Calculate dynamic maxY so bars never overflow the container height
    final double maxRevenue = provider.revenueToday;
    final double maxY = maxRevenue > 300 ? (maxRevenue * 1.25) : 350.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Revenue',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Last 14 days',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${maxRevenue.toInt()}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '— vs prior',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          ClipRect(
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: barTouchDataEnabled(),
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
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
                          if (value == 0) return const Text('0', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)));
                          final third = maxY / 3;
                          if ((value - third).abs() < (third * 0.2)) {
                            return Text('${(third / 1000).toStringAsFixed(1)}k', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)));
                          }
                          if ((value - (third * 2)).abs() < (third * 0.2)) {
                            return Text('${((third * 2) / 1000).toStringAsFixed(1)}k', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: getHorizontalLine,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(14, (index) {
                    final val = index == 13 ? maxRevenue : (index % 3 == 0 ? 40.0 : 0.0);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
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
        ],
      ),
    );
  }

  static FlLine getHorizontalLine(double value) {
    return const FlLine(
      color: Color(0xFFF1F5F9),
      strokeWidth: 1,
    );
  }

  BarTouchData barTouchDataEnabled() {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return BarTooltipItem(
            'Day ${group.x + 16}\n₹${rod.toY.toInt()}',
            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          );
        },
      ),
    );
  }
}
