import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/portal_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'portal_shell.dart';

NumberFormat _money(BuildContext context) => NumberFormat.currency(
    symbol: context.read<PortalProvider>().shop?['currency_symbol'] as String? ?? '₹',
    decimalDigits: 0,
    locale: 'en_IN');

String _pickupText(Map<String, dynamic> o) {
  final d = DateTime.tryParse('${o['pickup_date']}');
  if (d == null) return '';
  final t = '${o['pickup_time'] ?? ''}';
  final time = t.length >= 5
      ? DateFormat('h:mm a')
          .format(DateTime(2000, 1, 1, int.parse(t.substring(0, 2)), int.parse(t.substring(3, 5))))
      : '';
  return 'Pickup ${DateFormat('EEE d MMM').format(d)}${time.isEmpty ? '' : ', $time'}';
}

/// The customer's own orders in this shop: a month calendar to jump to a day,
/// the list grouped by the day they were booked, and pages of 10.
class PortalOrdersScreen extends StatefulWidget {
  const PortalOrdersScreen({super.key});

  @override
  State<PortalOrdersScreen> createState() => _PortalOrdersScreenState();
}

class _PortalOrdersScreenState extends State<PortalOrdersScreen> {
  static const _pageSize = 10;

  List<Map<String, dynamic>>? _orders;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  String? _error;

  /// The calendar's month (its first day), the orders per day in it, and the
  /// day the list is narrowed to, if any.
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, int> _days = const {};
  DateTime? _day;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadMonth();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Another page starts at the top, not where the pager button was.
  Future<void> _turnPage(int page) async {
    await _load(page: page);
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  static String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load({int page = 1}) async {
    setState(() => _error = null);
    try {
      final res = await ApiService.fetchMyOrdersPage(
          page: page, pageSize: _pageSize, date: _day == null ? null : _iso(_day!));
      if (!mounted) return;
      setState(() {
        _orders = [for (final o in res['orders'] as List) Map<String, dynamic>.from(o as Map)];
        _page = res['page'] as int? ?? 1;
        _pages = res['pages'] as int? ?? 1;
        _total = res['total'] as int? ?? _orders!.length;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadMonth() async {
    try {
      final days = await ApiService.fetchOrderCalendar(DateFormat('yyyy-MM').format(_month));
      if (mounted) setState(() => _days = days);
    } on ApiException {
      // The list still works without the dots.
    }
  }

  void _shiftMonth(int by) {
    setState(() {
      _month = DateTime(_month.year, _month.month + by);
      _days = const {};
    });
    _loadMonth();
  }

  void _pickDay(DateTime? day) {
    setState(() => _day = day);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final money = _money(context);
    final List<Widget> list;
    if (orders == null) {
      list = [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: _error == null
                ? const CircularProgressIndicator(strokeWidth: 2.5)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Try again')),
                  ]),
          ),
        ),
      ];
    } else if (orders.isEmpty && _day == null) {
      list = [_noOrders(context)];
    } else if (orders.isEmpty) {
      list = [
        PortalPanel(
          child: Text('No orders booked on ${DateFormat('EEE d MMM').format(_day!)}.',
              style: const TextStyle(color: AppColors.muted)),
        ),
      ];
    } else {
      list = [
        for (final g in _byDay(orders)) ...[
          _DayHeader(
            label: _dayLabel(g.day),
            summary: '${g.orders.length} order${g.orders.length == 1 ? '' : 's'} · '
                '${money.format(g.orders.fold<num>(0, (s, o) => s + ((o['total_amount'] as num?) ?? 0)))}',
          ),
          PortalPanel(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < g.orders.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
                _OrderRow(order: g.orders[i], money: money),
              ],
            ]),
          ),
        ],
        if (_pages > 1) ...[
          const SizedBox(height: 16),
          _Pager(
            page: _page,
            pages: _pages,
            total: _total,
            onPage: _turnPage,
          ),
        ],
      ];
    }
    return PortalShell(
      index: 1,
      title: 'Your orders',
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_load(page: _page), _loadMonth()]);
        },
        child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _HistoryCalendar(
                month: _month,
                counts: _days,
                selected: _day,
                onMonth: _shiftMonth,
                onDay: (d) => _pickDay(_day != null && _iso(_day!) == _iso(d) ? null : d),
              ),
              if (_day != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Text(
                        'Showing ${DateFormat('EEE d MMM').format(_day!)}'
                        '${orders == null ? '' : ' · $_total order${_total == 1 ? '' : 's'}'}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  ),
                  TextButton(onPressed: () => _pickDay(null), child: const Text('All dates')),
                ]),
              ],
              const SizedBox(height: 4),
              ...list,
            ]),
      ),
    );
  }

  Widget _noOrders(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: PortalPanel(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('No orders with ${context.watch<PortalProvider>().shopName} yet',
                style: AppTypography.sectionTitle),
            const SizedBox(height: 4),
            const Text('Book a pickup and it shows up here, with its status as it moves.',
                style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => context.go('/book'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Book a pickup'),
            ),
          ]),
        ),
      );
}

