import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/top_header.dart';

/// `/expenses` in the live app. Not captured yet, so this follows our own
/// conventions rather than cloning a screenshot. See LIVE_AUDIT.md
/// "Not captured". The live route is reachable (there are no plan tiers), so
/// it can be captured and this screen checked against it.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _category = 'All';

  /// Offered in the Add dialog. The field is free text on the backend, so this
  /// is a convenience list, not a constraint — an expense loaded with some
  /// other category still renders and still gets its own filter chip.
  static const _categoryPresets = [
    'Supplies',
    'Rent',
    'Utilities',
    'Maintenance',
    'Salary',
    'Transport',
    'Other',
  ];

  static const _paymentMethods = ['CASH', 'UPI', 'CARD', 'BANK_TRANSFER'];

  static const _categoryColors = {
    'Supplies': Color(0xFF1A4FD6),
    'Rent': Color(0xFFDC2626),
    'Utilities': Color(0xFFF59E0B),
    'Maintenance': Color(0xFF8B5CF6),
    'Salary': Color(0xFF10B981),
    'Transport': Color(0xFF0EA5E9),
  };

  static Color _colorFor(String category) =>
      _categoryColors[category] ?? const Color(0xFF64748B);

  static String _methodLabel(String raw) =>
      raw.split('_').map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()).join(' ');

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final all = provider.expenses;

    final categories = <String>{for (final e in all) e.category}.toList()..sort();
    final visible =
        _category == 'All' ? all : all.where((e) => e.category == _category).toList();

    final total = all.fold<double>(0, (sum, e) => sum + e.amount);
    final now = DateTime.now();
    final thisMonth = all
        .where((e) => e.date != null && e.date!.year == now.year && e.date!.month == now.month)
        .fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                TopHeader(onNewOrderPressed: () => provider.setNavIndex(1)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleRow(),
                        const SizedBox(height: 20),
                        _summaryRow(total, thisMonth, all.length),
                        const SizedBox(height: 20),
                        if (categories.isNotEmpty) ...[
                          _filterChips(categories),
                          const SizedBox(height: 16),
                        ],
                        _list(visible, provider),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleRow() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Expenses Log',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text('Log shop operational expenses, rent, detergents, & repairs',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: _showAddExpense,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Expense'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1A4FD6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(double total, double thisMonth, int count) {
    final cards = [
      _summaryCard('This month', '₹${thisMonth.toStringAsFixed(0)}',
          Icons.calendar_month_rounded, const Color(0xFFDC2626)),
      _summaryCard('Total logged', '₹${total.toStringAsFixed(0)}',
          Icons.account_balance_wallet_outlined, const Color(0xFF1A4FD6)),
      _summaryCard('Entries', '$count', Icons.receipt_long_outlined, const Color(0xFF8B5CF6)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth < 640 ? 1 : 3;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in cards) SizedBox(width: width, child: c)],
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips(List<String> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in ['All', ...categories])
          FilterChip(
            label: Text(c),
            selected: _category == c,
            showCheckmark: false,
            onSelected: (_) => setState(() => _category = c),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _category == c ? Colors.white : const Color(0xFF475569),
            ),
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF1A4FD6),
            side: BorderSide(
              color: _category == c ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
      ],
    );
  }

  Widget _list(List<ExpenseModel> expenses, AppProvider provider) {
    if (expenses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 56),
        decoration: _panel,
        child: Center(
          child: Text(
            provider.isLoading
                ? 'Loading expenses…'
                : _category == 'All'
                    ? 'No expenses logged yet.'
                    : 'No $_category expenses logged.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    return Container(
      decoration: _panel,
      child: Column(
        children: [
          for (var i = 0; i < expenses.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _colorFor(expenses[i].category).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long_outlined,
                        size: 17, color: _colorFor(expenses[i].category)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expenses[i].title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorFor(expenses[i].category).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(expenses[i].category,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _colorFor(expenses[i].category))),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${_methodLabel(expenses[i].paymentMethod)} · '
                                '${expenses[i].date == null ? 'No date' : DateFormat('MMM d, yyyy').format(expenses[i].date!)}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('₹${expenses[i].amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Takes no `BuildContext`: a parameter of that name would shadow
  /// `State.context`, and the `mounted` check below would then be guarding a
  /// different context than the snackbar uses.
  Future<void> _showAddExpense() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final provider = context.read<AppProvider>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var category = _categoryPresets.first;
        var method = _paymentMethods.first;
        var date = DateTime.now();
        String? error;
        var saving = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Expense',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Title'),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(fontSize: 13),
                      decoration: _fieldDecoration('e.g. Commercial detergent (50L)'),
                    ),
                    const SizedBox(height: 14),
                    _label('Amount (₹)'),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: _fieldDecoration('0'),
                    ),
                    const SizedBox(height: 14),
                    _label('Category'),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isDense: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: _fieldDecoration(''),
                      items: [
                        for (final c in _categoryPresets)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setDialogState(() => category = v ?? category),
                    ),
                    const SizedBox(height: 14),
                    _label('Payment method'),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      isDense: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: _fieldDecoration(''),
                      items: [
                        for (final m in _paymentMethods)
                          DropdownMenuItem(value: m, child: Text(_methodLabel(m))),
                      ],
                      onChanged: (v) => setDialogState(() => method = v ?? method),
                    ),
                    const SizedBox(height: 14),
                    _label('Date'),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => date = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 15),
                      label: Text(DateFormat('MMM d, yyyy').format(date),
                          style: const TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(double.infinity, 44),
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final amount = double.tryParse(amountController.text.trim());
                        if (title.isEmpty) {
                          setDialogState(() => error = 'Give the expense a title.');
                          return;
                        }
                        if (amount == null || amount <= 0) {
                          setDialogState(() => error = 'Enter an amount greater than zero.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        final ok = await provider.addExpense({
                          'title': title,
                          'category': category,
                          'amount': amount,
                          'payment_method': method,
                          'date': date.toUtc().toIso8601String(),
                        });
                        if (!ctx.mounted) return;
                        if (ok) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            saving = false;
                            error = provider.error ?? 'Could not save the expense.';
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4FD6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(saving ? 'Saving…' : 'Add Expense',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense logged.')),
      );
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );
}

const BoxDecoration _panel = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
);
