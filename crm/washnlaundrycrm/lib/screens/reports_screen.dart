import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/load_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';
import '../utils/money.dart';

/// `/reports` in the live app. Not captured yet, so this follows our own
/// conventions rather than cloning a screenshot — see LIVE_AUDIT.md
/// "Not captured". The live route is reachable (there are no plan tiers), so
/// it can be captured and this screen checked against it.
///
/// Every figure comes from `/api/reports/`. The screen used to hardcode all of
/// them, down to an eight-month bar chart whose heights were typed in by hand
/// and a status breakdown listing "Washing", a status the model does not have.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedPeriod = 0; // 0: This Month, 1: Last Month, 2: Custom
  DateTimeRange _customDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  /// The palette the breakdown rows cycle through. Which statuses and services
  /// come back is server-driven now, so colours can no longer be hardcoded per
  /// label the way they were.
  static const _palette = [
    Color(0xFF1A4FD6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFA855F7),
    Color(0xFFEF4444),
    Color(0xFF0284C7),
    Color(0xFFD97706),
  ];

  static Color _colorAt(int index) => _palette[index % _palette.length];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  /// The date range the current period selection means.
  DateTimeRange get _range {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0:
        return DateTimeRange(start: DateTime(now.year, now.month), end: now);
      case 1:
        final start = DateTime(now.year, now.month - 1);
        // Day zero of this month is the last day of the previous one.
        return DateTimeRange(
            start: start, end: DateTime(now.year, now.month, 0));
      default:
        return _customDateRange;
    }
  }

  void _load() {
    final range = _range;
    context.read<AppProvider>().loadReportsFor(range.start, range.end);
  }

  void _selectPeriod(int index) {
    setState(() => _selectedPeriod = index);
    _load();
  }

  /// Takes no BuildContext parameter: a parameter would shadow `State.context`
  /// and the `mounted` check after the await guards the State.
  Future<void> _pickCustomDateRange() async {
    final picked = await AppDatePicker.pickDateRange(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialRange: _customDateRange,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _customDateRange = picked;
      _selectedPeriod = 2;
    });
    _load();
  }

  /// Real month arithmetic. The old version said "July 2026" / "June 2026",
  /// which was correct for exactly one month of one year.
  String get _periodText {
    final range = _range;
    if (_selectedPeriod == 2) {
      return '${DateFormat('dd MMM').format(range.start)} - '
          '${DateFormat('dd MMM yyyy').format(range.end)}';
    }
    return DateFormat('MMMM yyyy').format(range.start);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return Column(
              children: [
                narrow ? _narrowHeader() : _header(),
                Expanded(child: _body(provider)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Below [SidebarNavigation.contentWideBreakpoint]: title (Expanded, ellipsis) with Print/Export
  /// PDF collapsed into an overflow menu (both are disabled no-ops today
  /// anyway — see the comment on the wide buttons below), and the period
  /// buttons + custom-date button moved to their own horizontal-scroll row,
  /// matching Staff's/Services' sub-tab pattern.
  Widget _narrowHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Financial Reports',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                    Text(_periodText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                icon: const Icon(Icons.more_vert_rounded,
                    size: 20, color: Color(0xFF475569)),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    enabled: false,
                    value: 'print',
                    child: Text('Print'),
                  ),
                  PopupMenuItem(
                    enabled: false,
                    value: 'export',
                    child: Text('Export PDF'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildPeriodButton(0, 'This Month'),
                const SizedBox(width: 8),
                _buildPeriodButton(1, 'Last Month'),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickCustomDateRange,
                  icon: const Icon(Icons.calendar_month_rounded,
                      size: 14, color: Color(0xFF475569)),
                  label: Text(
                    _selectedPeriod == 2 ? _periodText : 'Custom',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _selectedPeriod == 2
                          ? const Color(0xFF1A4FD6)
                          : const Color(0xFF334155),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: _selectedPeriod == 2
                            ? const Color(0xFF1A4FD6)
                            : const Color(0xFFE2E8F0)),
                    backgroundColor: _selectedPeriod == 2
                        ? const Color(0xFFEEF2FF)
                        : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Financial Reports',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
              Text(_periodText,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const Spacer(),

          _buildPeriodButton(0, 'This Month'),
          const SizedBox(width: 8),
          _buildPeriodButton(1, 'Last Month'),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _pickCustomDateRange,
            icon: const Icon(Icons.calendar_month_rounded,
                size: 14, color: Color(0xFF475569)),
            label: Text(
              _selectedPeriod == 2 ? _periodText : 'Custom',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _selectedPeriod == 2
                    ? const Color(0xFF1A4FD6)
                    : const Color(0xFF334155),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: _selectedPeriod == 2
                      ? const Color(0xFF1A4FD6)
                      : const Color(0xFFE2E8F0)),
              backgroundColor:
                  _selectedPeriod == 2 ? const Color(0xFFEEF2FF) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 14),

          // Print and Export PDF are deliberately still no-ops: neither has
          // been captured from the live app, so there is nothing to clone them
          // against yet. Disabled beats a button that silently does nothing.
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.print_outlined,
                size: 15, color: Color(0xFF94A3B8)),
            label: const Text('Print',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.download_rounded, size: 15),
            label: const Text('Export PDF',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AppProvider provider) {
    final report = provider.reports;

    if (provider.reportsError != null && report == null) {
      return ErrorState(
        title: 'Error loading reports',
        message: provider.reportsError!,
      );
    }
    if (provider.reportsLoading && report == null) {
      return const LoadingState();
    }
    if (report == null) {
      return const LoadingState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.reportsError != null) ...[
            _inlineError(provider.reportsError!),
            const SizedBox(height: 16),
          ],
          _metricRow(report),
          const SizedBox(height: 20),
          _chartRow(report),
          const SizedBox(height: 20),
          _breakdownRow(report),
        ],
      ),
    );
  }

  Widget _inlineError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 17, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)))),
          TextButton(
            onPressed: _load,
            child: const Text('Retry',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }

  /// Money with thousands separators — "₹4,850", the format the screen has
  /// always shown. The symbol and the grouping both come from the shop now;
  /// this used to hardcode '₹' and an `en_IN` pattern.
  static String _money(double value) => Money.grouped(value);

  Widget _metricRow(ReportsModel r) {
    // An em dash for "no data" rather than a 0% that would read as a real
    // measurement — the same rule the dashboard's Store Health panel follows.
    final collectedSub = r.collectedPercent == null
        ? '—'
        : '${r.collectedPercent!.round()}% of billed';
    final marginSub = r.margin == null ? '—' : '${r.margin!.round()}% margin';

    final cards = [
      _buildMetricCard(
          'Revenue',
          _money(r.revenue),
          ReportsModel.changeLabel(r.revenueChange) ?? 'no prior period',
          Icons.trending_up_rounded,
          const Color(0xFF1A4FD6),
          const Color(0xFFEEF2FF)),
      _buildMetricCard('Collected', _money(r.collected), collectedSub,
          Icons.payments_outlined, const Color(0xFF10B981),
          const Color(0xFFECFDF5)),
      _buildMetricCard('Outstanding', _money(r.outstanding), 'to collect',
          Icons.hourglass_empty_rounded, const Color(0xFFF59E0B),
          const Color(0xFFFEF3C7)),
      _buildMetricCard(
          'Expenses',
          _money(r.expenses),
          ReportsModel.changeLabel(r.expensesChange) ?? 'no prior period',
          Icons.receipt_long_outlined,
          const Color(0xFFEF4444),
          const Color(0xFFFEF2F2)),
      _buildMetricCard(
          'Net Profit',
          _money(r.netProfit),
          marginSub,
          Icons.account_balance_wallet_outlined,
          r.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          r.netProfit >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2)),
      _buildMetricCard(
          'Orders',
          '${r.orderCount}',
          'avg ${_money(r.averageOrderValue)}',
          Icons.shopping_bag_outlined,
          const Color(0xFFA855F7),
          const Color(0xFFF3E8FF)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth < 420
            ? 2
            : constraints.maxWidth < 760
                ? 3
                : 6;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in cards) SizedBox(width: width, child: c)],
        );
      },
    );
  }

  Widget _chartRow(ReportsModel r) {
    // Normalise against the tallest bar in the series. The screen used to be
    // handed ratios and had no idea what scale they represented.
    final peak = r.monthlySeries.fold<double>(
      0,
      (max, m) => [max, m.revenue, m.expenses].reduce((a, b) => a > b ? a : b),
    );

    final revenueChart = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, headerConstraints) {
                    final titleBlock = Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.show_chart_rounded,
                              size: 18, color: Color(0xFF1A4FD6)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Revenue vs Expenses',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A))),
                              Text('Last 8 months',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ],
                    );
                    final legend = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: const Color(0xFF1A4FD6),
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        const Text('Revenue',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(width: 14),
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        const Text('Expenses',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    );
                    if (headerConstraints.maxWidth < 480) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleBlock,
                          const SizedBox(height: 10),
                          legend,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: titleBlock),
                        legend,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  height: 180,
                  child: r.monthlySeries.isEmpty
                      ? const Center(
                          child: Text('No history yet.',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8))))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final month in r.monthlySeries)
                              _buildBarPair(month, peak),
                          ],
                        ),
                ),
              ],
            ),
          );

    // Net Profit gauge — one color for the whole panel (ring, margin %, and
    // the profit figure itself), so a loss reads as loss everywhere at once
    // rather than green optimism next to a negative number.
    final profitColor =
        r.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final netProfitPanel = Container(
            height: 290,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Net Profit',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                const Spacer(),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          // Clamped: a margin can exceed 100% or go negative,
                          // and the arc cannot draw either.
                          value: ((r.margin ?? 0) / 100).clamp(0.0, 1.0),
                          strokeWidth: 14,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(profitColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.margin == null ? '—' : '${r.margin!.round()}%',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: profitColor),
                          ),
                          const Text('margin',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Center(
                  child: Column(
                    children: [
                      Text(_money(r.netProfit),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: profitColor)),
                      Text(
                        ReportsModel.changeLabel(r.netProfitChange) ??
                            'no prior period',
                        style: TextStyle(
                          fontSize: 11,
                          color: (r.netProfitChange ?? 0) >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Below this the two panels stop fitting side by side, same
        // shape as Order Detail's/Customer Detail's own stack breakpoint.
        final stacked =
            constraints.maxWidth < SidebarNavigation.contentStackBreakpoint;
        if (stacked) {
          return Column(
            children: [
              revenueChart,
              const SizedBox(height: 20),
              netProfitPanel,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: revenueChart),
            const SizedBox(width: 20),
            Expanded(flex: 1, child: netProfitPanel),
          ],
        );
      },
    );
  }

  Widget _breakdownRow(ReportsModel r) {
    final ordersBreakdown = Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.list_alt_rounded,
                    size: 18, color: Color(0xFF1A4FD6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Orders breakdown',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                    Text('${r.orderCount} orders in this period',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              // Below this, 3 breakdown columns squeeze too tight to read —
              // stack them instead, one below the other.
              final stackedColumns = constraints.maxWidth < 500;
              final status = _breakdownColumn('BY STATUS', r.byStatus);
              final type = _breakdownColumn('BY TYPE', r.byType);
              final service = _breakdownColumn('BY SERVICE', r.byService);
              if (stackedColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    status,
                    const SizedBox(height: 16),
                    type,
                    const SizedBox(height: 16),
                    service,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: status),
                  const SizedBox(width: 20),
                  Expanded(child: type),
                  const SizedBox(width: 20),
                  Expanded(child: service),
                ],
              );
            },
          ),
        ],
      ),
    );

    final paymentsMix = Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.credit_card_rounded,
                    size: 18, color: Color(0xFF1A4FD6)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payments mix',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                    Text('Collected by method',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (r.paymentMix.isEmpty)
            const Text('Nothing collected in this period.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
          else
            for (var i = 0; i < r.paymentMix.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _buildPaymentMethodRow(r.paymentMix[i], _colorAt(i)),
            ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Below this the two panels stop fitting side by side, same
        // shape as Order Detail's/Customer Detail's own stack breakpoint.
        final stacked =
            constraints.maxWidth < SidebarNavigation.contentStackBreakpoint;
        if (stacked) {
          return Column(
            children: [
              ordersBreakdown,
              const SizedBox(height: 20),
              paymentsMix,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: ordersBreakdown),
            const SizedBox(width: 20),
            Expanded(flex: 1, child: paymentsMix),
          ],
        );
      },
    );
  }

  Widget _breakdownColumn(String title, List<ReportBreakdownModel> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8))),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Text('—',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
        else
          for (var i = 0; i < rows.length; i++)
            _buildStatusRow(rows[i].label, '${rows[i].count}', _colorAt(i)),
      ],
    );
  }

  Widget _buildPeriodButton(int idx, String title) {
    final isSel = _selectedPeriod == idx;
    return OutlinedButton(
      onPressed: () => _selectPeriod(idx),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
            color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
        backgroundColor: isSel ? const Color(0xFFEEF2FF) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
          color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, String sub, IconData icon,
      Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(val,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Takes rupee amounts and the series peak, and works out the bar heights
  /// itself. It used to be handed ratios that meant nothing in particular.
  Widget _buildBarPair(ReportMonthModel month, double peak) {
    double height(double amount) => peak <= 0 ? 0 : 120 * (amount / peak);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 12,
              height: height(month.revenue),
              decoration: const BoxDecoration(
                color: Color(0xFF1A4FD6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              height: height(month.expenses),
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(month.label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildStatusRow(String label, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          ),
          Text(count,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(PaymentMixModel row, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(row.methodLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A))),
            ),
            const SizedBox(width: 8),
            Text('${_money(row.amount)} (${row.percent.round()}%)',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          // Straight from the server, not parsed back out of the label the way
          // this used to do with double.parse(pct.replaceAll('%', '')).
          value: (row.percent / 100).clamp(0.0, 1.0),
          backgroundColor: const Color(0xFFF1F5F9),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
