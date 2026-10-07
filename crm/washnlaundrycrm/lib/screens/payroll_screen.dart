import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/money.dart';
import '../utils/navigation.dart';
import '../widgets/app_shell.dart';
import '../widgets/load_state.dart';
import '../widgets/sidebar_navigation.dart';

/// `/payroll`, laid out to match the live app (captured 2026-09-25):
///
/// - a single title row — "Payroll", a month dropdown, Add advance, Pay all
///   pending;
/// - four KPI cards (Total payroll, Paid %, Pending %, active Staff);
/// - one table row per staff member (Salary, Present, Half, Leave, Advances,
///   Deductions, Net pay, Status, Actions) with a Total row, a
///   "Showing 1–N of N staff" footer and the "Paid salaries appear in
///   Expenses" note;
/// - clicking a name opens the Salary slip as a right-hand panel;
/// - the row's document icon ("Manage payments & adjustments") swaps the page
///   for that staff member's month, still at `/payroll`, as the live app does.
///
/// Every figure comes from `/api/payroll/`: wages earned are the attendance
/// register times the monthly wage divided into a per-day rate, and what was
/// paid comes from SalaryPayment. We have no payroll-adjustment model, so the
/// Deductions column and the slip's "Other earnings/deductions" are always 0 —
/// Advances are the only deduction.
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

/// How the live app's "Paid via" segments map onto our payment methods.
const _paidViaOptions = [
  ('CASH', 'Cash'),
  ('UPI', 'UPI'),
  ('BANK_TRANSFER', 'Bank'),
];

class _PayrollScreenState extends State<PayrollScreen> {
  // The current month, not a hardcoded July 2026 that went stale the moment it
  // was typed.
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  /// Staff whose Salary slip panel is open, or null.
  String? _slipStaffId;

  /// Staff whose "Manage payments & adjustments" view replaces the list, or
  /// null for the list itself.
  String? _detailStaffId;

