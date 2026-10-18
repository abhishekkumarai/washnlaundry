import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/portal_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/item_art.dart';
import 'address_editor.dart';
import 'portal_shell.dart';

/// New Order in customer mode, one step at a time: items (the shop's own
/// prices), a pickup slot with room left, an address, then a review. The server re-prices
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
  int _step = 0;

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
        for (final d in (_options?['days'] as List? ?? const []))
          Map<String, dynamic>.from(d as Map)
      ];

  List<Map<String, dynamic>> _openSlots(Map<String, dynamic> day) => [
        for (final s in (day['slots'] as List? ?? const []))
          if ((s as Map)['remaining'] != 0) Map<String, dynamic>.from(s)
      ];

  Map<int, Map<String, dynamic>> get _itemsById => {
        for (final c in _categories)
          for (final i in (c['items'] as List))
            (i as Map)['id'] as int: Map<String, dynamic>.from(i)
      };

  double get _total {
    final items = _itemsById;
    return _qty.entries
        .fold(0.0, (sum, e) => sum + ((items[e.key]?['price'] as num?) ?? 0) * e.value);
  }

  Map<String, dynamic>? get _address => _addresses.where((a) => a['id'] == _addressId).firstOrNull;

  bool get _pincodeServed {
    final pins = [for (final p in (_options?['pincodes'] as List? ?? const [])) '$p'];
    final pin = _address?['pin_code'];
    return pins.isEmpty || pin == null || pins.contains('$pin');
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
        _step = 1;
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

  static const _stepNames = ['Items', 'Pickup time', 'Address', 'Review'];

  /// What stops [step] from moving on, or null when it is done.
  String? _blockerFor(int step) => switch (step) {
        0 => _qty.values.every((q) => q == 0) ? 'Add at least one item.' : null,
        1 => _date == null || _slotId == null ? 'Choose a pickup time.' : null,
        2 => _address == null
            ? 'Add a pickup address.'
            : !_pincodeServed
                ? 'The shop does not pick up from ${_address!['pin_code']} yet.'
                : null,
        _ => null,
      };

  /// The furthest step that can be opened: every step before it is done.
  int get _reachable {
    for (var s = 0; s < 3; s++) {
      if (_blockerFor(s) != null) return s;
    }
    return 3;
  }

  void _goTo(int step) => setState(() {
        _step = step.clamp(0, _reachable);
        _error = null;
      });

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
    final blocker = _blockerFor(_step);
    final last = _step == _stepNames.length - 1;
    final pieces = _qty.values.fold<int>(0, (s, q) => s + q);
    return PortalShell(
      index: 0,
      title: 'Book a pickup',
      child: Column(children: [
        _StepBar(
          names: _stepNames,
          current: _step,
          reachable: _reachable,
          onTap: _goTo,
        ),
        Expanded(
          child: ListView(
            key: PageStorageKey('book-step-$_step'),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: switch (_step) {
              0 => _itemsStep(money),
              1 => _timeStep(),
              2 => _addressStep(),
              _ => _reviewStep(money),
            },
          ),
        ),
        if (_step == 0)
          _cartFooter(money, pieces)
        else
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
                      style: TextStyle(
                          fontSize: 13,
                          color: _error != null ? AppColors.danger : AppColors.muted)),
                ),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        pieces == 0
                            ? 'Estimated total'
                            : 'Estimated total · $pieces item${pieces == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    Text(money.format(_total), style: AppTypography.kpiHero),
                  ]),
                ),
                if (_step > 0) ...[
                  OutlinedButton(
                    onPressed: _busy ? null : () => _goTo(_step - 1),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(88, 48),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton(
                  onPressed: _busy || blocker != null
                      ? null
                      : last
                          ? _book
                          : () => _goTo(_step + 1),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 48),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(last
                      ? (_busy ? 'Booking…' : 'Book pickup')
                      : 'Continue to ${_stepNames[_step + 1].toLowerCase()}'),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }

  List<Widget> _itemsStep(NumberFormat money) {
    final cats = _categories;
    return [
      const _StepTitle(
          'What needs cleaning?', 'Prices are the shop\'s own. Pick a service, then add items.'),
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
              final count = picked.fold<int>(0, (s, it) => s + (_qty[(it as Map)['id']] ?? 0));
              return ChoiceChip(
                label: Text(count > 0 ? '${cats[i]['name']} · $count' : '${cats[i]['name']}'),
                selected: _category == i,
                onSelected: (_) => setState(() => _category = i),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        for (final raw in cats[_category.clamp(0, cats.length - 1)]['items'] as List) ...[
          _ItemRow(
            item: Map<String, dynamic>.from(raw as Map),
            quantity: _qty[(raw)['id']] ?? 0,
            money: money,
            onAdd: () => _changed(() => _qty[raw['id'] as int] = 1),
            onOpenCart: () => _openCart(money),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }

  /// Items step footer, as on the CRM's phone New Order: nothing to do until
  /// something is added, then a navy bar with the count and total that opens
  /// the cart.
  Widget _cartFooter(NumberFormat money, int pieces) {
    if (pieces == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: const Text('Add items to continue.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Material(
        key: const Key('portalCartBar'),
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openCart(money),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              const Icon(Icons.shopping_bag_outlined, color: AppColors.onPrimary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$pieces ${pieces == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                            color: AppColors.onPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    const TextSpan(
                        text: '  ·  ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                    TextSpan(
                        text: money.format(_total),
                        style: const TextStyle(
                            color: AppColors.onPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Text('View order',
                  style: TextStyle(
                      color: AppColors.onPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.onPrimary, size: 20),
            ]),
          ),
        ),
      ),
    );
  }

  /// The cart slid up over the list: each line with its stepper and remove,
  /// the total, and the way on to the pickup time.
  Future<void> _openCart(NumberFormat money) async {
    final next = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
        void set(int id, int q) {
          _changed(() => q <= 0 ? _qty.remove(id) : _qty[id] = q);
          if (_qty.values.every((v) => v == 0)) {
            Navigator.pop(sheet);
          } else {
            setSheet(() {});
          }
        }

        final items = _itemsById;
        final lines = [
          for (final e in _qty.entries)
            if (e.value > 0 && items[e.key] != null) (e.key, items[e.key]!, e.value)
        ];
        final count = lines.fold<int>(0, (s, l) => s + l.$3);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.88),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFD9D5CB), borderRadius: BorderRadius.circular(2)),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                  onPressed: () => Navigator.pop(sheet),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                const Expanded(child: Text('Your order', style: AppTypography.title)),
                Text('$count ${count == 1 ? 'item' : 'items'}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: lines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.borderSubtle),
                itemBuilder: (_, i) {
                  final (id, item, q) = lines[i];
                  return _CartLine(
                    item: item,
                    quantity: q,
                    money: money,
                    onChanged: (n) => set(id, n),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Column(children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Estimated total', style: AppTypography.sectionTitle)),
                    Text(money.format(_total), style: AppTypography.kpiHero),
                  ]),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheet, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Continue to pickup time'),
                  ),
                ]),
              ),
            ),
          ]),
        );
      }),
    );
    if (next == true && mounted) _goTo(1);
  }

  List<Widget> _timeStep() => [
        const _StepTitle('When should we pick up?', 'Slots close a little before they start.'),
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
      ];

  List<Widget> _addressStep() => [
        const _StepTitle('Where should we pick up?', 'Delivery comes back to the same address.'),
        if (_addresses.isNotEmpty)
          PortalPanel(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < _addresses.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
                _AddressRow(
                  address: _addresses[i],
                  selected: _addresses[i]['id'] == _addressId,
                  onTap: () => _changed(() => _addressId = _addresses[i]['id'] as int),
                ),
              ],
            ]),
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
      ];

  List<Widget> _reviewStep(NumberFormat money) {
    final items = _itemsById;
    final lines = [
      for (final e in _qty.entries)
        if (e.value > 0 && items[e.key] != null) (items[e.key]!, e.value)
    ];
    final day = _days.where((d) => d['date'] == _date).firstOrNull;
    final slot = (day?['slots'] as List? ?? const [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .where((s) => s['id'] == _slotId)
        .firstOrNull;
    final a = _address;
    return [
      const _StepTitle('Check and book', 'You pay when your clothes come back.'),
      _ReviewBlock(
        title: 'Items',
        onEdit: () => _goTo(0),
        child: Column(children: [
          for (final (item, q) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                    child: Text('${item['name']} × $q',
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.w500))),
                Text(money.format(((item['price'] as num?) ?? 0) * q), style: AppTypography.body),
              ]),
            ),
          const Divider(height: 18, color: AppColors.borderSubtle),
          Row(children: [
            const Expanded(child: Text('Estimated total', style: AppTypography.sectionTitle)),
            Text(money.format(_total), style: AppTypography.sectionTitle),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      _ReviewBlock(
        title: 'Pickup',
        onEdit: () => _goTo(1),
        child: Text(
            [
              if (_date != null) _PickupPicker.dayLabel(_date!),
              if (slot != null) '${slot['label']}'
            ].join(', '),
            style: AppTypography.bodyMedium),
      ),
      const SizedBox(height: 10),
      _ReviewBlock(
        title: 'Address',
        onEdit: () => _goTo(2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (a != null) ...[
            Text(_labelOf(a), style: AppTypography.bodyMedium),
            const SizedBox(height: 2),
            Text(_addressLine(a), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
          if (_notes.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Note: ${_notes.text.trim()}',
                style: const TextStyle(fontSize: 13, color: AppColors.ink)),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      const Text('The shop confirms the final bill after counting your clothes.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
    ];
  }
}

String _labelOf(Map<String, dynamic> a) =>
    const {'HOME': 'Home', 'WORK': 'Work', 'OTHER': 'Other'}[a['label']] ?? 'Address';

String _addressLine(Map<String, dynamic> a) => [
      a['address'],
      a['landmark'],
      a['area'],
      a['pin_code']
    ].where((v) => v != null && '$v'.isNotEmpty).join(', ');

/// Progress across the booking steps: numbered segments, done ones tappable.
class _StepBar extends StatelessWidget {
  const _StepBar(
      {required this.names, required this.current, required this.reachable, required this.onTap});

  final List<String> names;
  final int current;
  final int reachable;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        for (var i = 0; i < names.length; i++)
          Expanded(
            child: InkWell(
              onTap: i <= reachable && i != current ? () => onTap(i) : null,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(
                    i < current ? '✓' : '${i + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i <= current ? AppColors.primary : AppColors.muted),
                  ),
                  const SizedBox(width: 6),
                  if (!narrow || i == current)
                    Flexible(
                      child: Text(names[i],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: i == current ? FontWeight.w600 : FontWeight.w500,
                              color: i == current ? AppColors.ink : AppColors.muted)),
                    ),
                ]),
                const SizedBox(height: 8),
                Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i == names.length - 1 ? 0 : 6),
                  color: i <= current ? AppColors.primary : AppColors.borderSubtle,
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.title, this.hint);

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
        ]),
      );
}

/// One saved address as a selectable row.
class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.selected, required this.onTap});

  final Map<String, dynamic> address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          color: selected ? AppColors.accentSoft : null,
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20, color: selected ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_labelOf(address), style: AppTypography.sectionTitle),
                const SizedBox(height: 2),
                Text(_addressLine(address),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ]),
            ),
          ]),
        ),
      );
}