/// A month of the customer's history: a dot under each day with orders; tap
/// a day to list just that day (tap again to clear). Weeks start on Monday.
class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar({
    required this.month,
    required this.counts,
    required this.selected,
    required this.onMonth,
    required this.onDay,
  });

  final DateTime month;
  final Map<String, int> counts;
  final DateTime? selected;
  final ValueChanged<int> onMonth;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lead = month.weekday - 1; // blanks before the 1st
    final days = DateTime(month.year, month.month + 1, 0).day;
    final isCurrent = month.year == now.year && month.month == now.month;
    final booked = counts.values.fold<int>(0, (a, b) => a + b);
    String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

    return PortalPanel(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => onMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded, color: AppColors.ink),
          ),
          Expanded(
            child: Column(children: [
              Text(DateFormat('MMMM y').format(month),
                  style: AppTypography.sectionTitle
                      .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              Text(booked == 0 ? 'No orders' : '$booked order${booked == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ]),
          ),
          IconButton(
            tooltip: 'Next month',
            // Nothing is booked in the future.
            onPressed: isCurrent ? null : () => onMonth(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Expanded(
              child: Text(w,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted)),
            ),
        ]),
        const SizedBox(height: 4),
        for (var row = 0; row * 7 < lead + days; row++)
          Row(children: [
            for (var col = 0; col < 7; col++)
              Expanded(
                child: Builder(builder: (context) {
                  final n = row * 7 + col - lead + 1;
                  if (n < 1 || n > days) return const SizedBox(height: 40);
                  final d = DateTime(month.year, month.month, n);
                  final count = counts[iso(d)] ?? 0;
                  final picked = selected != null && iso(selected!) == iso(d);
                  final future = d.isAfter(today);
                  return _DayCell(
                    day: n,
                    count: count,
                    picked: picked,
                    today: d == today,
                    muted: future,
                    onTap: future ? null : () => onDay(d),
                  );
                }),
              ),
          ]),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.picked,
    required this.today,
    required this.muted,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool picked;
  final bool today;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = picked
        ? AppColors.onPrimary
        : muted
            ? const Color(0xFFC4C0B8)
            : AppColors.ink;
    return Semantics(
      button: onTap != null,
      label: '$day${count == 0 ? '' : ', $count order${count == 1 ? '' : 's'}'}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: picked ? AppColors.primary : null,
                border: today && !picked ? Border.all(color: AppColors.primary) : null,
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$day',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: count > 0 || today ? FontWeight.w700 : FontWeight.w400,
                        color: fg,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: count == 0
                        ? Colors.transparent
                        : picked
                            ? AppColors.onPrimary
                            : AppColors.accent,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Newer · "Page 2 of 3" · Older, under the list.
class _Pager extends StatelessWidget {
  const _Pager(
      {required this.page, required this.pages, required this.total, required this.onPage});

  final int page;
  final int pages;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    return Row(children: [
      OutlinedButton.icon(
        onPressed: page > 1 ? () => onPage(page - 1) : null,
        style: style,
        icon: const Icon(Icons.chevron_left_rounded, size: 18),
        label: const Text('Newer'),
      ),
      Expanded(
        child: Column(children: [
          Text('Page $page of $pages',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()])),
          Text('$total orders', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ]),
      ),
      OutlinedButton(
        onPressed: page < pages ? () => onPage(page + 1) : null,
        style: style,
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Older'),
          SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18),
        ]),
      ),
    ]);
  }
}

/// Orders grouped by the local day they were booked, newest day first.
List<({DateTime? day, List<Map<String, dynamic>> orders})> _byDay(
    List<Map<String, dynamic>> orders) {
  final groups = <DateTime?, List<Map<String, dynamic>>>{};
  for (final o in orders) {
    final at = DateTime.tryParse('${o['created_at']}')?.toLocal();
    final day = at == null ? null : DateTime(at.year, at.month, at.day);
    groups.putIfAbsent(day, () => []).add(o);
  }
  final days = groups.keys.toList()
    ..sort((a, b) => b == null
        ? -1
        : a == null
            ? 1
            : b.compareTo(a));
  return [for (final d in days) (day: d, orders: groups[d]!)];
}

