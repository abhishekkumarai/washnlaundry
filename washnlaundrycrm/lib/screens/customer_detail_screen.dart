import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/status_pill.dart';
import '../utils/money.dart';

/// `/customers/:customerId` in the live app — see LIVE_AUDIT.md "Customer detail".
///
/// Reached the same way [OrderDetailScreen] is: the list screen swaps its own
/// body rather than pushing a route, because there is no router. [onBack]
/// restores the list.
class CustomerDetailScreen extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onBack;

  /// Live app puts a `New Order` button in the detail header. The list screen
  /// owns navigation, so it supplies the jump.
  final VoidCallback? onNewOrder;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
    required this.onBack,
    this.onNewOrder,
  });

  /// Orders belonging to this customer.
  ///
  /// Matches on the FK when the order carries one, and falls back to the phone
  /// number for counter orders written before the customer record existed —
  /// those have `customerId == ''` but the same phone.
  List<OrderModel> _ordersFor(List<OrderModel> all) {
    return all.where((o) {
      if (o.customerId.isNotEmpty && customer.id.isNotEmpty) {
        return o.customerId == customer.id;
      }
      return customer.phone.isNotEmpty && o.customerPhone == customer.phone;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final orders = _ordersFor(provider.orders);

    // Money and counts come from the customer record, which the backend keeps
    // as running totals — using them keeps this screen agreeing with the list.
    // "Last order" has no stored column, so it is derived from the orders.
    final lastOrder = orders.isEmpty ? null : orders.first.createdAt;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _profileCard(),
                        const SizedBox(height: 20),
                        _kpiRow(lastOrder),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Below this the two panels stop fitting side by
                            // side and the tables start clipping.
                            final stacked = constraints.maxWidth < 900;
                            if (stacked) {
                              return Column(
                                children: [
                                  _orderHistory(orders),
                                  const SizedBox(height: 20),
                                  _contactCard(),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _orderHistory(orders)),
                                const SizedBox(width: 20),
                                Expanded(child: _contactCard()),
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

  Widget _header(BuildContext context) {
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
            onTap: onBack,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF1A4FD6)),
                  SizedBox(width: 6),
                  Text('Back to Customers',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(height: 20, width: 1, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 16),
          const Text('Customers / ',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Flexible(
            child: Text(
              customer.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
          const Spacer(),
          if (onNewOrder != null)
            FilledButton.icon(
              onPressed: onNewOrder,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Order'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A4FD6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    final since = customer.createdAt;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panel,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF1A4FD6),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(
                  customer.phone.isEmpty ? 'No phone on file' : customer.phone,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                if (since != null) ...[
                  const SizedBox(height: 2),
                  Text('Member since ${DateFormat('MMM yyyy').format(since)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ],
            ),
          ),
          if (customer.dueAmount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${Money.symbol}${customer.dueAmount.toStringAsFixed(0)} due',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpiRow(DateTime? lastOrder) {
    final cards = [
      _kpi('Lifetime value', '${Money.symbol}${customer.totalSpent.toStringAsFixed(0)}',
          Icons.account_balance_wallet_outlined, const Color(0xFF10B981)),
      _kpi('Total Orders', '${customer.totalOrders}',
          Icons.shopping_bag_outlined, const Color(0xFF1A4FD6)),
      _kpi('Avg order value', '${Money.symbol}${customer.avgOrderValue.toStringAsFixed(0)}',
          Icons.trending_up_rounded, const Color(0xFFA855F7)),
      _kpi('Last order', lastOrder == null ? '—' : relativeTime(lastOrder),
          Icons.access_time_rounded, const Color(0xFFF59E0B)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across needs ~880px; below that go two-by-two rather than
        // squeezing "₹12,340" into a column too narrow to render it.
        final perRow = constraints.maxWidth < 880 ? 2 : 4;
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

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _orderHistory(List<OrderModel> orders) {
    return Container(
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Order History',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${orders.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('No orders yet for this customer.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: _ColHead('ORDER')),
                  Expanded(flex: 3, child: _ColHead('DATE')),
                  Expanded(flex: 2, child: _ColHead('ITEMS')),
                  Expanded(flex: 3, child: _ColHead('STATUS')),
                  Expanded(flex: 2, child: _ColHead('TOTAL', align: TextAlign.right)),
                ],
              ),
            ),
            for (final o in orders)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('#${o.orderNumber}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(DateFormat('MMM d, yyyy').format(o.createdAt),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('${o.items.length}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusPill(status: o.status),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('${Money.symbol}${o.totalAmount.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _contactCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTACT & ADDRESSES',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          _contactRow(Icons.phone_outlined, 'Phone', customer.phone),
          _contactRow(Icons.mail_outline_rounded, 'Email', customer.email),
          _contactRow(Icons.location_on_outlined, 'Area', customer.area),
          _contactRow(Icons.home_outlined, 'Address', customer.address),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    final shown = value.trim().isEmpty ? 'Not provided' : value.trim();
    final empty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(
                  shown,
                  style: TextStyle(
                    fontSize: 13,
                    color: empty ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A),
                    fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const BoxDecoration _panel = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
);

class _ColHead extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _ColHead(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        color: Color(0xFF64748B),
      ),
    );
  }
}
