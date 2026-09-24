import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../widgets/load_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/top_header.dart';
import '../utils/money.dart';

/// `/payroll` in the live app. Not captured yet, so this follows our own
/// conventions rather than cloning a screenshot — see LIVE_AUDIT.md
/// "Not captured". The live route is reachable (there are no plan tiers), so
/// it can be captured and this screen checked against it.
///
/// Every figure comes from `/api/payroll/`: wages earned are the attendance
/// register times the monthly wage divided into a per-day rate, and what was
/// paid comes from SalaryPayment.
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  // The current month, not a hardcoded July 2026 that went stale the moment it
  // was typed.
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _searchQuery = '';

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().loadPayrollFor(_selectedMonth);
    });
  }

  void _stepMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    context.read<AppProvider>().loadPayrollFor(_selectedMonth);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(
        body: Column(
          children: [
            TopHeader(
              title: 'Payroll',
              actionLabel: 'New Payroll',
              actionIcon: Icons.payments_outlined,
              onActionPressed: () => _showNewPayrollDialog(provider),
            ),
            Expanded(child: _body(provider)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppProvider provider) {
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

    final allEntries = payroll?.entries ?? const <PayrollEntryModel>[];
    final query = _searchQuery.trim().toLowerCase();
    final entries = query.isEmpty
        ? allEntries
        : allEntries
            .where((e) =>
                e.staffName.toLowerCase().contains(query) ||
                e.role.toLowerCase().contains(query))
            .toList();
    final searching = query.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleRow(narrow, provider),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, kpiConstraints) {
                  final perRow = kpiConstraints.maxWidth < 640 ? 2 : 4;
                  const gap = 12.0;
                  final width =
                      (kpiConstraints.maxWidth - gap * (perRow - 1)) / perRow;
                  final cards = [
                    _buildSummaryCard(
                        'Total Payroll',
                        '${Money.symbol}${_money(payroll?.totalPayroll)}',
                        const Color(0xFF1A4FD6)),
                    _buildSummaryCard('Paid',
                        '${Money.symbol}${_money(payroll?.paid)}',
                        const Color(0xFF10B981)),
                    _buildSummaryCard(
                        'Pending Balance',
                        '${Money.symbol}${_money(payroll?.pending)}',
                        const Color(0xFFEF4444)),
                    _buildSummaryCard('Staff Count',
                        '${payroll?.staffCount ?? 0}',
                        const Color(0xFFA855F7)),
                  ];
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final c in cards) SizedBox(width: width, child: c),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (provider.payrollError != null) ...[
                _inlineError(provider.payrollError!),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_monthLabel Payroll Records',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 16),
                    if (entries.isEmpty)
                      _empty(searching: searching)
                    else if (narrow)
                      Column(
                        children: [
                          for (final e in entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _payrollCard(e),
                            ),
                        ],
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) => _row(entries[idx]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Whole rupees. Money is a double end to end here (see CLAUDE.md), but the
  /// screen has never shown paise and showing them now would only add noise.
  static String _money(double? value) => (value ?? 0).round().toString();

  Widget _titleRow(bool narrow, AppProvider provider) {
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Flexible(
          child: Text(
              'Calculate staff wages, attendance payout, and salary records',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ),
        IconButton(
          onPressed: _showHelp,
          icon: const Icon(Icons.help_outline_rounded,
              size: 16, color: Color(0xFF94A3B8)),
          tooltip: 'How Payroll is calculated',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
      ],
    );
    final hasPending =
        (provider.payroll?.entries ?? const <PayrollEntryModel>[])
            .any((e) => e.pendingAmount > 0);

    Widget advanceAndPayAll({required bool compact}) => Row(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (compact)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddAdvance(provider),
                  icon: const Icon(Icons.add_card_rounded, size: 16),
                  label: const Text('Advance'),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _showAddAdvance(provider),
                icon: const Icon(Icons.add_card_rounded, size: 16),
                label: const Text('Add advance'),
              ),
            const SizedBox(width: 8),
            if (compact)
              Expanded(
                child: FilledButton.icon(
                  onPressed: hasPending
                      ? () => _confirmPayAllPending(provider)
                      : null,
                  icon: const Icon(Icons.payments_rounded, size: 16),
                  label: const Text('Pay all'),
                ),
              )
            else
              FilledButton.icon(
                onPressed:
                    hasPending ? () => _confirmPayAllPending(provider) : null,
                icon: const Icon(Icons.payments_rounded, size: 16),
                label: const Text('Pay all pending'),
              ),
          ],
        );
    final monthNav = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: () => _stepMonth(-1),
          ),
          Text(
            _monthLabel,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: () => _stepMonth(1),
          ),
        ],
      ),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 12),
          _searchField(),
          const SizedBox(height: 12),
          advanceAndPayAll(compact: true),
          const SizedBox(height: 12),
          monthNav,
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: title),
        SizedBox(width: 220, child: _searchField()),
        const SizedBox(width: 12),
        advanceAndPayAll(compact: false),
        const SizedBox(width: 12),
        monthNav,
      ],
    );
  }

  Widget _searchField() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 18, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Search staff...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty({required bool searching}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.payments_outlined,
                size: 32, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
                searching
                    ? 'No staff match "${_searchQuery.trim()}".'
                    : 'No payroll for this month.',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(
                searching
                    ? 'Try a different name or role.'
                    : 'Mark attendance to build up wages.',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
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

  static Color _statusColor(String status) {
    switch (status) {
      case 'PAID':
        return const Color(0xFF10B981);
      case 'PARTIAL':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  Widget _row(PayrollEntryModel entry) {
    final colour = _statusColor(entry.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEEF2FF),
                child: Text(
                  entry.staffName.isEmpty
                      ? '?'
                      : entry.staffName[0].toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.staffName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  Text(
                      '${entry.role} • ${Money.symbol}${entry.monthlyWage.round()}/month',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${Money.symbol}${_money(entry.totalSalary)}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  Text('Days worked: ${entry.daysWorkedLabel}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                  Text(
                      'P ${entry.presentDays} • H ${entry.halfDays} • L ${entry.leaveDays}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      'Advances ${Money.symbol}${_money(entry.advancesAmount)}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                  Text('Net pay ${Money.symbol}${_money(entry.netPay)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Paid ${Money.symbol}${_money(entry.paidAmount)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981))),
                  Text('Due ${Money.symbol}${_money(entry.pendingAmount)}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(width: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.status,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: colour),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _showSalarySlip(entry),
                icon: const Icon(Icons.description_outlined, size: 18),
                tooltip: 'Salary slip',
                visualDensity: VisualDensity.compact,
                color: const Color(0xFF64748B),
              ),
              TextButton(
                onPressed: () => _showPaymentHistory(entry),
                child: const Text('History',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B))),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: !entry.canRecordPayment
                    ? null
                    : () => _showRecordPayment(entry),
                child: const Text('Record Payment',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Narrow-mode replacement for [_row]: the left avatar+name block and the
  /// right block (salary/days, paid/due, status pill, History/Record Payment
  /// buttons) are both intrinsic-width with no flex anywhere — fine at
  /// desktop width, but they overflow badly once this stacks to phone width.
  Widget _payrollCard(PayrollEntryModel entry) {
    final colour = _statusColor(entry.status);
    return Container(
      padding: const EdgeInsets.all(14),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEEF2FF),
                child: Text(
                  entry.staffName.isEmpty
                      ? '?'
                      : entry.staffName[0].toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.staffName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                    Text(
                        '${entry.role} • ${Money.symbol}${entry.monthlyWage.round()}/month',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.status,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: colour),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _cardStat(
                    'Salary (P${entry.presentDays} H${entry.halfDays} L${entry.leaveDays})',
                    '${Money.symbol}${_money(entry.totalSalary)}'),
              ),
              Expanded(
                child: _cardStat('Advances',
                    '${Money.symbol}${_money(entry.advancesAmount)}'),
              ),
              Expanded(
                child: _cardStat(
                    'Net pay', '${Money.symbol}${_money(entry.netPay)}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _cardStat('Paid',
                    '${Money.symbol}${_money(entry.paidAmount)}'),
              ),
              Expanded(
                child: _cardStat(
                    'Due', '${Money.symbol}${_money(entry.pendingAmount)}'),
              ),
              Expanded(
                child: IconButton(
                  onPressed: () => _showSalarySlip(entry),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  tooltip: 'Salary slip',
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showPaymentHistory(entry),
                  child: const Text('History'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: !entry.canRecordPayment
                      ? null
                      : () => _showRecordPayment(entry),
                  child: const Text('Record Payment'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
      ],
    );
  }

  /// The full payout ledger for [entry.staffId] — every month, not just the
  /// one currently selected. Fetched fresh on open rather than cached
  /// provider state, since this dialog is the only place it's read.
  Future<void> _showPaymentHistory(PayrollEntryModel entry) async {
    final provider = context.read<AppProvider>();
    final methodChoices = provider.paymentMethods;
    String methodLabel(String raw) => methodChoices
        .firstWhere((c) => c.value == raw,
            orElse: () => ChoiceModel(value: raw, label: raw))
        .label;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${entry.staffName} — Payment History',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
        content: SizedBox(
          width: math.min(420.0, MediaQuery.sizeOf(dialogContext).width - 48),
          child: FutureBuilder<List<SalaryPaymentModel>>(
            future: provider.fetchSalaryHistory(entry.staffId),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Could not load payment history: ${snapshot.error}',
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
                  ),
                );
              }
              final payments = snapshot.data ?? const <SalaryPaymentModel>[];
              if (payments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No payments recorded yet.',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                  ),
                );
              }
              return SizedBox(
                width: double.infinity,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, i) {
                    final p = payments[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.month == null
                                      ? '—'
                                      : DateFormat('MMMM yyyy')
                                          .format(p.month!),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${methodLabel(p.method)}'
                                  '${p.paidOn == null ? '' : ' · ${DateFormat('MMM d, yyyy').format(p.paidOn!)}'}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                if (p.note.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(p.note.trim(),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8))),
                                ],
                              ],
                            ),
                          ),
                          Text('${Money.symbol}${p.amount.round()}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981))),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  /// The header's "New Payroll" action. There's no bare "create a payroll"
  /// concept — payroll rows are derived from attendance, not created — so
  /// this is a staff picker in front of the same [_showRecordPayment] dialog
  /// each row's own "Record Payment" button opens, rather than a duplicate
  /// form.
  Future<void> _showNewPayrollDialog(AppProvider provider) async {
    final entries = provider.payroll?.entries ?? const <PayrollEntryModel>[];
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No staff payroll for this month yet. Mark attendance first.')),
      );
      return;
    }

    final selected = await showDialog<PayrollEntryModel>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Payroll — $_monthLabel',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
        content: SizedBox(
          width: math.min(400.0, MediaQuery.sizeOf(dialogContext).width - 48),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final e = entries[idx];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    e.staffName.isEmpty ? '?' : e.staffName[0].toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                  ),
                ),
                title: Text(e.staffName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(e.role),
                trailing: Text(
                  'Due ${Money.symbol}${_money(e.pendingAmount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: e.pendingAmount > 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981)),
                ),
                onTap: () => Navigator.of(dialogContext).pop(e),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );

    if (selected != null && mounted) {
      await _showRecordPayment(selected);
    }
  }

  Future<void> _showRecordPayment(PayrollEntryModel entry) async {
    // Prefilled with what is owed, which is the common case — settling up.
    final amountController =
        TextEditingController(text: entry.pendingAmount.round().toString());
    final noteController = TextEditingController();
    // One served vocabulary, replacing this screen's own copy.
    final methodChoices = context.read<AppProvider>().paymentMethods;
    var method = methodChoices.first.value;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Pay ${entry.staffName}'),
          content: SizedBox(
            width: math.min(360.0, MediaQuery.sizeOf(dialogContext).width - 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '$_monthLabel • ${Money.symbol}${_money(entry.pendingAmount)} outstanding',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${Money.symbol} ',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Method',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in methodChoices)
                      DropdownMenuItem(value: m.value, child: Text(m.label)),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => method = value ?? method),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFDC2626))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  setDialogState(
                      () => error = 'Enter an amount greater than zero.');
                  return;
                }
                // Can't pay out more than is actually owed for the month —
                // pendingAmount is total_salary minus what's already been
                // paid, so anything above it would be an overpayment. With
                // nothing earned there is no amount to cap against.
                if (!entry.nothingEarned && amount > entry.pendingAmount) {
                  setDialogState(() => error =
                      'Cannot exceed the ${Money.symbol}${_money(entry.pendingAmount)} outstanding.');
                  return;
                }
                final ok =
                    await context.read<AppProvider>().recordSalaryPayment(
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
                  setDialogState(() => error =
                      context.read<AppProvider>().payrollError ??
                          'Could not record the payment.');
                }
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    noteController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('How Payroll is calculated',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: math.min(420.0, MediaQuery.sizeOf(dialogContext).width - 48),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpLine('Salary',
                  'The attendance register for the month × a daily rate '
                      '(monthly wage ÷ days in that month). A Half Day counts '
                      'as half a day; Leave and Absent are unpaid.'),
              SizedBox(height: 12),
              _HelpLine('Advances',
                  'Money handed out against this month\'s wages before it\'s '
                      'due. It comes straight off Salary to give Net pay — use '
                      '"Add advance" to record one.'),
              SizedBox(height: 12),
              _HelpLine('Net pay',
                  'Salary minus Advances — what the staff member is actually '
                      'still owed for the month.'),
              SizedBox(height: 12),
              _HelpLine('Paid / Due',
                  'Paid is the total of every "Record Payment" made against '
                      'Net pay this month; Due is whatever is left. Paying it '
                      'off also logs a matching Salary expense automatically.'),
              SizedBox(height: 12),
              _HelpLine('Status',
                  'PAID once Due reaches ₹0, PARTIAL once something has been '
                      'paid but Due remains, otherwise UNPAID.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Global — lets any staff member be picked, not scoped to one row, since
  /// this mirrors the header-level "Add advance" action rather than a
  /// per-row one.
  Future<void> _showAddAdvance(AppProvider provider) async {
    final roster = provider.staff.where((s) => s.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (roster.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active staff to advance money to.')),
      );
      return;
    }

    var selectedStaffId = roster.first.id;
    final amountController = TextEditingController();
    final methodChoices = provider.paymentMethods;
    var method = methodChoices.first.value;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add advance — $_monthLabel'),
          content: SizedBox(
            width: math.min(380.0, MediaQuery.sizeOf(dialogContext).width - 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedStaffId,
                  decoration: const InputDecoration(
                    labelText: 'Staff',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in roster)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (value) => setDialogState(
                      () => selectedStaffId = value ?? selectedStaffId),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${Money.symbol} ',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Paid via',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in methodChoices)
                      DropdownMenuItem(value: m.value, child: Text(m.label)),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => method = value ?? method),
                ),
                const SizedBox(height: 8),
                const Text("The advance is deducted from this month's net pay.",
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFDC2626))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  setDialogState(
                      () => error = 'Enter an amount greater than zero.');
                  return;
                }
                final ok = await context.read<AppProvider>().recordSalaryAdvance(
                      staffId: selectedStaffId,
                      month: _selectedMonth,
                      amount: amount,
                      method: method,
                    );
                if (!dialogContext.mounted) return;
                if (ok) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  setDialogState(() => error =
                      context.read<AppProvider>().payrollError ??
                          'Could not record the advance.');
                }
              },
              child: const Text('Save advance'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Advance recorded'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _confirmPayAllPending(AppProvider provider) async {
    final pendingCount = (provider.payroll?.entries ?? const <PayrollEntryModel>[])
        .where((e) => e.pendingAmount > 0)
        .length;
    if (pendingCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pay all pending?'),
        content: Text(
            'This records a full payment for $pendingCount staff member'
            '${pendingCount == 1 ? '' : 's'} with a balance still due for '
            '$_monthLabel.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Pay all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final paidCount = await provider.payAllPending(_selectedMonth);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(paidCount == pendingCount
            ? 'Paid $paidCount staff member${paidCount == 1 ? '' : 's'}'
            : 'Paid $paidCount of $pendingCount — ${provider.payrollError ?? 'stopped on an error'}'),
        backgroundColor:
            paidCount == pendingCount ? const Color(0xFF10B981) : const Color(0xFFDC2626),
      ),
    );
  }

  /// The real app's "Salary slip" panel, as a dialog here rather than a side
  /// panel — Payroll has no persistent side rail to dock one in, and every
  /// other per-row detail view on this screen (History, Record Payment) is
  /// already a dialog.
  Future<void> _showSalarySlip(PayrollEntryModel entry) async {
    final provider = context.read<AppProvider>();
    StaffModel? staff;
    for (final s in provider.staff) {
      if (s.id == entry.staffId) {
        staff = s;
        break;
      }
    }
    final totalDays = entry.presentDays + entry.halfDays + entry.leaveDays;
    final staffPhone = staff?.phone ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${entry.staffName} — Salary Slip',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: math.min(360.0, MediaQuery.sizeOf(dialogContext).width - 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _slipRow('Role', entry.role),
              if (staffPhone.isNotEmpty) _slipRow('Phone', staffPhone),
              _slipRow('Pay period', _monthLabel),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              const Text('Attendance summary',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _slipStat('Present', '${entry.presentDays}'),
                  _slipStat('Half day', '${entry.halfDays}'),
                  _slipStat('Leave', '${entry.leaveDays}'),
                  _slipStat('Total days', '$totalDays'),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _slipRow('Base salary',
                  '${Money.symbol}${_money(entry.totalSalary)}'),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),
              _slipRow('Advances',
                  '-${Money.symbol}${_money(entry.advancesAmount)}',
                  valueColor: const Color(0xFFDC2626)),
              const SizedBox(height: 6),
              _slipRow('Net pay', '${Money.symbol}${_money(entry.netPay)}',
                  bold: true),
              const SizedBox(height: 6),
              _slipRow('Paid', '${Money.symbol}${_money(entry.paidAmount)}'),
              _slipRow('Due', '${Money.symbol}${_money(entry.pendingAmount)}'),
              const SizedBox(height: 6),
              _slipRow('Payment status', entry.status, bold: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _toast('Sent to the printer.'),
            child: const Text('Print'),
          ),
          FilledButton.icon(
            onPressed: staffPhone.isEmpty
                ? null
                : () => _sendSlipOnWhatsApp(staffPhone, entry),
            icon: const Icon(Icons.chat_rounded, size: 16),
            label: const Text('Send on WhatsApp'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _slipRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _slipStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      ],
    );
  }

  void _sendSlipOnWhatsApp(String phone, PayrollEntryModel entry) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent(
        'Hi ${entry.staffName},\nYour salary slip for $_monthLabel:\n'
        'Base salary: ${Money.symbol}${_money(entry.totalSalary)}\n'
        'Advances: -${Money.symbol}${_money(entry.advancesAmount)}\n'
        'Net pay: ${Money.symbol}${_money(entry.netPay)}\n'
        'Paid: ${Money.symbol}${_money(entry.paidAmount)}\n'
        'Due: ${Money.symbol}${_money(entry.pendingAmount)}');
    final url = Uri.parse('https://wa.me/91$cleanPhone?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

/// One term + explanation line in the help dialog.
class _HelpLine extends StatelessWidget {
  final String term;
  final String explanation;

  const _HelpLine(this.term, this.explanation);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(term,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 2),
        Text(explanation,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }
}