String _dayLabel(DateTime? day) {
  if (day == null) return 'Earlier';
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day).difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat(day.year == now.year ? 'EEE d MMM' : 'EEE d MMM y').format(day);
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.summary});

  final String label;
  final String summary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Row(children: [
          Expanded(
            child: Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFF475569))),
          ),
          Text(summary, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      );
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.money});

  final Map<String, dynamic> order;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final count = (o['items'] as List).length;
    final at = DateTime.tryParse('${o['created_at']}')?.toLocal();
    return InkWell(
      onTap: () => context.go('/orders/${Uri.encodeComponent('${o['order_number']}')}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${o['order_number']}', style: AppTypography.sectionTitle),
              const SizedBox(height: 2),
              Text(
                  [
                    if (at != null) 'Booked ${DateFormat('h:mm a').format(at)}',
                    '$count item${count == 1 ? '' : 's'}',
                    _pickupText(o),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money.format(o['total_amount'] ?? 0), style: AppTypography.sectionTitle),
            const SizedBox(height: 2),
            _StatusTag(status: '${o['status']}'),
          ]),
        ]),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final done = status == 'DELIVERED';
    final cancelled = status == 'CANCELLED';
    final color = cancelled
        ? AppColors.danger
        : done
            ? AppColors.success
            : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(portalStatusLabels[status] ?? status,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// One order: items, amounts, the status timeline and a QR the shop can scan.
class PortalOrderDetailScreen extends StatefulWidget {
  const PortalOrderDetailScreen({super.key, required this.orderNumber, this.justBooked = false});

  final String orderNumber;
  final bool justBooked;

  @override
  State<PortalOrderDetailScreen> createState() => _PortalOrderDetailScreenState();
}

class _PortalOrderDetailScreenState extends State<PortalOrderDetailScreen> {
  Map<String, dynamic>? _order;
  String? _error;

  static const _timeline = [
    ('PLACED', 'placed_at'),
    ('PROCESSING', 'processing_at'),
    ('IRONING', 'ironing_at'),
    ('READY', 'ready_at'),
    ('OUT_FOR_DELIVERY', 'out_for_delivery_at'),
    ('DELIVERED', 'delivered_at'),
  ];

  @override
  void initState() {
    super.initState();
    ApiService.fetchMyOrder(widget.orderNumber).then((o) {
      if (mounted) setState(() => _order = o);
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final portal = context.watch<PortalProvider>();
    if (o == null) {
      return PortalShell(
        index: 1,
        title: '#${widget.orderNumber}',
        child: Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!)),
      );
    }
    final money = _money(context);
    final fmt = DateFormat('d MMM, h:mm a');
    final cancelled = o['status'] == 'CANCELLED';
    return PortalShell(
      index: 1,
      title: '#${o['order_number']}',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.justBooked) ...[
          PortalPanel(
            child: Text('Booking received by ${portal.shopName}. ${_pickupText(o)}.',
                style: const TextStyle(color: AppColors.ink, height: 1.4)),
          ),
          const SizedBox(height: 12),
        ],
        PortalPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Status', style: AppTypography.sectionTitle),
            const SizedBox(height: 10),
            if (cancelled)
              Text(
                  'Cancelled ${o['cancelled_at'] != null ? fmt.format(DateTime.parse('${o['cancelled_at']}').toLocal()) : ''}',
                  style: const TextStyle(color: AppColors.danger))
            else
              for (final (status, field) in _timeline)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(o[field] != null ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18, color: o[field] != null ? AppColors.success : AppColors.border),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(portalStatusLabels[status]!,
                            style: TextStyle(
                                color: o[field] != null ? AppColors.ink : AppColors.muted))),
                    if (o[field] != null)
                      Text(fmt.format(DateTime.parse('${o[field]}').toLocal()),
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ]),
                ),
          ]),
        ),
        const SizedBox(height: 12),
        PortalPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Items', style: AppTypography.sectionTitle),
            const SizedBox(height: 8),
            for (final raw in o['items'] as List)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(
                      child: Text('${(raw as Map)['quantity']} × ${raw['item_title']}'
                          '  ·  ${raw['service_type']}')),
                  Text(money.format(raw['total_price'] ?? 0)),
                ]),
              ),
            const Divider(color: AppColors.border, height: 20),
            Row(children: [
              const Expanded(child: Text('Total', style: AppTypography.sectionTitle)),
              Text(money.format(o['total_amount'] ?? 0), style: AppTypography.sectionTitle),
            ]),
            if ((o['due_amount'] as num? ?? 0) > 0)
              Text('To pay on delivery: ${money.format(o['due_amount'])}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 12),
        PortalPanel(
          child: Builder(builder: (context) {
            final pickup = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pickup', style: AppTypography.sectionTitle),
              const SizedBox(height: 6),
              Text(_pickupText(o).replaceFirst('Pickup ', '')),
              if ('${o['address'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                    '${o['address']}${'${o['pin_code'] ?? ''}'.isEmpty ? '' : ' - ${o['pin_code']}'}',
                    style: const TextStyle(color: AppColors.muted)),
              ],
            ]);
            final qr = Column(children: [
              QrImageView(data: '${o['order_number']}', size: 96, padding: EdgeInsets.zero),
              const SizedBox(height: 4),
              const Text('Show at the shop',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ]);
            // Beside the address the QR squeezes it into a sliver on a phone.
            if (MediaQuery.sizeOf(context).width < 420) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                pickup,
                const Divider(height: 24, color: AppColors.borderSubtle),
                Center(child: qr),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: pickup),
              const SizedBox(width: 12),
              qr,
            ]);
          }),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/orders'), child: const Text('All orders')),
      ]),
    );
  }
}
