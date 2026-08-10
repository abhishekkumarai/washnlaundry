import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/status_pill.dart';

/// `/orders/:orderId` in the live app.
///
/// Captured 2026-08-10 from `#WA3P-00002`, a store-pickup order. Two things
/// that capture settled: the step bar is four stages, not five (the real app
/// collapses `Out for Delivery` into the Timeline), and its last two labels
/// change with the fulfilment type — see [OrderModel.stepLabels].
class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onBack;

  const OrderDetailScreen({super.key, required this.order, required this.onBack});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  /// The order as the server last returned it. Every mutation goes through the
  /// provider and replaces this — the old screen only ever called setState, so
  /// a status change looked like it worked and vanished on reload.
  late OrderModel _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  @override
  void didUpdateWidget(covariant OrderDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) _order = widget.order;
  }

  /// Prefer the provider's copy so a change made elsewhere is reflected here.
  ///
  /// Takes the provider rather than reading it off `context`: `build` wants
  /// `watch`, but a dialog callback must use `read`, and calling `watch`
  /// outside the widget tree throws.
  OrderModel _orderFrom(AppProvider provider) {
    final match = provider.orders.where((o) => o.id == _order.id);
    return match.isEmpty ? _order : match.first;
  }

  @override
  Widget build(BuildContext context) {
    final order = _orderFrom(context.watch<AppProvider>());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                _header(order),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleRow(order),
                        const SizedBox(height: 20),
                        _stepBar(order),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 980;
                            final left = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _itemsCard(order),
                                const SizedBox(height: 20),
                                _timelineCard(order),
                              ],
                            );
                            final right = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _customerCard(order),
                                const SizedBox(height: 20),
                                _fulfilmentCard(order),
                                const SizedBox(height: 20),
                                _paymentCard(order),
                              ],
                            );
                            if (stacked) {
                              return Column(children: [left, const SizedBox(height: 20), right]);
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: left),
                                const SizedBox(width: 20),
                                Expanded(flex: 2, child: right),
                              ],
                            );
                          },
                        ),
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

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(OrderModel order) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF1A4FD6)),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Orders / ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text('#${order.orderNumber}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Spacer(),
          _headerButton(
            'WhatsApp',
            Icons.chat_bubble_outline_rounded,
            const Color(0xFF10B981),
            () => _toast('WhatsApp receipt sent to ${order.customerName}.'),
          ),
          const SizedBox(width: 8),
          _headerButton('Edit', Icons.edit_outlined, const Color(0xFF475569), _showEditOrder),
          const SizedBox(width: 8),
          _headerButton('Print Receipt', Icons.print_outlined, const Color(0xFF475569),
              () => _toast('Sent to the printer.')),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: order.isCancelled ? null : _showUpdateStatus,
            icon: const Icon(Icons.autorenew_rounded, size: 16),
            label: const Text('Update Status'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _titleRow(OrderModel order) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text('#${order.orderNumber}',
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        StatusPill(status: order.status, fontSize: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(order.deliveryTypeLabel,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
        ),
        if (order.express)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('⚡ EXPRESS',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
          ),
        Text('Placed ${DateFormat('MMM d, h:mm a').format(order.createdAt)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ],
    );
  }

  // ── Step bar ───────────────────────────────────────────────────────────────

  Widget _stepBar(OrderModel order) {
    if (order.isCancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('This order was cancelled.',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
          ],
        ),
      );
    }

    final labels = order.stepLabels;
    final statuses = order.stepStatuses;
    final reached = order.stepIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: _panel,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 28),
                  color: i <= reached ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0),
                ),
              ),
            _step(
              index: i,
              label: labels[i],
              at: order.stageTimestamps[statuses[i]],
              done: i <= reached,
              current: i == reached,
            ),
          ],
        ],
      ),
    );
  }

  Widget _step({
    required int index,
    required String label,
    required DateTime? at,
    required bool done,
    required bool current,
  }) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: done ? const Color(0xFF1A4FD6) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: current ? Border.all(color: const Color(0xFFBFDBFE), width: 3) : null,
          ),
          child: done && !current
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Center(
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: done ? Colors.white : const Color(0xFF94A3B8))),
                ),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                fontWeight: done ? FontWeight.bold : FontWeight.normal,
                color: done ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(at == null ? '—' : DateFormat('h:mm a').format(at),
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      ],
    );
  }

  // ── Items ──────────────────────────────────────────────────────────────────

  Widget _itemsCard(OrderModel order) {
    // The live app groups lines under the service heading, uppercased.
    final groups = <String, List<OrderItemModel>>{};
    for (final item in order.items) {
      groups.putIfAbsent(item.serviceType.toUpperCase(), () => []).add(item);
    }

    return Container(
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Items',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${order.items.length}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                ),
              ],
            ),
          ),
          for (final entry in groups.entries) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF8FAFC),
              child: Text(entry.key,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: Color(0xFF64748B))),
            ),
            for (final item in entry.value) _itemRow(item, order.express),
          ],
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _totalRow('Subtotal', order.subtotal),
                // Only rendered when there is one — the live receipt has no
                // zero-value rows, and the old screen invented two.
                if (order.deliveryCharge > 0) ...[
                  const SizedBox(height: 8),
                  _totalRow('Delivery', order.deliveryCharge),
                ],
                if (order.discountAmount > 0) ...[
                  const SizedBox(height: 8),
                  _totalRow('Discount', -order.discountAmount),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('₹${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(OrderItemModel item, bool orderIsExpress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.dry_cleaning_rounded, size: 16, color: Color(0xFF1A4FD6)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(item.itemTitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A))),
                    ),
                    if (orderIsExpress) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('⚡ EXP',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(item.serviceType,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Text('${item.quantity} × ₹${item.unitPrice.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 16),
          SizedBox(
            width: 70,
            child: Text('₹${item.totalPrice.toStringAsFixed(0)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text('₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  // ── Timeline ───────────────────────────────────────────────────────────────

  Widget _timelineCard(OrderModel order) {
    final entries = order.timeline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Timeline',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Text('No timeline recorded for this order.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
          else
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A4FD6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i < entries.length - 1)
                          Container(width: 2, height: 26, color: const Color(0xFFE2E8F0)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entries[i].label,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A))),
                          Text(DateFormat('MMM d, h:mm a').format(entries[i].at),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          // Provenance sits on the first entry, as it does live.
                          if (i == 0)
                            Text('Created by ${order.createdByLabel}',
                                style:
                                    const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            const Text('NOTES',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            Text(order.notes!.trim(),
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          ],
        ],
      ),
    );
  }

  // ── Right rail ─────────────────────────────────────────────────────────────

  Widget _customerCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEEF2FF),
                child: Text(
                  order.customerName.isNotEmpty ? order.customerName[0].toUpperCase() : 'W',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.customerName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                    Text(
                      order.customerPhone.isEmpty ? 'No phone on file' : order.customerPhone,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Store pickup gets FULFILMENT / Expected Ready; anything delivered gets
  /// DELIVERY & ROUTE / Assigned Agent, as the live app does.
  Widget _fulfilmentCard(OrderModel order) {
    final collected = order.isCollectedInStore;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(collected ? 'FULFILMENT' : 'DELIVERY & ROUTE',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          _railRow(
            collected ? 'Expected Ready' : 'Expected Delivery',
            order.scheduledDate == null
                ? 'Not scheduled'
                : DateFormat('MMM d, yyyy').format(order.scheduledDate!),
          ),
          if (!collected) ...[
            const SizedBox(height: 10),
            _railRow('Assigned Agent', order.assignedAgentName ?? 'No agent assigned'),
          ],
        ],
      ),
    );
  }

  Widget _railRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(width: 12),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ),
      ],
    );
  }

  Widget _paymentCard(OrderModel order) {
    final isPaid = order.paymentStatus == PaymentStatus.paid;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(order.paymentStatusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPaid ? const Color(0xFF10B981) : const Color(0xFFDC2626))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _railRow('Total', '₹${order.totalAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _railRow('Amount Paid', '₹${order.paidAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _railRow('Balance Due', '₹${order.dueAmount.toStringAsFixed(0)}'),
          if (order.dueAmount > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _collectPayment(order),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Collect Payment',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _collectPayment(OrderModel order) async {
    final provider = context.read<AppProvider>();
    final ok = await provider.collectPayment(order.id, order.dueAmount);
    if (!mounted) return;
    _toast(ok
        ? 'Payment of ₹${order.dueAmount.toStringAsFixed(0)} collected.'
        : provider.error ?? 'Could not record the payment.');
  }

  /// The live Update Status dialog: the four stages as a radio list with the
  /// current one badged, Cancelled separated out as irreversible, and an
  /// optional note that travels with the change.
  Future<void> _showUpdateStatus() async {
    final provider = context.read<AppProvider>();
    final order = _orderFrom(provider);
    final noteController = TextEditingController();

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var selected = order.status;
        String? error;
        var saving = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Update Status',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Status',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    for (var i = 0; i < order.stepStatuses.length; i++)
                      _statusOption(
                        label: order.stepLabels[i],
                        value: order.stepStatuses[i],
                        index: i + 1,
                        selected: selected,
                        isCurrent: order.stepStatuses[i] == order.status,
                        onTap: () => setDialogState(() => selected = order.stepStatuses[i]),
                      ),
                    const SizedBox(height: 4),
                    _statusOption(
                      label: 'Cancelled',
                      value: OrderStatus.cancelled,
                      index: null,
                      selected: selected,
                      isCurrent: order.status == OrderStatus.cancelled,
                      destructive: true,
                      subtitle: 'This action cannot be undone',
                      onTap: () => setDialogState(() => selected = OrderStatus.cancelled),
                    ),
                    const SizedBox(height: 14),
                    const Text('Notes (optional)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add any notes about this status change...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
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
              OutlinedButton.icon(
                onPressed: saving ? null : () => _toast('Status shared on WhatsApp.'),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                label: const Text('Share via WhatsApp', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (selected == order.status) {
                          setDialogState(() => error = 'That is already the current status.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        final ok = await provider.updateOrderStatus(
                          order.id,
                          selected,
                          note: noteController.text,
                        );
                        if (!ctx.mounted) return;
                        if (ok) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            saving = false;
                            error = provider.error ?? 'Could not update the status.';
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4FD6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(saving ? 'Saving…' : 'Update Status',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (changed == true && mounted) _toast('Status updated.');
  }

  Widget _statusOption({
    required String label,
    required String value,
    required int? index,
    required String selected,
    required bool isCurrent,
    required VoidCallback onTap,
    bool destructive = false,
    String? subtitle,
  }) {
    final isSelected = selected == value;
    final accent = destructive ? const Color(0xFFDC2626) : const Color(0xFF1A4FD6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accent : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accent : const Color(0xFFF1F5F9),
                ),
                child: isSelected
                    ? const Icon(Icons.circle, size: 8, color: Colors.white)
                    : Center(
                        child: destructive
                            ? const Icon(Icons.close_rounded, size: 12, color: Color(0xFFDC2626))
                            : Text('$index',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF94A3B8))),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: destructive
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0F172A))),
                    if (subtitle != null)
                      Text(subtitle,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('CURRENT',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                          color: Color(0xFF475569))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The live `Edit` action's dialog was not captured, so this edits the order
  /// header fields our model actually carries. It is deliberately not a
  /// line-item editor — that would be inventing a screen we have never seen.
  Future<void> _showEditOrder() async {
    final provider = context.read<AppProvider>();
    final order = _orderFrom(provider);
    final nameController = TextEditingController(text: order.customerName);
    final phoneController = TextEditingController(text: order.customerPhone);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var deliveryType = order.deliveryType;
        var scheduled = order.scheduledDate;
        String? error;
        var saving = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit Order',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _editLabel('Customer Name'),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 13),
                      decoration: _editDecoration('Walk-in customer'),
                    ),
                    const SizedBox(height: 14),
                    _editLabel('Phone'),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 13),
                      decoration: _editDecoration('+919876543210'),
                    ),
                    const SizedBox(height: 14),
                    _editLabel('Fulfilment'),
                    DropdownButtonFormField<String>(
                      initialValue: deliveryType,
                      isDense: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: _editDecoration(''),
                      items: [
                        for (final t in DeliveryType.labels.keys)
                          DropdownMenuItem(value: t, child: Text(DeliveryType.label(t))),
                      ],
                      onChanged: (v) => setDialogState(() => deliveryType = v ?? deliveryType),
                    ),
                    const SizedBox(height: 14),
                    _editLabel(deliveryType == DeliveryType.storePickup ||
                            deliveryType == DeliveryType.homePickup
                        ? 'Expected Ready'
                        : 'Expected Delivery'),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: scheduled ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => scheduled = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 15),
                      label: Text(
                        scheduled == null
                            ? 'Not scheduled'
                            : DateFormat('MMM d, yyyy').format(scheduled!),
                        style: const TextStyle(fontSize: 13),
                      ),
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
                      Text(error!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
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
                        if (nameController.text.trim().isEmpty) {
                          setDialogState(() => error = 'Give the order a customer name.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        final updated = await provider.updateOrder(order.id, {
                          'customer_name': nameController.text.trim(),
                          'customer_phone': phoneController.text.trim(),
                          'delivery_type': deliveryType,
                          'scheduled_date': scheduled == null
                              ? null
                              : DateFormat('yyyy-MM-dd').format(scheduled!),
                        });
                        if (!ctx.mounted) return;
                        if (updated != null) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            saving = false;
                            error = provider.error ?? 'Could not save the order.';
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4FD6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(saving ? 'Saving…' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) _toast('Order updated.');
  }

  Widget _editLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
      );

  InputDecoration _editDecoration(String hint) => InputDecoration(
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
