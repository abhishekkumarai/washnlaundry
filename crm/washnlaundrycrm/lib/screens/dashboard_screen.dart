import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/navigation.dart';
import '../widgets/app_shell.dart';
import '../widgets/dashboard_side_panels.dart';
import '../widgets/kpi_cards_row.dart';
import '../widgets/load_state.dart';
import '../widgets/order_pipeline_card.dart';
import '../widgets/panel_card.dart';
import '../widgets/recent_activity_card.dart';
import '../widgets/revenue_analytics_card.dart';
import '../widgets/revenue_chart_card.dart';
import '../widgets/store_health_card.dart';
import '../widgets/top_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  /// Below this the two-column sections stack instead. Measured against the
  /// content area (viewport minus the 240px rail and 24px padding), so a
  /// ~1366px laptop still gets the two-column layout the live app uses.
  static const double _wideBreakpoint = 990;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 200;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: Column(
          children: [
            TopHeader(
              title: 'Dashboard',
              onActionPressed: () => context.goSection(1),
            ),
            Expanded(child: _body(provider)),
          ],
        ),
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
        final isWide = constraints.maxWidth > DashboardScreen._wideBreakpoint;
        final isCollapsible = !isWide;

        return Stack(
          children: [
            SingleChildScrollView(
              key: const Key('dashboard_scroll_view'),
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWide)
                    const KpiCardsRow()
                  else
                    const PanelCard(
                      title: 'Key Metrics',
                      subtitle: "Today's summary",
                      collapsible: true,
                      child: KpiCardsRow(),
                    ),
                  const SizedBox(height: 20),

                  // Revenue trend beside the live pipeline.
                  _twoColumn(
                    isWide: isWide,
                    leftFlex: 7,
                    rightFlex: 5,
                    left: RevenueChartCard(collapsible: isCollapsible),
                    right: OrderPipelineCard(collapsible: isCollapsible),
                  ),
                  const SizedBox(height: 20),

                  // Operational health beside the money view.
                  _twoColumn(
                    isWide: isWide,
                    leftFlex: 6,
                    rightFlex: 6,
                    left: StoreHealthCard(collapsible: isCollapsible),
                    right: RevenueAnalyticsCard(collapsible: isCollapsible),
                  ),
                  const SizedBox(height: 20),

                  // Activity table beside the action panels.
                  _twoColumn(
                    isWide: isWide,
                    leftFlex: 7,
                    rightFlex: 5,
                    left: RecentActivityCard(collapsible: isCollapsible),
                    right: Column(
                      children: [
                        NeedsAttentionCard(collapsible: isCollapsible),
                        const SizedBox(height: 20),
                        OrderChannelsCard(collapsible: isCollapsible),
                        const SizedBox(height: 20),
                        StaffAttendanceCard(collapsible: isCollapsible),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isWide && _showScrollToTop)
              Positioned(
                right: 20,
                bottom: 20,
                child: FloatingActionButton.small(
                  key: const Key('dashboard_scroll_to_top'),
                  heroTag: 'dashboard_scroll_to_top',
                  tooltip: 'Scroll to top',
                  onPressed: _scrollToTop,
                  backgroundColor: const Color(0xFF182C4F),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
          ],
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