  static const _ink = Color(0xFF141A24);
  static const _muted = Color(0xFF64748B);
  static const _faint = Color(0xFF94A3B8);
  static const _line = Color(0xFFE4E0D8);
  static const _brand = Color(0xFF182C4F);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFD97706);

  String get _monthLabel => DateFormat('MMMM yyyy').format(_selectedMonth);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().loadPayrollFor(_selectedMonth);
    });
  }

  void _setMonth(DateTime month) {
    setState(() => _selectedMonth = DateTime(month.year, month.month));
    context.read<AppProvider>().loadPayrollFor(_selectedMonth);
  }

  void _stepMonth(int delta) =>
      _setMonth(DateTime(_selectedMonth.year, _selectedMonth.month + delta));

  /// The live dropdown lists the current month and the eleven before it,
  /// newest first. A month picked from the staff view's stepper can fall
  /// outside that window, so it is added rather than breaking the dropdown.
  List<DateTime> get _monthOptions {
    final now = DateTime(DateTime.now().year, DateTime.now().month);
    final months = [
      for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i),
    ];
    if (!months.contains(_selectedMonth)) months.add(_selectedMonth);
    return months;
  }

  static String _rs(num? value) => Money.grouped(value);

  PayrollEntryModel? _entryFor(String? staffId, AppProvider provider) {
    if (staffId == null) return null;
    for (final e in provider.payroll?.entries ?? const <PayrollEntryModel>[]) {
      if (e.staffId == staffId) return e;
    }
    return null;
  }

  StaffModel? _staffFor(String staffId, AppProvider provider) {
    for (final s in provider.staff) {
      if (s.id == staffId) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow =
                constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            if (_detailStaffId != null) {
              return _staffDetail(provider, narrow);
            }
            final slipEntry = _entryFor(_slipStaffId, provider);
            // The slip docks beside the table only when there is room for
            // both; below that it opens as a dialog instead (see _openSlip).
            final dockSlip = slipEntry != null && constraints.maxWidth >= 1000;
            // stretch: the Row must fill the height, or AppShell centres a
            // short page vertically and the title floats mid-screen.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _body(provider, narrow)),
                if (dockSlip)
                  Container(
                    width: 320,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(left: BorderSide(color: _line)),
                    ),
                    child: _SalarySlip(
                      entry: slipEntry,
                      staff: _staffFor(slipEntry.staffId, provider),
                      shop: provider.shop,
                      month: _selectedMonth,
                      onClose: () => setState(() => _slipStaffId = null),
                      onManage: () => setState(() {
                        _detailStaffId = slipEntry.staffId;
                        _slipStaffId = null;
                      }),
                      onPrint: () => _toast('Sent to the printer.'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── List view ────────────────────────────────────────────────────────────

  Widget _body(AppProvider provider, bool narrow) {
    final payroll = provider.payroll;

    if (provider.payrollError != null && payroll == null) {
      return ErrorState(
        title: 'Error loading payroll',
        message: provider.payrollError!,
      );
    }
    if (provider.payrollLoading && payroll == null) {
      return const LoadingState();
    }

    final entries = payroll?.entries ?? const <PayrollEntryModel>[];

    return SingleChildScrollView(
      padding: EdgeInsets.all(narrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(provider, narrow),
          const SizedBox(height: 20),
          _kpis(payroll),
          const SizedBox(height: 20),
          if (provider.payrollError != null) ...[
            _inlineError(provider.payrollError!),
            const SizedBox(height: 16),
          ],
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entries.isEmpty)
                  _empty()
                else if (narrow)
                  for (final e in entries) _card(e)
                else ...[
                  _tableHeader(),
                  for (final e in entries) _tableRow(e),
                  _totalRow(entries),
                ],
                if (entries.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _line)),
                    ),
                    child: Text(
                      'Showing 1–${entries.length} of ${entries.length} staff',
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                _expensesNote(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppProvider provider, bool narrow) {
    final hasPending =
        (provider.payroll?.entries ?? const <PayrollEntryModel>[])
            .any((e) => e.pendingAmount > 0);

    final monthPicker = Container(
      key: const ValueKey('payroll-month-picker'),
      height: 40,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 15, color: _muted),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<DateTime>(
              value: _selectedMonth,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: _muted),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
              items: [
                for (final m in _monthOptions)
                  DropdownMenuItem(
                    value: m,
                    child: Text(DateFormat('MMMM yyyy').format(m)),
                  ),
              ],
              onChanged: (m) {
                if (m != null) _setMonth(m);
              },
            ),
          ),
        ],
      ),
    );

    final addAdvance = OutlinedButton.icon(
      onPressed: () => _showAddAdvance(provider),
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text('Add advance'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _brand,
        side: const BorderSide(color: _brand),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    final payAll = FilledButton(
      onPressed: hasPending ? () => _showPayAll(provider) : null,
      style: FilledButton.styleFrom(
        backgroundColor: _brand,
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Pay all pending'),
    );

    const title = Text('Payroll',
        style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: _ink));

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 12),
          monthPicker,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: addAdvance),
              const SizedBox(width: 8),
              Expanded(child: payAll),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        title,
        const Spacer(),
        monthPicker,
        const SizedBox(width: 12),
        addAdvance,
        const SizedBox(width: 12),
        payAll,
      ],
    );
  }

  Widget _kpis(PayrollSummaryModel? payroll) {
    final total = payroll?.totalPayroll ?? 0;
    String pct(double part) =>
        '${(total <= 0 ? 0 : part / total * 100).toStringAsFixed(1)}%';
    final cards = [
      _kpiCard(
        icon: Icons.account_balance_wallet_outlined,
        tint: _brand,
        label: 'Total payroll',
        value: _rs(total),
      ),
      _kpiCard(
        icon: Icons.check_circle_outline_rounded,
        tint: _green,
        label: 'Paid',
        value: _rs(payroll?.paid),
        sub: pct(payroll?.paid ?? 0),
        subColor: _green,
      ),
      _kpiCard(
        icon: Icons.schedule_rounded,
        tint: _amber,
        label: 'Pending',
        value: _rs(payroll?.pending),
        sub: pct(payroll?.pending ?? 0),
        subColor: _amber,
      ),
      _kpiCard(
        icon: Icons.people_outline_rounded,
        tint: const Color(0xFF2563EB),
        label: 'Staff',
        value: '${payroll?.staffCount ?? 0}',
        sub: 'active staff',
        subColor: _muted,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth < 640 ? 2 : 4;
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

  Widget _kpiCard({
    required IconData icon,
    required Color tint,
    required String label,
    required String value,
    String? sub,
    Color? subColor,
  }) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 21, color: tint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                const SizedBox(height: 2),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(fontSize: 11, color: subColor ?? _muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Column flexes shared by the header, every row and the Total row.
  static const _cols = [
    ('Staff', 3),
    ('Salary', 2),
    ('Present', 1),
    ('Half', 1),
    ('Leave', 1),
    ('Advances', 2),
    ('Deductions', 2),
    ('Net pay', 2),
    ('Status', 2),
    ('Actions', 3),
  ];

  Widget _cells(List<Widget> cells, {Color? background, double height = 56}) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: background,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1EFEA))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: _cols[i].$2,
              child: i == 0
                  ? Align(alignment: Alignment.centerLeft, child: cells[i])
                  : Center(child: cells[i]),
            ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return _cells(
      [
        for (final c in _cols)
          Text(c.$1,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
      ],
      height: 46,
    );
  }

  Widget _num(String text, {bool bold = false}) => Text(text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.w400,
          color: _ink));

  Widget _tableRow(PayrollEntryModel e) {
    final selected = _slipStaffId == e.staffId;
    return _cells(
      [
        InkWell(
          key: ValueKey('payroll-open-slip-${e.staffId}'),
          onTap: () => _openSlip(e),
          child: _staffCell(e),
        ),
        _num(_rs(e.monthlyWage)),
        _num('${e.presentDays}'),
        _num('${e.halfDays}'),
        _num('${e.leaveDays}'),
        _num(_rs(e.advancesAmount)),
        _num(_rs(0)),
        _num(_rs(e.netPay)),
        _statusPill(e.status),
        _rowActions(e),
      ],
      background: selected ? const Color(0xFFEFF6FF) : null,
      height: 58,
    );
  }

  Widget _totalRow(List<PayrollEntryModel> entries) {
    double sum(double Function(PayrollEntryModel) f) =>
        entries.fold(0.0, (a, e) => a + f(e));
    int count(int Function(PayrollEntryModel) f) =>
        entries.fold(0, (a, e) => a + f(e));
    return _cells(
      [
        _num('Total', bold: true),
        // The live Total row sums what was earned, not the contracted wages.
        _num(_rs(sum((e) => e.totalSalary)), bold: true),
        _num('${count((e) => e.presentDays)}', bold: true),
        _num('${count((e) => e.halfDays)}', bold: true),
        _num('${count((e) => e.leaveDays)}', bold: true),
        _num(_rs(sum((e) => e.advancesAmount)), bold: true),
        _num(_rs(0), bold: true),
        _num(_rs(sum((e) => e.netPay)), bold: true),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ],
      height: 46,
    );
  }

  Widget _avatar(String name, {double size = 30}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: _brand)),
    );
  }

  Widget _staffCell(PayrollEntryModel e) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _avatar(e.staffName),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.staffName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
              Text(e.role.isEmpty ? 'Staff' : e.role,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
        ),
      ],
    );
  }

  /// PAID / PARTIAL / UNPAID in the live app's words and colours — an unpaid
  /// month reads "Pending", not "Unpaid".
  static (String, Color) _statusStyle(String status) {
    switch (status) {
      case 'PAID':
        return ('Paid', const Color(0xFF16A34A));
      case 'PARTIAL':
        return ('Partial', const Color(0xFF2563EB));
      default:
        return ('Pending', const Color(0xFFD97706));
    }
  }

  Widget _statusPill(String status) {
    final (label, colour) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: colour)),
    );
  }

  Widget _squareIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color color = const Color(0xFF334155),
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _line),
          ),
          child: Icon(icon,
              size: 15, color: onPressed == null ? _faint : color),
        ),
      ),
    );
  }

  Widget _rowActions(PayrollEntryModel e) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Something to pay → "Pay ₹X"; otherwise the live app offers the
        // staff member's month (payments & adjustments) in its place.
        if (e.pendingAmount > 0)
          SizedBox(
            height: 30,
            child: FilledButton(
              key: ValueKey('payroll-pay-${e.staffId}'),
              onPressed: () => _showPay(e),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text('Pay ${_rs(e.pendingAmount)}'),
            ),
          )
        else
          _squareIcon(
            icon: Icons.description_outlined,
            tooltip: 'Manage payments & adjustments',
            onPressed: () => setState(() => _detailStaffId = e.staffId),
          ),
      ],
    );
  }

  /// Phone-width replacement for a table row.
  Widget _card(PayrollEntryModel e) {
    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: _faint)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1EFEA))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: ValueKey('payroll-open-slip-${e.staffId}'),
                  onTap: () => _openSlip(e),
                  child: _staffCell(e),
                ),
              ),
              _statusPill(e.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            stat('Salary', _rs(e.monthlyWage)),
            stat('P · H · L', '${e.presentDays} · ${e.halfDays} · ${e.leaveDays}'),
            stat('Advances', _rs(e.advancesAmount)),
            stat('Net pay', _rs(e.netPay)),
          ]),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: _rowActions(e)),
        ],
      ),
    );
  }

  Widget _empty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 32, color: _faint),
          SizedBox(height: 10),
          Text('No staff members',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: _ink)),
          SizedBox(height: 4),
          Text('Add staff members first to mark attendance.',
              style: TextStyle(fontSize: 12, color: _muted)),
        ],
      ),
    );
  }

  Widget _expensesNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: const Color(0xFFEFF6FF),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: _brand),
          const SizedBox(width: 10),
          // One wrapping paragraph, not three Row children, so it can't
          // overflow at phone width.
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                children: [
                  const TextSpan(text: 'Paid salaries appear in '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: InkWell(
                      onTap: () => context.goSection(8),
                      child: const Text('Expenses',
                          style: TextStyle(
                              fontSize: 12,
                              color: _brand,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const TextSpan(text: ' automatically.'),
                ],
              ),
            ),
          ),
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
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          ),
          TextButton(
            onPressed: () =>
                context.read<AppProvider>().loadPayrollFor(_selectedMonth),
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

  /// Wide windows dock the slip beside the table (build() reads
  /// [_slipStaffId]); narrow ones get it as a dialog.
  void _openSlip(PayrollEntryModel e) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    if (wide) {
      setState(() => _slipStaffId = e.staffId);
      return;
    }
    final provider = context.read<AppProvider>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 360,
          height: math.min(640.0, MediaQuery.sizeOf(dialogContext).height - 32),
          child: _SalarySlip(
            entry: e,
            staff: _staffFor(e.staffId, provider),
            shop: provider.shop,
            month: _selectedMonth,
            onClose: () => Navigator.of(dialogContext).pop(),
            onManage: () {
              Navigator.of(dialogContext).pop();
              setState(() => _detailStaffId = e.staffId);
            },
            onPrint: () => _toast('Sent to the printer.'),
          ),
        ),
      ),
    );
  }

  // ── Staff month view ("Manage payments & adjustments") ────────────────────

  Widget _staffDetail(AppProvider provider, bool narrow) {
    final staffId = _detailStaffId!;
    final entry = _entryFor(staffId, provider);
    final staff = _staffFor(staffId, provider);
    final name = entry?.staffName ?? staff?.name ?? 'Staff';
    final wage = entry?.monthlyWage ?? staff?.monthlyWage ?? 0;

    final top = Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to Payroll',
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: () => setState(() => _detailStaffId = null),
          ),
          InkWell(
            onTap: () => setState(() => _detailStaffId = null),
            child: const Text('Payroll',
                style: TextStyle(fontSize: 13, color: _muted)),
          ),
          const Text('  /  ', style: TextStyle(fontSize: 13, color: _faint)),
          Flexible(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            onPressed: () => _stepMonth(-1),
          ),
          Text(_monthLabel,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            onPressed: () => _stepMonth(1),
          ),
        ],
      ),
    );

    Widget card(Widget child) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: child,
        );

    final chips = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFEA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, count, colour) in [
            ('P', entry?.presentDays ?? 0, const Color(0xFF16A34A)),
            ('A', entry?.absentDays ?? 0, const Color(0xFFDC2626)),
            ('H', entry?.halfDays ?? 0, const Color(0xFFD97706)),
            ('L', entry?.leaveDays ?? 0, const Color(0xFF2563EB)),
          ]) ...[
            Text('$count$label',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: colour)),
            if (label != 'L') const SizedBox(width: 8),
          ],
        ],
      ),
    );

    Widget line(String label, String value, {Color? colour, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: bold ? _ink : _muted,
                        fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
              ),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                      color: colour ?? _ink)),
            ],
          ),
        );

    final body = entry == null
        ? card(Column(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 30, color: _faint),
              const SizedBox(height: 10),
              const Text('No payroll record for this month.',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: _ink)),
              const SizedBox(height: 10),
              chips,
            ],
          ))
        : Column(
            children: [
              card(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Attendance',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                      const Spacer(),
                      chips,
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1EFEA)),
                  const SizedBox(height: 8),
                  line('Salary earned', _rs(entry.totalSalary)),
                  line('Advances', '-${_rs(entry.advancesAmount)}',
                      colour: const Color(0xFFDC2626)),
                  line('Net pay', _rs(entry.netPay), bold: true),
                  line('Paid', _rs(entry.paidAmount), colour: _green),
                  line('To pay', _rs(entry.pendingAmount), bold: true),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Text('Payment status',
                        style: TextStyle(fontSize: 13, color: _muted)),
                    const Spacer(),
                    _statusPill(entry.status),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddAdvance(provider,
                              preselectStaffId: staffId),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add advance'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: entry.canRecordPayment
                              ? () => _showRecordPayment(entry)
                              : null,
                          icon: const Icon(Icons.account_balance_wallet_outlined,
                              size: 16),
                          label: const Text('Record payment'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brand,
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )),
              const SizedBox(height: 12),
              card(_paymentHistory(entry, provider)),
            ],
          );

    return Column(
      children: [
        top,
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(narrow ? 12 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  children: [
                    card(Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(name[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: _ink)),
                              Text('Monthly · ${_rs(wage)}/Month',
                                  style: const TextStyle(
                                      fontSize: 12, color: _muted)),
                            ],
                          ),
                        ),
                      ],
                    )),
                    const SizedBox(height: 12),
                    body,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Every payout recorded for this staff member, across all months.
  Widget _paymentHistory(PayrollEntryModel entry, AppProvider provider) {
    String methodLabel(String raw) => provider.paymentMethods
        .firstWhere((c) => c.value == raw,
            orElse: () => ChoiceModel(value: raw, label: raw))
        .label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payments',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 8),
        FutureBuilder<List<SalaryPaymentModel>>(
          // Keyed on the paid amount so a new payment refetches the list.
          key: ValueKey('history-${entry.staffId}-${entry.paidAmount}'),
          future: provider.fetchSalaryHistory(entry.staffId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snapshot.hasError) {
              return Text('Could not load payments: ${snapshot.error}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)));
            }
            final payments = snapshot.data ?? const <SalaryPaymentModel>[];
            if (payments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No payments recorded yet.',
                    style: TextStyle(fontSize: 12, color: _faint)),
              );
            }
            return Column(
              children: [
                for (final p in payments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  p.month == null
                                      ? '—'
                                      : DateFormat('MMMM yyyy').format(p.month!),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _ink)),
                              Text(
                                  '${methodLabel(p.method)}'
                                  '${p.paidOn == null ? '' : ' · ${DateFormat('d MMM yyyy').format(p.paidOn!)}'}'
                                  '${p.note.trim().isEmpty ? '' : ' · ${p.note.trim()}'}',
                                  style: const TextStyle(
                                      fontSize: 11, color: _muted)),
                            ],
                          ),
                        ),
                        Text(_rs(p.amount),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _green)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  /// The live app's compact dialog shell: title + close, then content.
  Widget _panelDialog(BuildContext dialogContext,
      {required String title, required List<Widget> children}) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _ink)),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paidVia(String method, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Paid via',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _paidViaOptions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _segment(
                  _paidViaOptions[i].$2,
                  selected: method == _paidViaOptions[i].$1,
                  onTap: () => onChanged(_paidViaOptions[i].$1),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _segment(String label,
      {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _brand : _line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? _brand : _ink)),
      ),
    );
  }

  Widget _amountBox(double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Text('Amount to pay',
              style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
          const Spacer(),
          Text(_rs(amount),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
        ],
      ),
    );
  }

  Widget _primary(String label, {VoidCallback? onPressed, Key? key}) {
    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _brand,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  /// Shared by a row's "Pay ₹X" and the header's "Pay all pending": the
  /// amount is what is owed, shown rather than typed, as in the live app.
  Future<bool?> _settleDialog({
    required String title,
    required String message,
    required double amount,
    required Future<String?> Function(String method) pay,
  }) {
    var method = _paidViaOptions.first.$1;
    var busy = false;
    String? error;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => _panelDialog(
          dialogContext,
          title: title,
          children: [
            Text(message,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
            const SizedBox(height: 14),
            _amountBox(amount),
            const SizedBox(height: 16),
            _paidVia(method, (m) => setDialogState(() => method = m)),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 18),
            _primary(
              'Pay ${_rs(amount)}',
              key: const ValueKey('payroll-settle-confirm'),
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      final failure = await pay(method);
                      if (!dialogContext.mounted) return;
                      if (failure == null) {
                        Navigator.of(dialogContext).pop(true);
                      } else {
                        setDialogState(() {
                          busy = false;
                          error = failure;
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPay(PayrollEntryModel entry) async {
    final provider = context.read<AppProvider>();
    final paid = await _settleDialog(
      title: 'Pay salary',
      message:
          "Settle ${entry.staffName}'s salary for $_monthLabel. It is marked paid.",
      amount: entry.pendingAmount,
      pay: (method) async {
        final ok = await provider.recordSalaryPayment(
          staffId: entry.staffId,
          month: _selectedMonth,
          amount: entry.pendingAmount,
          method: method,
        );
        return ok ? null : (provider.payrollError ?? 'Could not record the payment.');
      },
    );
    if (paid == true && mounted) _toast('Payment recorded', success: true);
  }

  Future<void> _showPayAll(AppProvider provider) async {
    final pending = (provider.payroll?.entries ?? const <PayrollEntryModel>[])
        .where((e) => e.pendingAmount > 0)
        .toList();
    if (pending.isEmpty) return;
    final total = pending.fold(0.0, (a, e) => a + e.pendingAmount);
    var paidCount = 0;
    final done = await _settleDialog(
      title: 'Pay all pending',
      message:
          'Settle ${pending.length} salaries for $_monthLabel. Each is marked paid.',
      amount: total,
      pay: (method) async {
        paidCount = await provider.payAllPending(_selectedMonth, method: method);
        return paidCount == pending.length
            ? null
            : 'Paid $paidCount of ${pending.length} — '
                '${provider.payrollError ?? 'stopped on an error'}';
      },
    );
    if (done == true && mounted) {
      _toast('Paid $paidCount staff member${paidCount == 1 ? '' : 's'}',
          success: true);
    }
  }

  /// Staff month view's "Record payment": an editable amount (partial
  /// payments, or paying someone with nothing earned) plus a note — the
  /// flexible path the fixed-amount "Pay ₹X" dialog doesn't cover.
  Future<void> _showRecordPayment(PayrollEntryModel entry) async {
    final amountController =
        TextEditingController(text: entry.pendingAmount.round().toString());
    final noteController = TextEditingController();
    var method = _paidViaOptions.first.$1;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => _panelDialog(
          dialogContext,
          title: 'Record payment',
          children: [
            Text(
                '${entry.staffName} · $_monthLabel · ${_rs(entry.pendingAmount)} to pay',
                style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 14),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${Money.symbol} ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            _paidVia(method, (m) => setDialogState(() => method = m)),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 18),
            _primary(
              'Record payment',
              key: const ValueKey('payroll-record-confirm'),
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  setDialogState(
                      () => error = 'Enter an amount greater than zero.');
                  return;
                }
                // Can't pay out more than is owed; with nothing earned there
                // is no amount to cap against (the backend agrees).
                if (!entry.nothingEarned && amount > entry.pendingAmount) {
                  setDialogState(() => error =
                      'Cannot exceed the ${_rs(entry.pendingAmount)} outstanding.');
                  return;
                }
                final provider = context.read<AppProvider>();
                final ok = await provider.recordSalaryPayment(
                  staffId: entry.staffId,
                  month: _selectedMonth,
                  amount: amount,
                  method: method,
                  note: noteController.text,
                );
                if (!dialogContext.mounted) return;
                if (ok) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  setDialogState(() => error = provider.payrollError ??
                      'Could not record the payment.');
                }
              },
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    noteController.dispose();
    if (saved == true && mounted) _toast('Payment recorded', success: true);
  }

  Future<void> _showAddAdvance(AppProvider provider,
      {String? preselectStaffId}) async {
    final roster = provider.staff.where((s) => s.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (roster.isEmpty) {
      _toast('No active staff to advance money to.');
      return;
    }

    String? selectedStaffId =
        roster.any((s) => s.id == preselectStaffId) ? preselectStaffId : null;
    final amountController = TextEditingController();
    var method = _paidViaOptions.first.$1;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => _panelDialog(
          dialogContext,
          title: 'Add advance',
          children: [
            const Text('Staff',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedStaffId,
              hint: const Text('Select staff'),
              isDense: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final s in roster)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (value) =>
                  setDialogState(() => selectedStaffId = value),
            ),
            const SizedBox(height: 14),
            const Text('Amount',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(height: 6),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '${Money.symbol} ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            _paidVia(method, (m) => setDialogState(() => method = m)),
            const SizedBox(height: 10),
            const Text("The advance is deducted from this month's net pay.",
                style: TextStyle(fontSize: 11, color: _muted)),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 18),
            _primary(
              'Save advance',
              key: const ValueKey('payroll-advance-confirm'),
              onPressed: () async {
                if (selectedStaffId == null) {
                  setDialogState(() => error = 'Select a staff member.');
                  return;
                }
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  setDialogState(
                      () => error = 'Enter an amount greater than zero.');
                  return;
                }
                final ok = await provider.recordSalaryAdvance(
                  staffId: selectedStaffId!,
                  month: _selectedMonth,
                  amount: amount,
                  method: method,
                );
                if (!dialogContext.mounted) return;
                if (ok) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  setDialogState(() => error = provider.payrollError ??
                      'Could not record the advance.');
                }
              },
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    if (saved == true && mounted) _toast('Advance recorded', success: true);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _toast(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? const Color(0xFF10B981) : null,
    ));
  }
}

/// The live app's "Salary slip" panel — docked to the right of the table on
/// wide windows, a dialog on narrow ones.
class _SalarySlip extends StatelessWidget {
  final PayrollEntryModel entry;
  final StaffModel? staff;
  final Map<String, dynamic>? shop;
  final DateTime month;
  final VoidCallback onClose;
  final VoidCallback onManage;
  final VoidCallback onPrint;

  const _SalarySlip({
    required this.entry,
    required this.staff,
    required this.shop,
    required this.month,
    required this.onClose,
    required this.onManage,
    required this.onPrint,
  });

  static const _ink = Color(0xFF141A24);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE4E0D8);

  static String _rs(num? v) => Money.grouped(v);

  Widget _kv(String k, String v, {Color? colour, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(k,
                  style: TextStyle(
                      fontSize: 12,
                      color: colour ?? _muted,
                      fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
            ),
            Text(v,
                style: TextStyle(
                    fontSize: 12,
                    color: colour ?? _ink,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w500)),
          ],
        ),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: _ink)),
      );

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _line),
          ),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 9, color: _muted)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: _ink)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final shopName = (shop?['name'] as String?)?.trim();
    final shopCity = (shop?['city'] as String?)?.trim() ?? '';
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final period =
        '1 ${DateFormat('MMM').format(month)} – ${lastDay.day} ${DateFormat('MMM yyyy').format(month)}';
    final phone = staff?.phone ?? '';
    final (statusLabel, statusColour) = switch (entry.status) {
      'PAID' => ('Paid', const Color(0xFF16A34A)),
      'PARTIAL' => ('Partial', const Color(0xFF2563EB)),
      _ => ('Pending', const Color(0xFFD97706)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Salary slip',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _ink)),
                    Text(
                        '${entry.staffName} · ${DateFormat('MMMM yyyy').format(month)}',
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF182C4F),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                            (shopName == null || shopName.isEmpty)
                                ? '?'
                                : shopName[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                (shopName == null || shopName.isEmpty)
                                    ? 'Your shop'
                                    : shopName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _ink)),
                            if (shopCity.isNotEmpty)
                              Text(shopCity,
                                  style: const TextStyle(
                                      fontSize: 10, color: _muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Date',
                              style: TextStyle(fontSize: 9, color: _muted)),
                          Text(DateFormat('d MMM yyyy').format(DateTime.now()),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _ink)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: _line),
                  const SizedBox(height: 6),
                  _kv('Employee', entry.staffName),
                  _kv('Role', entry.role.isEmpty ? 'Staff' : entry.role),
                  if (phone.isNotEmpty) _kv('Phone', phone),
                  _kv('Pay period', period),
                  _section('Attendance summary'),
                  Row(children: [
                    _stat('Present', '${entry.presentDays}'),
                    _stat('Half day', '${entry.halfDays}'),
                    _stat('Leave', '${entry.leaveDays}'),
                    _stat('Total days',
                        '${entry.presentDays + entry.halfDays + entry.leaveDays}'),
                  ]),
                  _section('Earnings'),
                  _kv('Base salary', _rs(entry.totalSalary)),
                  _kv('Other earnings', _rs(0)),
                  _kv('Gross salary', _rs(entry.totalSalary),
                      colour: const Color(0xFF182C4F), bold: true),
                  _section('Deductions'),
                  _kv('Advances', '-${_rs(entry.advancesAmount)}'),
                  _kv('Other deductions', _rs(0)),
                  _kv('Total deductions', '-${_rs(entry.advancesAmount)}',
                      colour: const Color(0xFFDC2626), bold: true),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: _line),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Net pay',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _ink)),
                      ),
                      Text(_rs(entry.netPay),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Payment status',
                            style: TextStyle(fontSize: 12, color: _muted)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColour.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: statusColour)),
                      ),
                    ],
                  ),
                  _kv('To pay', _rs(entry.pendingAmount), bold: true),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onManage,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Manage payments & adjustments →',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF182C4F))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined, size: 15),
                label: const Text('Print'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
