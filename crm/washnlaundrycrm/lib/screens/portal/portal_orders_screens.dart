import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/portal_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'portal_shell.dart';
import 'portal_ticket.dart';

NumberFormat _money(BuildContext context) => NumberFormat.currency(
    symbol: context.read<PortalProvider>().shop?['currency_symbol'] as String? ?? '₹',
    decimalDigits: 0,
    locale: 'en_IN');

/// "Pickup Tue 21 Oct, 10:00 AM" for an order, or empty without a date.
String portalPickupText(Map<String, dynamic> o) {
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

  /// 0: Current (orders still moving, as claim tickets), 1: Past (the calendar
  /// and pages of delivered and cancelled orders).
  int _tab = 0;
  List<Map<String, dynamic>>? _current;
  String? _currentError;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCurrent();
    _load();
    _loadMonth();
  }

  Future<void> _loadCurrent() async {
    setState(() => _currentError = null);
    try {
      final res = await ApiService.fetchMyOrdersPage(pageSize: 50, state: 'current');
      if (!mounted) return;
      setState(() => _current = [
            for (final o in res['orders'] as List) Map<String, dynamic>.from(o as Map)
          ]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _currentError = e.message);
    }
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
          page: page, pageSize: _pageSize, date: _day == null ? null : _iso(_day!), state: 'past');
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
      final days =
          await ApiService.fetchOrderCalendar(DateFormat('yyyy-MM').format(_month), state: 'past');
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
    final current = _current;
    final List<Widget> currentList;
    if (current == null) {
      currentList = [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: _currentError == null
                ? const CircularProgressIndicator(strokeWidth: 2.5)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_currentError!),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _loadCurrent, child: const Text('Try again')),
                  ]),
          ),
        ),
      ];
    } else if (current.isEmpty) {
      currentList = [_noOrders(context, current: true)];
    } else {
      currentList = [
        for (final o in current) ...[
          _CurrentTicket(order: o, money: money),
          const SizedBox(height: 12),
        ],
      ];
    }
    return PortalShell(
      index: PortalSection.orders,
      title: 'Orders',
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadCurrent(), _load(page: _page), _loadMonth()]);
        },
        child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Segments(
                labels: [
                  current == null || current.isEmpty ? 'Current' : 'Current · ${current.length}',
                  'Past',
                ],
                selected: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 16),
              if (_tab == 0)
                ...currentList
              else ...[
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
              ],
            ]),
      ),
    );
  }

  Widget _noOrders(BuildContext context, {bool current = false}) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: PortalPanel(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                current
                    ? 'Nothing on the way'
                    : 'No past orders with ${context.watch<PortalProvider>().shopName} yet',
                style: AppTypography.sectionTitle),
            const SizedBox(height: 4),
            Text(
                current
                    ? 'Book a pickup and follow it here, step by step.'
                    : 'Delivered and cancelled orders show up here.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
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
                    portalPickupText(o),
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

/// Two tabs as a segmented control: white pill on the muted fill.
class _Segments extends StatelessWidget {
  const _Segments({required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.mutedFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == selected ? AppColors.card : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(labels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                            color: i == selected ? AppColors.ink : AppColors.muted)),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// What an order holds, in a few words: "Wash & fold, Dry clean · 4 pieces".
String _itemsSummary(Map<String, dynamic> o) {
  final items = [for (final i in (o['items'] as List? ?? const [])) Map<String, dynamic>.from(i as Map)];
  final services = {for (final i in items) '${i['service_type']}'}.where((s) => s.isNotEmpty);
  final pieces = items.fold<num>(0, (s, i) => s + ((i['quantity'] as num?) ?? 0));
  final count = pieces == pieces.roundToDouble() ? '${pieces.round()}' : '$pieces';
  return [services.join(', '), '$count piece${pieces == 1 ? '' : 's'}']
      .where((s) => s.isNotEmpty)
      .join(' · ');
}

/// One order still moving, as a claim ticket on the Current tab.
class _CurrentTicket extends StatelessWidget {
  const _CurrentTicket({required this.order, required this.money});

  final Map<String, dynamic> order;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final number = '${o['order_number']}';
    final pickup = portalPickupText(o);
    return PortalTicket(
      orderNumber: number,
      status: '${o['status']}',
      onTap: () => context.go('/orders/${Uri.encodeComponent(number)}'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(_itemsSummary(o),
                style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          ),
          Text(money.format(o['total_amount'] ?? 0),
              style: portalMono(size: 15, weight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        PortalStatusLine(status: '${o['status']}'),
        if (pickup.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.schedule, size: 15, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(pickup, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ]),
        ],
      ]),
    );
  }
}

/// One order: the claim ticket with its status line, items, pickup address, a
/// QR the shop can scan and "Need help with this order?". With [justBooked]
/// (`?placed=1`, straight after booking) it opens with "Pickup booked".
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

  /// The customer's five steps and the timestamp that marks each one done
  /// (Cleaning: whichever of processing / ironing came first).
  static const _timeline = [
    ('Booked', ['placed_at']),
    ('Cleaning', ['processing_at', 'ironing_at']),
    ('Ready', ['ready_at']),
    ('Out for delivery', ['out_for_delivery_at']),
    ('Delivered', ['delivered_at']),
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

  Widget _backLink(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.go('/orders'),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Orders'),
          style: TextButton.styleFrom(foregroundColor: AppColors.ink),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final portal = context.watch<PortalProvider>();
    if (o == null) {
      return PortalShell(
        index: PortalSection.orders,
        child: Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!)),
      );
    }
    final money = _money(context);
    final fmt = DateFormat('EEE d MMM, h:mm a');
    String? when(String field) {
      final d = DateTime.tryParse('${o[field] ?? ''}');
      return d == null ? null : fmt.format(d.toLocal());
    }

    final number = '${o['order_number']}';
    final status = '${o['status']}';
    final cancelled = status == 'CANCELLED';
    final at = portalStepIndex(status);
    final booked = when('created_at') ?? when('placed_at');

    final timeline = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (cancelled)
        Text('Cancelled${when('cancelled_at') == null ? '' : ' ${when('cancelled_at')}'}',
            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))
      else
        for (var i = 0; i < _timeline.length; i++)
          Builder(builder: (context) {
            final (label, fields) = _timeline[i];
            final stamp = fields.map(when).whereType<String>().firstOrNull;
            final done = i <= at;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < at || (done && i == _timeline.length - 1)
                        ? AppColors.primary
                        : AppColors.card,
                    border: Border.all(
                        color: done ? AppColors.primary : AppColors.border, width: 2),
                  ),
                  child: i < at || (done && i == _timeline.length - 1)
                      ? const Icon(Icons.check, size: 11, color: AppColors.onPrimary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == at ? FontWeight.w600 : FontWeight.w500,
                            color: done ? AppColors.ink : AppColors.muted)),
                    if (stamp != null)
                      Text(stamp, style: portalMono(size: 12, color: AppColors.muted)),
                  ]),
                ),
              ]),
            );
          }),
    ]);

    final ticket = PortalTicket(
      orderNumber: number,
      status: status,
      large: true,
      caption: booked == null ? null : 'Booked $booked',
      body: timeline,
    );

    final items = PortalPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ITEMS', style: portalFieldLabel),
        const SizedBox(height: 8),
        for (final raw in o['items'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${(raw as Map)['item_title']} × ${raw['quantity']}',
                      style: const TextStyle(fontSize: 14, color: AppColors.ink)),
                  Text('${raw['service_type']}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ]),
              ),
              Text(money.format(raw['total_price'] ?? 0), style: portalMono(size: 14)),
            ]),
          ),
        const Divider(color: AppColors.border, height: 20),
        Row(children: [
          const Text('Total', style: AppTypography.sectionTitle),
          if ((o['due_amount'] as num? ?? 0) > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(4)),
              child: const Text('Pay on delivery',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9A5B00))),
            ),
          ],
          const Spacer(),
          Text(money.format(o['total_amount'] ?? 0),
              style: portalMono(size: 16, weight: FontWeight.w600)),
        ]),
      ]),
    );

    final address =
        '${o['address'] ?? ''}${'${o['pin_code'] ?? ''}'.isEmpty ? '' : ' - ${o['pin_code']}'}';
    final pickup = PortalPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('PICKUP & DELIVERY', style: portalFieldLabel),
        const SizedBox(height: 10),
        if (portalPickupText(o).isNotEmpty)
          Row(children: [
            const Icon(Icons.schedule, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(portalPickupText(o).replaceFirst('Pickup ', ''),
                  style: portalMono(size: 14)),
            ),
          ]),
        if (address.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.place_outlined, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
                child: Text(address, style: const TextStyle(fontSize: 14, color: AppColors.ink))),
          ]),
        ],
        const Divider(height: 24, color: AppColors.borderSubtle),
        Row(children: [
          QrImageView(data: number, size: 72, padding: EdgeInsets.zero),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Show this at the shop to find your order quickly.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
          ),
        ]),
      ]),
    );

    final help = Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go('/help/report?order=${Uri.encodeComponent(number)}'),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.support_agent_outlined, size: 20, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Need help with this order?',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                SizedBox(height: 2),
                Text('Missing item, damage, delay or billing',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ]),
            ),
            Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      ),
    );

    final placed = widget.justBooked
        ? [
            const Text('Pickup booked',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('${portal.shopName} has your booking. Follow it here as it moves.',
                style: const TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.muted)),
            const SizedBox(height: 16),
          ]
        : const <Widget>[];

    final placedActions = widget.justBooked
        ? [
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/orders'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Track in Orders'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go('/book'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Book another pickup'),
            ),
          ]
        : const <Widget>[];

    final wide = MediaQuery.sizeOf(context).width >= PortalShell.wide;
    return PortalShell(
      index: PortalSection.orders,
      maxWidth: 1120,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        if (!widget.justBooked) _backLink(context) else const SizedBox(height: 16),
        ...placed,
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ticket,
                const SizedBox(height: 16),
                items,
              ]),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 360,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                pickup,
                const SizedBox(height: 16),
                help,
                ...placedActions,
              ]),
            ),
          ])
        else ...[
          ticket,
          const SizedBox(height: 12),
          items,
          const SizedBox(height: 12),
          pickup,
          const SizedBox(height: 12),
          help,
          ...placedActions,
        ],
      ]),
    );
  }
}
