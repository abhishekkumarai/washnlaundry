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
      ? DateFormat('h:mm a').format(DateTime(2000, 1, 1, int.parse(t.substring(0, 2)),
          int.parse(t.substring(3, 5))))
      : '';
  return 'Pickup ${DateFormat('EEE d MMM').format(d)}${time.isEmpty ? '' : ', $time'}';
}

/// The customer's own orders in this shop, newest first.
class PortalOrdersScreen extends StatefulWidget {
  const PortalOrdersScreen({super.key});

  @override
  State<PortalOrdersScreen> createState() => _PortalOrdersScreenState();
}

class _PortalOrdersScreenState extends State<PortalOrdersScreen> {
  List<Map<String, dynamic>>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final orders = await ApiService.fetchMyOrders();
      if (mounted) setState(() => _orders = orders);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final money = _money(context);
    Widget body;
    if (orders == null) {
      body = Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ]),
      );
    } else if (orders.isEmpty) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('No orders yet.', style: AppTypography.title),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go('/book'), child: const Text('Book a pickup')),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final o = orders[i];
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.go('/orders/${Uri.encodeComponent('${o['order_number']}')}'),
              child: PortalPanel(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('#${o['order_number']}', style: AppTypography.sectionTitle),
                      const SizedBox(height: 2),
                      Text(
                          [
                            '${(o['items'] as List).length} item${(o['items'] as List).length == 1 ? '' : 's'}',
                            _pickupText(o),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money.format(o['total_amount'] ?? 0), style: AppTypography.sectionTitle),
                    const SizedBox(height: 2),
                    _StatusTag(status: '${o['status']}'),
                  ]),
                ]),
              ),
            );
          },
        ),
      );
    }
    return PortalShell(index: 1, title: 'Your orders', child: body);
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final done = status == 'DELIVERED';
    final cancelled = status == 'CANCELLED';
    final color = cancelled ? AppColors.danger : done ? AppColors.success : AppColors.accent;
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
        child: Center(
            child: _error == null ? const CircularProgressIndicator() : Text(_error!)),
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
              Text('Cancelled ${o['cancelled_at'] != null ? fmt.format(DateTime.parse('${o['cancelled_at']}').toLocal()) : ''}',
                  style: const TextStyle(color: AppColors.danger))
            else
              for (final (status, field) in _timeline)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(o[field] != null ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                        color: o[field] != null ? AppColors.success : AppColors.border),
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
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Pickup', style: AppTypography.sectionTitle),
                const SizedBox(height: 6),
                Text(_pickupText(o).replaceFirst('Pickup ', '')),
                if ('${o['address'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${o['address']}${'${o['pin_code'] ?? ''}'.isEmpty ? '' : ' - ${o['pin_code']}'}',
                      style: const TextStyle(color: AppColors.muted)),
                ],
              ]),
            ),
            const SizedBox(width: 12),
            Column(children: [
              QrImageView(data: '${o['order_number']}', size: 96, padding: EdgeInsets.zero),
              const SizedBox(height: 4),
              const Text('Show at the shop', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/orders'), child: const Text('All orders')),
      ]),
    );
  }
}
