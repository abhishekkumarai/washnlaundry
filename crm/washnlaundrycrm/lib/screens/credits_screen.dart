import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/top_header.dart';
import '../utils/money.dart';

/// `/credits` section — similar to expenses with notes.
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  /// Where credit categories are managed.
  static const settingsLink = '/settings?tab=credit-categories';

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  String _category = 'All';
  String _searchQuery = '';

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

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

  void _stepMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _category = 'All';
    });
  }

  static const _palette = [
    Color(0xFF10B981),
    Color(0xFF182C4F),
    Color(0xFFF59E0B),
    Color(0xFF2563EB),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF64748B),
  ];

  /// Categories are shop-managed now, so there is no fixed name → color map.
  /// A hash of the name keeps each category's color stable across reloads
  /// (String.hashCode is not guaranteed stable, so it is computed here).
  static Color _colorFor(String category) {
    var h = 0;
    for (final unit in category.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  Future<void> _showNoCategories() => showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No credit categories'),
          content:
              const Text('Every category is turned off. Add or turn one on in '
                  'Settings → Credit categories first.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go(CreditsScreen.settingsLink);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

  static String _methodLabel(AppProvider provider, String raw) =>
      provider.paymentMethods
          .firstWhere((c) => c.value == raw,
              orElse: () => ChoiceModel(value: raw, label: raw))
          .label;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final all = provider.credits;

    final monthFiltered = all
        .where((c) =>
            c.date == null ||
            (c.date!.year == _selectedMonth.year &&
                c.date!.month == _selectedMonth.month))
        .toList();

    final categories =
        <String>{for (final c in monthFiltered) c.category}.toList()..sort();
    final query = _searchQuery.trim().toLowerCase();
    final visible = monthFiltered.where((c) {
      final matchesCategory = _category == 'All' || c.category == _category;
      final matchesSearch = query.isEmpty ||
          c.title.toLowerCase().contains(query) ||
          c.category.toLowerCase().contains(query) ||
          _methodLabel(provider, c.paymentMethod).toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    final total = all.fold<double>(0, (sum, c) => sum + c.amount);
    final monthTotal =
        monthFiltered.fold<double>(0, (sum, c) => sum + c.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: Column(
          children: [
            const TopHeader(title: 'Credits'),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth <
                      SidebarNavigation.contentWideBreakpoint;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(narrow ? 16 : 24),
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

  Widget _titleRow(bool narrow, List<CreditModel> visible) {
    const titleBlock = Expanded(
      child: Text(
          'Log shop incoming credits, advance deposits, investments, & misc income',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Log shop incoming credits, advance deposits, investments, & misc income',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 80,
                child: _searchField(),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        titleBlock,
        SizedBox(width: 240, child: _searchField()),
        const SizedBox(width: 14),
        FilledButton.icon(
          onPressed: _showAddCredit,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Credit'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
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
                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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

  Widget _monthNav() {
    return Row(
      key: const Key('creditMonthNav'),
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left_rounded, size: 22),
          onPressed: () => _stepMonth(-1),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE4E0D8)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE4E0D8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _monthLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF141A24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Next month',
          icon: const Icon(Icons.chevron_right_rounded, size: 22),
          onPressed: () => _stepMonth(1),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE4E0D8)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(double monthTotal, double allTimeTotal, int count) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isMobile = constraints.maxWidth < 640 || screenWidth < 640;
        final perRow = (constraints.maxWidth < 280 && screenWidth < 340)
            ? 1
            : (isMobile ? 2 : 3);
        final cards = [
          _summaryCard(
            'This Month',
            '${Money.symbol}${monthTotal.toStringAsFixed(0)}',
            'In $_monthLabel',
            const Color(0xFF10B981),
            Icons.trending_up_rounded,
            isCompact: isMobile,
          ),
          _summaryCard(
            'All Time',
            '${Money.symbol}${allTimeTotal.toStringAsFixed(0)}',
            'Total credits logged',
            const Color(0xFF182C4F),
            Icons.account_balance_wallet_rounded,
            isCompact: isMobile,
          ),
          _summaryCard(
            'Entries',
            '$count',
            'Credits in $_monthLabel',
            const Color(0xFFF59E0B),
            Icons.receipt_rounded,
            isCompact: isMobile,
          ),
        ];

        const gap = 12.0;
        final itemWidth = (constraints.maxWidth - gap * (perRow - 1)) / perRow;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: itemWidth, child: card),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
    String label,
    String value,
    String sub,
    Color color,
    IconData icon, {
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 11 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Row(
        children: [
          Container(
            width: isCompact ? 32 : 44,
            height: isCompact ? 32 : 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
            ),
            child: Icon(icon, color: color, size: isCompact ? 17 : 22),
          ),
          SizedBox(width: isCompact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: isCompact ? 10.5 : 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
                SizedBox(height: isCompact ? 2 : 4),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: isCompact ? -0.3 : 0,
                        color: const Color(0xFF141A24))),
                SizedBox(height: isCompact ? 1 : 2),
                Text(sub,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: isCompact ? 10 : 11,
                        color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips(List<String> categories) {
    final list = ['All', ...categories];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in list) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: _category == c,
                label: Text(c),
                onSelected: (_) => setState(() => _category = c),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFDCFCE7),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      _category == c ? FontWeight.bold : FontWeight.normal,
                  color: _category == c
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF475569),
                ),
                side: BorderSide(
                  color: _category == c
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD9D5CB),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(List<CreditModel> credits, AppProvider provider) {
    if (credits.isEmpty) {
      final message = provider.isLoading
          ? 'Loading credits…'
          : _searchQuery.trim().isNotEmpty
              ? 'No credits match "${_searchQuery.trim()}".'
              : _category == 'All'
                  ? 'No credits logged in $_monthLabel.'
                  : 'No $_category credits logged in $_monthLabel.';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E0D8)),
        ),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 40, color: Color(0xFFD9D5CB)),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            if (!provider.isLoading && _searchQuery.trim().isEmpty) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _showAddCredit,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Credit'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: credits.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFF1EFEA)),
        itemBuilder: (context, i) {
          final c = credits[i];
          final color = _colorFor(c.category);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  // Money in: the arrow is green like the "+" amount, whatever
                  // the category's own color (that stays on the chip below).
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_downward_rounded,
                      size: 17, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF141A24))),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(c.category,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: color)),
                          ),
                          Text(
                            '${_methodLabel(provider, c.paymentMethod)} · '
                            '${c.date == null ? 'No date' : DateFormat('MMM d, yyyy').format(c.date!)}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      if (c.notes != null && c.notes!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          c.notes!,
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
                Text(
                  '+${Money.symbol}${c.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Credit options',
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showCreditDialog(existing: c);
                    } else if (value == 'delete') {
                      _showDeleteCreditConfirm(c);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
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
                              size: 16, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddCredit() => _showCreditDialog();

  Future<void> _showCreditDialog({CreditModel? existing}) async {
    final isEdit = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
        text: existing == null ? '' : existing.amount.toStringAsFixed(0));
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final provider = context.read<AppProvider>();

    // Only active categories can be picked, but an edit keeps showing the
    // credit's own category even if it has since been turned off — the
    // backend accepts an unchanged category either way.
    final categoryList = [
      for (final c in provider.activeCreditCategories) c.name,
    ];
    if (isEdit &&
        existing.category.isNotEmpty &&
        !categoryList.contains(existing.category)) {
      categoryList.add(existing.category);
    }
    if (categoryList.isEmpty) {
      await _showNoCategories();
      return;
    }

    String category = existing?.category ?? categoryList.first;
    if (!categoryList.contains(category)) {
      category = categoryList.first;
    }

    final methodChoices = provider.paymentMethods;
    final fallbackMethods = const [
      ChoiceModel(value: 'CASH', label: 'Cash'),
      ChoiceModel(value: 'UPI', label: 'UPI'),
      ChoiceModel(value: 'CARD', label: 'Card'),
      ChoiceModel(value: 'BANK_TRANSFER', label: 'Bank Transfer'),
    ];
    final methodList =
        methodChoices.isNotEmpty ? methodChoices : fallbackMethods;

    String method = existing?.paymentMethod ?? methodList.first.value;
    if (!methodList.any((m) => m.value == method)) {
      method = methodList.first.value;
    }

    DateTime date = existing?.date ?? DateTime.now();

    String? error;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Edit Credit' : 'Add Credit',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Title *'),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(fontSize: 13),
                    decoration: _fieldDecoration('e.g. Hotel advance payment'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _label('Category')),
                      // Categories live in Settings; this is the way there
                      // from the one place they are actually used.
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          context.go(CreditsScreen.settingsLink);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Manage',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: _fieldDecoration(''),
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF141A24)),
                    items: [
                      for (final c in categoryList)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => category = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  _label('Amount (${Money.symbol}) *'),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: _fieldDecoration('0.00'),
                  ),
                  const SizedBox(height: 14),
                  _label('Payment Method'),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: _fieldDecoration(''),
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF141A24)),
                    items: [
                      for (final m in methodList)
                        DropdownMenuItem(value: m.value, child: Text(m.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => method = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  _label('Date'),
                  AppDateButton(
                    label: DateFormat('MMM d, yyyy').format(date),
                    onPressed: () async {
                      final picked = await AppDatePicker.pickDate(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
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
                    decoration: _fieldDecoration(
                        'Additional details, receipt ref, client notes, etc.'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFEF4444))),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981)),
              onPressed: saving
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        setDialogState(
                            () => error = 'Give the credit entry a title.');
                        return;
                      }
                      final amount =
                          double.tryParse(amountController.text.trim());
                      if (amount == null || amount <= 0) {
                        setDialogState(
                            () => error = 'Enter a valid amount above zero.');
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
                          ? await provider.updateCredit(existing.id, payload)
                          : await provider.addCredit(payload);
                      if (!mounted) return;
                      if (ok) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(isEdit
                                  ? 'Credit updated.'
                                  : 'Credit logged.')),
                        );
                      } else {
                        setDialogState(() {
                          saving = false;
                          error = provider.error ??
                              'Could not save the credit entry.';
                        });
                      }
                    },
              child: Text(
                saving ? 'Saving…' : (isEdit ? 'Save Changes' : 'Add Credit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteCreditConfirm(CreditModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Credit',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${c.title}" '
          '(${Money.symbol}${c.amount.toStringAsFixed(0)})?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<AppProvider>();
    final ok = await provider.deleteCredit(c.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Credit deleted.'
            : (provider.error ?? 'Could not delete the credit.')),
      ),
    );
  }

  static Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569))),
      );

  static InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8F7F5),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD9D5CB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD9D5CB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
      );
}
