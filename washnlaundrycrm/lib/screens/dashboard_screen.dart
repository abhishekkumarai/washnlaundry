import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/dashboard_side_panels.dart';
import '../widgets/kpi_cards_row.dart';
import '../widgets/load_state.dart';
import '../widgets/order_pipeline_card.dart';
import '../widgets/quick_scan_card.dart';
import '../widgets/recent_activity_card.dart';
import '../widgets/revenue_analytics_card.dart';
import '../widgets/revenue_chart_card.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/store_health_card.dart';
import '../widgets/top_header.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// Below this the two-column sections stack instead. Measured against the
  /// content area (viewport minus the 240px rail and 24px padding), so a
  /// ~1366px laptop still gets the two-column layout the live app uses.
  static const double _wideBreakpoint = 990;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                TopHeader(
                  onNewOrderPressed: () => provider.setNavIndex(1),
                ),
                Expanded(child: _body(provider)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AppProvider provider) {
    if (provider.isLoading && provider.stats.isEmpty) {
      return const LoadingState();
    }
    if (provider.hasError && provider.orders.isEmpty) {
      return ErrorState(message: provider.error!);
    }

    // LayoutBuilder wraps the scroll view rather than sitting inside it: nested
    // in an unbounded-height context it collapses the scrollable extent and the
    // dashboard stops scrolling entirely.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > _wideBreakpoint;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const QuickScanCard(),
              const SizedBox(height: 20),
              const KpiCardsRow(),
              const SizedBox(height: 20),

              // Revenue trend beside the live pipeline.
              _twoColumn(
                isWide: isWide,
                leftFlex: 7,
                rightFlex: 5,
                left: const RevenueChartCard(),
                right: const OrderPipelineCard(),
              ),
              const SizedBox(height: 20),

              // Operational health beside the money view.
              _twoColumn(
                isWide: isWide,
                leftFlex: 6,
                rightFlex: 6,
                left: const StoreHealthCard(),
                right: const RevenueAnalyticsCard(),
              ),
              const SizedBox(height: 20),

              // Activity table beside the action panels.
              _twoColumn(
                isWide: isWide,
                leftFlex: 7,
                rightFlex: 5,
                left: const RecentActivityCard(),
                right: const Column(
                  children: [
                    NeedsAttentionCard(),
                    SizedBox(height: 20),
                    OrderChannelsCard(),
                    SizedBox(height: 20),
                    StaffAttendanceCard(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _twoColumn({
    required bool isWide,
    required int leftFlex,
    required int rightFlex,
    required Widget left,
    required Widget right,
  }) {
    if (!isWide) {
      return Column(
        children: [left, const SizedBox(height: 20), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        const SizedBox(width: 20),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}
