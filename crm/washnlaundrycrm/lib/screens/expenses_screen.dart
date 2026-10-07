import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../utils/csv.dart';
import '../utils/csv_download.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/top_header.dart';
import '../utils/money.dart';

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
  String _searchQuery = '';

  // Expenses used to only ever show the literal current month's "This month"
  // figure with no way to look back — the list itself was every expense ever
  // logged, all-time, with no month scoping at all.
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

  void _stepMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      // A category chip from the old month may not exist in the new one —
      // left as-is, filtering by it would silently show an empty list with
      // no chip visibly selected to explain why.
      _category = 'All';
    });
  }

  static const _categoryColors = {
    'Supplies': Color(0xFF182C4F),
    'Rent': Color(0xFFDC2626),
    'Utilities': Color(0xFFF59E0B),
    'Maintenance': Color(0xFF2563EB),
    'Salary': Color(0xFF10B981),
    'Transport': Color(0xFF0EA5E9),
  };

  static Color _colorFor(String category) =>
      _categoryColors[category] ?? const Color(0xFF64748B);

  static String _methodLabel(AppProvider provider, String raw) =>
      provider.paymentMethods
          .firstWhere((c) => c.value == raw,
              orElse: () => ChoiceModel(value: raw, label: raw))
          .label;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final all = provider.expenses;

    // An expense with no recorded date can't be excluded from any month —
    // it stays visible everywhere rather than silently vanishing the moment
    // a month filter exists at all.
    final monthFiltered = all
        .where((e) =>
            e.date == null ||
            (e.date!.year == _selectedMonth.year &&
                e.date!.month == _selectedMonth.month))
        .toList();

    final categories = <String>{for (final e in monthFiltered) e.category}
        .toList()
      ..sort();
    final query = _searchQuery.trim().toLowerCase();
    final visible = monthFiltered.where((e) {
      final matchesCategory = _category == 'All' || e.category == _category;
      final matchesSearch = query.isEmpty ||
          e.title.toLowerCase().contains(query) ||
          e.category.toLowerCase().contains(query) ||
          _methodLabel(provider, e.paymentMethod).toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    final total = all.fold<double>(0, (sum, e) => sum + e.amount);
    final monthTotal =
        monthFiltered.fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: Column(
          children: [
            // No action button here — the in-page "Add Expense" button in
            // _titleRow below is the one, pre-existing control for this;
            // giving the header its own copy would just be a second button
            // doing the same job (the same redundant-duplicate pattern this
            // codebase has already caught and removed on Services and
            // Staff — see wip.md).
            const TopHeader(title: 'Expenses'),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth <
                      SidebarNavigation.contentWideBreakpoint;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleRow(narrow, visible),
                        const SizedBox(height: 16),
                        _monthNav(),
                        const SizedBox(height: 16),
                        _summaryRow(monthTotal, total, monthFiltered.length),
                        const SizedBox(height: 20),
                        if (categories.isNotEmpty) ...[
                          _filterChips(categories),
                          const SizedBox(height: 16),
                        ],
                        _list(visible, provider),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleRow(bool narrow, List<ExpenseModel> visible) {
    const titleBlock = Expanded(
      child: Text('Log shop operational expenses, rent, detergents, & repairs',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              titleBlock,
              SizedBox(
                width: 38,
                height: 38,
                child: FilledButton(
                  onPressed: _showAddExpense,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF182C4F),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.add_rounded, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _searchField(),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _exportButton(visible),
          ),
        ],
      );
    }

    return Row(
      children: [
        titleBlock,
        SizedBox(width: 240, child: _searchField()),
        const SizedBox(width: 14),
        _exportButton(visible),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _showAddExpense,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Expense'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF182C4F),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 38,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EFEA),
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
                  hintText: 'Search by title, category, or method...',
                  hintStyle:
                      TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportButton(List<ExpenseModel> visible) {
    return OutlinedButton.icon(
      onPressed: () => _exportExpensesCsv(visible),
      icon: const Icon(Icons.download_rounded,
          size: 16, color: Color(0xFF475569)),
      label: const Text('Export',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155))),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE4E0D8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  /// Exports exactly what's on screen — the currently category-filtered and
  /// searched rows — same convention as Orders'/Customers' Export.
  void _exportExpensesCsv(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export.')),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    final rows = <List<Object?>>[
      const ['Title', 'Category', 'Amount', 'Payment Method', 'Date', 'Notes'],
      for (final e in expenses)
        [
          e.title,
          e.category,
          e.amount,
          _methodLabel(provider, e.paymentMethod),
          e.date == null ? '' : DateFormat('yyyy-MM-dd').format(e.date!),
          e.notes ?? '',
        ],
    ];

    final filename =
        'expenses_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final ok = downloadCsv(filename, buildCsv(rows));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export is only available in the web app.')),
      );
    }
  }

  /// Chevron month stepper — same pattern as Payroll's, so switching which
  /// month's expenses are shown reads the same way across both screens.
  Widget _monthNav() {
    return Container(
      key: const Key('expenseMonthNav'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            tooltip: 'Previous month',
            onPressed: () => _stepMonth(-1),
          ),
          Text(
            _monthLabel,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            tooltip: 'Next month',
            onPressed: () => _stepMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(double monthTotal, double allTimeTotal, int count) {
    final cards = [
      _summaryCard(
          _monthLabel,
          '${Money.symbol}${monthTotal.toStringAsFixed(0)}',
          Icons.calendar_month_rounded,
          const Color(0xFFDC2626)),
      _summaryCard('Total logged (all time)',
          '${Money.symbol}${allTimeTotal.toStringAsFixed(0)}',
          Icons.account_balance_wallet_outlined, const Color(0xFF182C4F)),
      _summaryCard('Entries this month', '$count', Icons.receipt_long_outlined,
          const Color(0xFF2563EB)),
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
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF141A24))),
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
            selectedColor: const Color(0xFF182C4F),
            side: BorderSide(
              color: _category == c
                  ? const Color(0xFF182C4F)
                  : const Color(0xFFE4E0D8),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                : _searchQuery.trim().isNotEmpty
                    ? 'No expenses match "${_searchQuery.trim()}".'
                    : _category == 'All'
                        ? 'No expenses logged in $_monthLabel.'
                        : 'No $_category expenses logged in $_monthLabel.',
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
                    : const Border(top: BorderSide(color: Color(0xFFE4E0D8))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _colorFor(expenses[i].category)
                          .withValues(alpha: 0.12),
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
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF141A24))),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorFor(expenses[i].category)
                                    .withValues(alpha: 0.12),
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
                                '${_methodLabel(provider, expenses[i].paymentMethod)} · '
                                '${expenses[i].date == null ? 'No date' : DateFormat('MMM d, yyyy').format(expenses[i].date!)}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                        if (expenses[i].notes != null &&
                            expenses[i].notes!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            expenses[i].notes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                      '${Money.symbol}${expenses[i].amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444))),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Expense options',
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _showExpenseDialog(existing: expenses[i]);
                      } else if (action == 'delete') {
                        _showDeleteExpenseConfirm(expenses[i]);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 15, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Text('Edit', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 15, color: Color(0xFFDC2626)),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddExpense() => _showExpenseDialog();

  /// [existing] null adds an expense; non-null edits it in place — same
  /// dialog either way, same shape `customers_screen.dart`'s
  /// `_showCustomerDialog` uses for the same reason.
  ///
  /// Takes no `BuildContext`: a parameter of that name would shadow
  /// `State.context`, and the `mounted` check below would then be guarding a
  /// different context than the snackbar uses.
  Future<void> _showExpenseDialog({ExpenseModel? existing}) async {
    final isEdit = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
        text: existing == null ? '' : existing.amount.toStringAsFixed(0));
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final provider = context.read<AppProvider>();

    // Vocabularies come from `/api/meta/` now. This screen used to hold its
    // own seven categories and four payment methods, while New Order offered
    // three methods and Payroll four in a different order.
    final categoryChoices = provider.expenseCategories;
    final methodChoices = provider.paymentMethods;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var category = existing?.category ??
            (categoryChoices.isEmpty
                ? 'Supplies'
                : categoryChoices.first.value);
        var method = existing?.paymentMethod ?? methodChoices.first.value;
        var date = existing?.date ?? DateTime.now();
        String? error;
        var saving = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEdit ? 'Edit Expense' : 'Add Expense',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141A24))),
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
                      decoration:
                          _fieldDecoration('e.g. Commercial detergent (50L)'),
                    ),
                    const SizedBox(height: 14),
                    _label('Amount (${Money.symbol})'),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: _fieldDecoration('0'),
                    ),
                    const SizedBox(height: 14),
                    _label('Category'),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isDense: true,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF141A24)),
                      decoration: _fieldDecoration(''),
                      items: [
                        for (final c in categoryChoices)
                          DropdownMenuItem(
                              value: c.value, child: Text(c.label)),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => category = v ?? category),
                    ),
                    const SizedBox(height: 14),
                    _label('Payment method'),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      isDense: true,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF141A24)),
                      decoration: _fieldDecoration(''),
                      items: [
                        for (final m in methodChoices)
                          DropdownMenuItem(
                              value: m.value, child: Text(m.label)),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => method = v ?? method),
                    ),
                    const SizedBox(height: 14),
                    _label('Date'),
                    AppDateButton(
                      label: DateFormat('MMM d, yyyy').format(date),
                      onPressed: () async {
                        final picked = await AppDatePicker.pickDate(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => date = picked);
                      },
                    ),
                    const SizedBox(height: 14),
                    _label('Notes (optional)'),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      decoration: _fieldDecoration('Additional details, receipt ref, etc.'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFDC2626))),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final amount =
                            double.tryParse(amountController.text.trim());
                        if (title.isEmpty) {
                          setDialogState(
                              () => error = 'Give the expense a title.');
                          return;
                        }
                        if (amount == null || amount <= 0) {
                          setDialogState(() =>
                              error = 'Enter an amount greater than zero.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        final notesText = notesController.text.trim();
                        final payload = {
                          'title': title,
                          'category': category,
                          'amount': amount,
                          'payment_method': method,
                          'date': date.toUtc().toIso8601String(),
                          'notes': notesText.isEmpty ? null : notesText,
                        };
                        final ok = isEdit
                            ? await provider.updateExpense(existing.id, payload)
                            : await provider.addExpense(payload);
                        if (!ctx.mounted) return;
                        if (ok) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            saving = false;
                            error =
                                provider.error ?? 'Could not save the expense.';
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF182C4F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  saving
                      ? 'Saving…'
                      : (isEdit ? 'Save Changes' : 'Add Expense'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isEdit ? 'Expense updated.' : 'Expense logged.')),
      );
    }
  }

  Future<void> _showDeleteExpenseConfirm(ExpenseModel e) async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24))),
        content: Text(
            'Are you sure you want to delete "${e.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await provider.deleteExpense(e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Deleted "${e.title}".'
            : (provider.error ?? 'Could not delete the expense.')),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569))),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );
}

const BoxDecoration _panel = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFE4E0D8))),
);
