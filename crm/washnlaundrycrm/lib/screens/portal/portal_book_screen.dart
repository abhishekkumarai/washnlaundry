import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/portal_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'address_editor.dart';
import 'portal_shell.dart';

/// New Order in customer mode: pick items (the shop's own prices), a pickup
/// slot with room left, and one of their saved addresses. The server re-prices
/// everything; the total here is only a preview.
class PortalBookScreen extends StatefulWidget {
  const PortalBookScreen({super.key});

  @override
  State<PortalBookScreen> createState() => _PortalBookScreenState();
}

class _PortalBookScreenState extends State<PortalBookScreen> {
  Map<String, dynamic>? _options;
  List<Map<String, dynamic>> _addresses = [];
  String? _loadError;

  final Map<int, int> _qty = {};
  String? _date;
  int? _slotId;
  int? _addressId;
  final _notes = TextEditingController();
  int _category = 0;

  bool _busy = false;
  String? _error;

  /// Kept across retries of the same booking so a double tap or a timeout
  /// retry never creates two orders; renewed whenever the booking changes.
  String _key = _newKey();

  static String _newKey() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  void _changed(VoidCallback fn) => setState(() {
        fn();
        _key = _newKey();
        _error = null;
      });

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final results = await Future.wait([
        ApiService.fetchBookingOptions(),
        ApiService.fetchMyAddresses(),
      ]);
      if (!mounted) return;
      setState(() {
        _options = results[0] as Map<String, dynamic>;
        _addresses = results[1] as List<Map<String, dynamic>>;
        _addressId ??= _addresses.isEmpty ? null : _addresses.first['id'] as int;
        final days = _days;
        _date ??= days.firstWhere((d) => _openSlots(d).isNotEmpty,
            orElse: () => days.isEmpty ? <String, dynamic>{} : days.first)['date'] as String?;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  List<Map<String, dynamic>> get _categories => [
        for (final c in (_options?['categories'] as List? ?? const []))
          Map<String, dynamic>.from(c as Map)
      ];

  List<Map<String, dynamic>> get _days => [
        for (final d in (_options?['days'] as List? ?? const [])) Map<String, dynamic>.from(d as Map)
      ];

  List<Map<String, dynamic>> _openSlots(Map<String, dynamic> day) => [
        for (final s in (day['slots'] as List? ?? const []))
          if ((s as Map)['remaining'] != 0) Map<String, dynamic>.from(s)
      ];

  Map<int, Map<String, dynamic>> get _itemsById => {
        for (final c in _categories)
          for (final i in (c['items'] as List)) (i as Map)['id'] as int: Map<String, dynamic>.from(i)
      };

  double get _total {
    final items = _itemsById;
    return _qty.entries
        .fold(0.0, (sum, e) => sum + ((items[e.key]?['price'] as num?) ?? 0) * e.value);
  }

  Map<String, dynamic>? get _address =>
      _addresses.where((a) => a['id'] == _addressId).firstOrNull;

  bool get _pincodeServed {
    final pins = [for (final p in (_options?['pincodes'] as List? ?? const [])) '$p'];
    final pin = _address?['pin_code'];
    return pins.isEmpty || pin == null || pins.contains('$pin');
  }

  String? get _blocker {
    if (_qty.values.every((q) => q == 0)) return 'Add at least one item.';
    if (_date == null || _slotId == null) return 'Choose a pickup time.';
    if (_address == null) return 'Add a pickup address.';
    if (!_pincodeServed) return 'The shop does not pick up from ${_address!['pin_code']} yet.';
    return null;
  }

  Future<void> _book() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await ApiService.placeBooking({
        'items': [
          for (final e in _qty.entries)
            if (e.value > 0) {'item_id': e.key, 'quantity': e.value}
        ],
        'pickup_date': _date,
        'slot_id': _slotId,
        'address_id': _addressId,
        'notes': _notes.text.trim(),
      }, _key);
      if (!mounted) return;
      context.go('/orders/${Uri.encodeComponent('${order['order_number']}')}?new=1');
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      // A slot that just filled up: show fresh capacity.
      if (e.statusCode == 409) {
        _slotId = null;
        _load();
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _addAddress() async {
    final saved = await showAddressEditor(context);
    if (saved == null || !mounted) return;
    _changed(() {
      _addresses = [..._addresses, saved];
      _addressId = saved['id'] as int;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<PortalProvider>().shop?['currency_symbol'] as String? ?? '₹';
    final money = NumberFormat.currency(symbol: currency, decimalDigits: 0, locale: 'en_IN');
    if (_options == null) {
      return PortalShell(
        index: 0,
        title: 'Book a pickup',
        child: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Try again')),
                ]),
        ),
      );
    }
    final cats = _categories;
    final blocker = _blocker;
    return PortalShell(
      index: 0,
      title: 'Book a pickup',
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const _Step(number: 1, title: 'What needs cleaning'),
            if (cats.isEmpty)
              const Text('This shop has not listed its services yet.',
                  style: TextStyle(color: AppColors.muted))
            else ...[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final picked = cats[i]['items'] as List;
                    final count = picked.fold<int>(
                        0, (s, it) => s + (_qty[(it as Map)['id']] ?? 0));
                    return ChoiceChip(
                      label: Text(count > 0 ? '${cats[i]['name']} · $count' : '${cats[i]['name']}'),
                      selected: _category == i,
                      onSelected: (_) => setState(() => _category = i),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              PortalPanel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final raw in cats[_category.clamp(0, cats.length - 1)]['items'] as List)
                    _ItemRow(
                      item: Map<String, dynamic>.from(raw as Map),
                      quantity: _qty[(raw)['id']] ?? 0,
                      money: money,
                      onChanged: (q) => _changed(() => _qty[raw['id'] as int] = q),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            const _Step(number: 2, title: 'Pickup time'),
            _PickupPicker(
              days: _days,
              openSlots: _openSlots,
              date: _date,
              slotId: _slotId,
              onDate: (d) => _changed(() {
                _date = d;
                _slotId = null;
              }),
              onSlot: (s) => _changed(() => _slotId = s),
            ),
            const SizedBox(height: 24),
            const _Step(number: 3, title: 'Pickup address'),
            for (final a in _addresses)
              RadioListTile<int>(
                value: a['id'] as int,
                groupValue: _addressId,
                onChanged: (v) => _changed(() => _addressId = v),
                contentPadding: EdgeInsets.zero,
                title: Text(_labelOf(a), style: AppTypography.sectionTitle),
                subtitle: Text(
                    [a['address'], a['landmark'], a['area'], a['pin_code']]
                        .where((v) => v != null && '$v'.isNotEmpty)
                        .join(', '),
                    style: const TextStyle(color: AppColors.muted)),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addAddress,
                icon: const Icon(Icons.add),
                label: Text(_addresses.isEmpty ? 'Add your address' : 'Add another address'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(
                  labelText: 'Notes for the shop (optional)',
                  hintText: 'e.g. Ring the bell twice; no starch',
                  border: OutlineInputBorder()),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_error != null || blocker != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error ?? blocker!,
                    style: TextStyle(color: _error != null ? AppColors.danger : AppColors.muted)),
              ),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Estimated total', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  Text(money.format(_total), style: AppTypography.kpiHero),
                ]),
              ),
              FilledButton(
                onPressed: _busy || blocker != null ? null : _book,
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                child: Text(_busy ? 'Booking…' : 'Book pickup'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

String _labelOf(Map<String, dynamic> a) =>
    const {'HOME': 'Home', 'WORK': 'Work', 'OTHER': 'Other'}[a['label']] ?? 'Address';

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text('$number', style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
          const SizedBox(width: 10),
          Text(title, style: AppTypography.title),
        ]),
      );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow(
      {required this.item, required this.quantity, required this.money, required this.onChanged});

  final Map<String, dynamic> item;
  final int quantity;
  final NumberFormat money;
  final ValueChanged<int> onChanged;

  static const _units = {'PC': 'piece', 'KG': 'kg', 'SQFT': 'sq.ft', 'SET': 'set'};

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['name']}', style: AppTypography.body.copyWith(fontWeight: FontWeight.w500)),
              Text('${money.format(item['price'] ?? 0)} / ${_units[item['unit']] ?? 'piece'}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          if (quantity == 0)
            OutlinedButton(onPressed: () => onChanged(1), child: const Text('Add'))
          else
            Row(children: [
              IconButton(
                  tooltip: 'Fewer',
                  onPressed: () => onChanged(quantity - 1),
                  icon: const Icon(Icons.remove_circle_outline)),
              SizedBox(
                  width: 28,
                  child: Text('$quantity',
                      textAlign: TextAlign.center, style: AppTypography.sectionTitle)),
              IconButton(
                  tooltip: 'More',
                  onPressed: quantity >= 100 ? null : () => onChanged(quantity + 1),
                  icon: const Icon(Icons.add_circle_outline)),
            ]),
        ]),
      );
}

