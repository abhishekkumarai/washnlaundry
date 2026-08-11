import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../widgets/load_state.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/top_header.dart';

/// `/payroll` in the live app. Paid-plan gated there and never captured, so
/// this follows our own conventions — see LIVE_AUDIT.md "Not captured".
///
/// Every figure comes from `/api/payroll/`: wages earned are the attendance
/// register times the daily wage, and what was paid comes from SalaryPayment.
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  // The current month, not a hardcoded July 2026 that went stale the moment it
  // was typed.
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _paymentMethods = ['CASH', 'UPI', 'BANK_TRANSFER', 'CARD'];

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
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    context.read<AppProvider>().loadPayrollFor(_selectedMonth);
  }

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
                TopHeader(onNewOrderPressed: () => provider.setNavIndex(1)),
                Expanded(child: _body(provider)),
              ],
            ),
          ),
        ],
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

    final entries = payroll?.entries ?? const <PayrollEntryModel>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(),
          const SizedBox(height: 20),

          Row(
            children: [
              _buildSummaryCard('Total Payroll', '₹${_money(payroll?.totalPayroll)}',
                  const Color(0xFF1A4FD6)),
              const SizedBox(width: 12),
              _buildSummaryCard('Paid', '₹${_money(payroll?.paid)}', const Color(0xFF10B981)),
              const SizedBox(width: 12),
              _buildSummaryCard('Pending Balance', '₹${_money(payroll?.pending)}',
                  const Color(0xFFEF4444)),
              const SizedBox(width: 12),
              _buildSummaryCard('Staff Count', '${payroll?.staffCount ?? 0}',
                  const Color(0xFFA855F7)),
            ],
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
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  _empty()
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
  }

  /// Whole rupees. Money is a double end to end here (see CLAUDE.md), but the
  /// screen has never shown paise and showing them now would only add noise.
  static String _money(double? value) => (value ?? 0).round().toString();

  Widget _titleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payroll', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text('Calculate staff wages, attendance payout, and salary records',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),

        // Month Navigation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: () => _stepMonth(-1),
              ),
              Text(
                _monthLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: () => _stepMonth(1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.payments_outlined, size: 32, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text('No payroll for this month.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            SizedBox(height: 4),
            Text('Mark attendance to build up wages.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
          const Icon(Icons.error_outline_rounded, size: 17, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          ),
          TextButton(
            onPressed: () => context.read<AppProvider>().loadPayrollFor(_selectedMonth),
            child: const Text('Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
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
                  entry.staffName.isEmpty ? '?' : entry.staffName[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.staffName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('${entry.role} • ₹${entry.dailyWage.round()}/day',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),

          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${_money(entry.totalSalary)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Days worked: ${entry.daysWorkedLabel}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(width: 20),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Paid ₹${_money(entry.paidAmount)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                  Text('Due ₹${_money(entry.pendingAmount)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(width: 20),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.status,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colour),
                ),
              ),
              const SizedBox(width: 8),

              TextButton(
                onPressed: entry.pendingAmount <= 0 ? null : () => _showRecordPayment(entry),
                child: const Text('Record Payment',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRecordPayment(PayrollEntryModel entry) async {
    // Prefilled with what is owed, which is the common case — settling up.
    final amountController =
        TextEditingController(text: entry.pendingAmount.round().toString());
    final noteController = TextEditingController();
    var method = _paymentMethods.first;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Pay ${entry.staffName}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_monthLabel • ₹${_money(entry.pendingAmount)} outstanding',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
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
                    for (final m in _paymentMethods)
                      DropdownMenuItem(value: m, child: Text(m.replaceAll('_', ' '))),
                  ],
                  onChanged: (value) => setDialogState(() => method = value ?? method),
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
                  Text(error!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
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
                  setDialogState(() => error = 'Enter an amount greater than zero.');
                  return;
                }
                final ok = await context.read<AppProvider>().recordSalaryPayment(
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
                      context.read<AppProvider>().payrollError ?? 'Could not record the payment.');
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

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
