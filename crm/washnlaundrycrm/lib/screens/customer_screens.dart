import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/status_pill.dart';

/// The customer-only side of the app: a signed-in customer sees their own
/// orders, the rate card and a pickup form, nothing else. The backend scopes
/// every call here to the verified Google email (`/api/customer/*`), so this
/// is a view, not the access control; `router.dart` just keeps customers off
/// the staff routes.
const _brandBlue = Color(0xFF1A4FD6);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

/// Keys of the per-status timestamps in the `/customer/orders/` payload.
const _statusStamp = {
  OrderStatus.placed: 'placed_at',
  OrderStatus.processing: 'processing_at',
  OrderStatus.ironing: 'ironing_at',
  OrderStatus.ready: 'ready_at',
  OrderStatus.outForDelivery: 'out_for_delivery_at',
  OrderStatus.delivered: 'delivered_at',
};

/// Chrome shared by every customer screen: brand, three tabs, sign out.
class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.current, required this.child});

  /// 0 Orders, 1 Rate card, 2 Book a pickup.
  final int current;
  final Widget child;

  static const _tabs = [
    ('Orders', '/my/orders'),
    ('Rate card', '/my/rate-card'),
    ('Book a pickup', '/my/book'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    children: [
                      const Text('WashNLaundry',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _brandBlue)),
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (var i = 0; i < _tabs.length; i++)
                            TextButton(
                              onPressed: () => context.go(_tabs[i].$2),
                              child: Text(
                                _tabs[i].$1,
                                style: TextStyle(
                                  fontWeight: i == current
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: i == current ? _brandBlue : _muted,
                                ),
                              ),
                            ),
                          TextButton(
                            onPressed: auth.signOut,
                            child: const Text('Sign out',
                                style: TextStyle(color: _muted)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: _border),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads something once and renders loading / error (with retry) / data.
class _Loader<T> extends StatefulWidget {
  const _Loader({required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext, T) builder;

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  late Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final e = snap.error;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e is ApiException ? e.message : 'Something went wrong.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _future = widget.load()),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        return widget.builder(context, snap.data as T);
      },
    );
  }
}

String _date(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().me?['customer'] as Map?;
    return CustomerShell(
      current: 0,
      child: _Loader<List<Map<String, dynamic>>>(
        load: ApiService.fetchMyOrders,
        builder: (context, orders) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hi ${me?['name'] ?? 'there'}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 4),
            if (me != null)
              Text(
                '${me['total_orders']} orders'
                '${(me['due_amount'] ?? 0) > 0 ? ' · ${Money.grouped(me['due_amount'])} due' : ''}',
                style: const TextStyle(color: _muted),
              ),
            const SizedBox(height: 16),
            if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No orders yet.', style: TextStyle(color: _muted)),
              ),
            for (final o in orders) _OrderTile(order: o),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final due = (order['due_amount'] ?? 0) as num;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: () => context.go('/my/orders/${order['order_number']}'),
        title: Text('${order['order_number']}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(_date(order['created_at'])),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatusPill(status: '${order['status']}'),
            const SizedBox(height: 4),
            Text(
              due > 0
                  ? '${Money.grouped(due)} due'
                  : Money.grouped(order['total_amount'] as num?),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: due > 0 ? const Color(0xFFD97706) : _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class MyOrderDetailScreen extends StatelessWidget {
  const MyOrderDetailScreen({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      current: 0,
      child: _Loader<Map<String, dynamic>?>(
        // The list already carries items and timestamps for every order, and
        // an order that isn't this customer's simply isn't in it.
        load: () async => (await ApiService.fetchMyOrders())
            .where((o) => o['order_number'] == orderNumber)
            .firstOrNull,
        builder: (context, order) {
          if (order == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Order not found',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () => context.go('/my/orders'),
                    child: const Text('Back to orders'),
                  ),
                ],
              ),
            );
          }
          final status = '${order['status']}';
          final items = (order['items'] as List).cast<Map>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextButton.icon(
                onPressed: () => context.go('/my/orders'),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('All orders'),
              ),
              Row(
                children: [
                  Text('${order['order_number']}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _ink)),
                  const SizedBox(width: 12),
                  StatusPill(status: status),
                ],
              ),
              const SizedBox(height: 16),
              if (status == OrderStatus.cancelled)
                const Text('This order was cancelled.',
                    style: TextStyle(color: Color(0xFFDC2626)))
              else
                _Timeline(order: order, status: status),
              const SizedBox(height: 20),
              const Text('Items',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 8),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(
                              '${i['quantity']} × ${i['title']} (${i['service_type']})')),
                      Text(Money.grouped(i['total_price'] as num?)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              _amount('Total', order['total_amount']),
              _amount('Paid', order['paid_amount']),
              _amount('Due', order['due_amount'], bold: true),
            ],
          );
        },
      ),
    );
  }

  Widget _amount(String label, dynamic v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(Money.grouped(v as num?),
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          ],
        ),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order, required this.status});

  final Map<String, dynamic> order;
  final String status;

  @override
  Widget build(BuildContext context) {
    final reached = OrderStatus.progression.indexOf(status);
    return Column(
      children: [
        for (var i = 0; i < OrderStatus.progression.length; i++)
          Builder(builder: (context) {
            final step = OrderStatus.progression[i];
            final done = i <= reached;
            final stamp = order[_statusStamp[step]];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(done ? Icons.check_circle : Icons.circle_outlined,
                      size: 18, color: done ? _brandBlue : _border),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(OrderStatus.label(step),
                        style: TextStyle(
                            fontWeight:
                                i == reached ? FontWeight.w800 : FontWeight.w500,
                            color: done ? _ink : _muted)),
                  ),
                  if (stamp != null)
                    Text(_date(stamp),
                        style: const TextStyle(fontSize: 12, color: _muted)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class RateCardScreen extends StatelessWidget {
  const RateCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      current: 1,
      child: _Loader<List<Map<String, dynamic>>>(
        load: ApiService.fetchRateCard,
        builder: (context, cats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final c in cats) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Text('${c['name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: _ink)),
              ),
              for (final i in (c['items'] as List).cast<Map>())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text('${i['name']}')),
                      Text('${Money.grouped(i['price'] as num?)} ${i['unit'] ?? ''}',
                          style: const TextStyle(color: _muted)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class BookPickupScreen extends StatefulWidget {
  const BookPickupScreen({super.key});

  @override
  State<BookPickupScreen> createState() => _BookPickupScreenState();
}

class _BookPickupScreenState extends State<BookPickupScreen> {
  late final _name = TextEditingController(
      text: '${context.read<AuthProvider>().me?['customer']?['name'] ?? ''}');
  late final _phone = TextEditingController(
      text: '${context.read<AuthProvider>().me?['customer']?['phone'] ?? ''}');
  final _address = TextEditingController();
  final _service = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _ok = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ApiService.requestPickup(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        service: _service.text.trim(),
      );
      _ok = true;
      _message = 'Thanks! We will call you to confirm the pickup.';
    } on ApiException catch (e) {
      _ok = false;
      _message = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _field(String label, TextEditingController c, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: lines,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      current: 2,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Book a pickup',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 16),
          _field('Name', _name),
          _field('Phone', _phone),
          _field('Pickup address', _address, lines: 2),
          _field('What do you need? (e.g. Wash & iron)', _service),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_message!,
                  style: TextStyle(
                      color: _ok ? const Color(0xFF10B981) : const Color(0xFFDC2626))),
            ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Sending…' : 'Request pickup'),
          ),
        ],
      ),
    );
  }
}

/// A Google account that is neither staff nor a customer yet: collect a name
/// and phone. A new number creates the customer; a number the store already
/// has queues a link request for staff to approve.
class CustomerStartScreen extends StatefulWidget {
  const CustomerStartScreen({super.key});

  @override
  State<CustomerStartScreen> createState() => _CustomerStartScreenState();
}

class _CustomerStartScreenState extends State<CustomerStartScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _pending = auth.me?['pending_link'] == true;
    _name.text = auth.userName ?? '';
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res =
          await ApiService.customerSignup(_name.text.trim(), _phone.text.trim());
      if (res['pending'] == true) {
        _pending = true;
      } else {
        await auth.refreshRole();
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, ${auth.userEmail ?? ''}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 8),
                if (_pending) ...[
                  const Text(
                      'We have asked the store to link this email to your '
                      'existing account. Your orders will appear here once '
                      'it is approved.',
                      style: TextStyle(color: _muted)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: auth.refreshRole,
                    child: const Text('Check again'),
                  ),
                ] else ...[
                  const Text('Tell us who you are to see your orders.',
                      style: TextStyle(color: _muted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: OutlineInputBorder()),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFDC2626))),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Saving…' : 'Continue'),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                    onPressed: auth.signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