class _PickupPicker extends StatelessWidget {
  const _PickupPicker({
    required this.days,
    required this.openSlots,
    required this.date,
    required this.slotId,
    required this.onDate,
    required this.onSlot,
  });

  final List<Map<String, dynamic>> days;
  final List<Map<String, dynamic>> Function(Map<String, dynamic>) openSlots;
  final String? date;
  final int? slotId;
  final ValueChanged<String> onDate;
  final ValueChanged<int> onSlot;

  @override
  Widget build(BuildContext context) {
    if (days.every((d) => (d['slots'] as List).isEmpty)) {
      return const Text('The shop has not set pickup times yet. Call them to book.',
          style: TextStyle(color: AppColors.muted));
    }
    final day = days.where((d) => d['date'] == date).firstOrNull;
    final today = DateTime.now();
    String dayLabel(String iso) {
      final d = DateTime.parse(iso);
      final diff = DateTime(d.year, d.month, d.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      return diff == 0 ? 'Today' : diff == 1 ? 'Tomorrow' : DateFormat('EEE d MMM').format(d);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in days)
          ChoiceChip(
            label: Text(dayLabel(d['date'] as String)),
            selected: d['date'] == date,
            onSelected: openSlots(d).isEmpty ? null : (_) => onDate(d['date'] as String),
          ),
      ]),
      const SizedBox(height: 12),
      if (day != null)
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in (day['slots'] as List).map((s) => Map<String, dynamic>.from(s as Map)))
            ChoiceChip(
              label: Text(s['remaining'] == 0
                  ? '${s['label']} · full'
                  : s['remaining'] != null && (s['remaining'] as int) <= 2
                      ? '${s['label']} · ${s['remaining']} left'
                      : '${s['label']}'),
              selected: s['id'] == slotId,
              onSelected: s['remaining'] == 0 ? null : (_) => onSlot(s['id'] as int),
            ),
        ]),
    ]);
  }
}