/// A section of the review step with an Edit link back to its step.
class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({required this.title, required this.onEdit, required this.child});

  final String title;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) => PortalPanel(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Color(0xFF475569))),
            ),
            TextButton(onPressed: onEdit, child: const Text('Edit')),
          ]),
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
        ]),
      );
}

const _units = {'PC': 'piece', 'KG': 'kg', 'SQFT': 'sq.ft', 'SET': 'set'};

/// One catalogue item, as the CRM's phone New Order shows it: art or photo,
/// name and price, and "+ Add to Cart" that turns into "In Cart · n" (which
/// opens the cart, where the quantity is changed).
class _ItemRow extends StatelessWidget {
  const _ItemRow(
      {required this.item,
      required this.quantity,
      required this.money,
      required this.onAdd,
      required this.onOpenCart});

  final Map<String, dynamic> item;
  final int quantity;
  final NumberFormat money;
  final VoidCallback onAdd;
  final VoidCallback onOpenCart;

  @override
  Widget build(BuildContext context) {
    final name = '${item['name']}';
    final art = itemArtFor(name);
    final photo = '${item['image_url'] ?? ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: quantity > 0 ? AppColors.primary : AppColors.border),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            color: AppColors.background,
            child: photo.isNotEmpty
                ? Image.network(photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(art.icon, size: 24, color: art.color))
                : Icon(art.icon, size: 24, color: art.color),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.ink)),
            const SizedBox(height: 2),
            Row(children: [
              Text(money.format(item['price'] ?? 0),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(width: 4),
              Flexible(
                child: Text('/ ${_units[item['unit']] ?? 'piece'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 112,
          child: quantity == 0
              ? OutlinedButton(
                  onPressed: onAdd,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('+ Add to Cart',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                )
              : Material(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onOpenCart,
                    child: SizedBox(
                      height: 38,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('In Cart · $quantity',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                        ),
                      ]),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}

/// A cart line: name, unit price, a stepper and remove (the CRM's cart line).
class _CartLine extends StatelessWidget {
  const _CartLine(
      {required this.item, required this.quantity, required this.money, required this.onChanged});

  final Map<String, dynamic> item;
  final int quantity;
  final NumberFormat money;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['name']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.ink)),
              Text('${money.format(item['price'] ?? 0)} each',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            height: 34,
            decoration:
                BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Fewer',
                icon: const Icon(Icons.remove, size: 15, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => onChanged(quantity - 1),
              ),
              SizedBox(
                width: 22,
                child: Text('$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.add, size: 15, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: quantity >= 100 ? null : () => onChanged(quantity + 1),
              ),
            ]),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => onChanged(0),
          ),
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

  /// "Today", "Tomorrow", else "Sat 18 Oct".
  static String dayLabel(String iso) {
    final d = DateTime.parse(iso);
    final now = DateTime.now();
    final diff =
        DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff == 0
        ? 'Today'
        : diff == 1
            ? 'Tomorrow'
            : DateFormat('EEE d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    if (days.every((d) => (d['slots'] as List).isEmpty)) {
      return const Text('The shop has not set pickup times yet. Call them to book.',
          style: TextStyle(color: AppColors.muted));
    }
    final day = days.where((d) => d['date'] == date).firstOrNull;
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
