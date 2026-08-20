import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../utils/navigation.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/status_pill.dart';
import 'customer_detail_screen.dart';
import '../utils/money.dart';

/// `/customers` in the live app — see LIVE_AUDIT.md "Customers".
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _searchQuery = '';
  CustomerModel? _selected;

  /// Most recent order date per customer, keyed by both id and phone so a
  /// counter order written without a customer FK still matches on phone.
  Map<String, DateTime> _lastOrderIndex(AppProvider provider) {
    final index = <String, DateTime>{};
    void put(String key, DateTime when) {
      if (key.isEmpty) return;
      final existing = index[key];
      if (existing == null || when.isAfter(existing)) index[key] = when;
    }

    for (final o in provider.orders) {
      put(o.customerId, o.createdAt);
      put(o.customerPhone, o.createdAt);
    }
    return index;
  }

  DateTime? _lastOrderFor(CustomerModel c, Map<String, DateTime> index) =>
      index[c.id] ?? index[c.phone];

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return CustomerDetailScreen(
        customer: _selected!,
        onBack: () => setState(() => _selected = null),
        onNewOrder: () {
          setState(() => _selected = null);
          context.goSection(1);
        },
      );
    }

    final provider = context.watch<AppProvider>();
    final customers = provider.customers;
    final lastOrders = _lastOrderIndex(provider);

    final q = _searchQuery.trim().toLowerCase();
    final filtered = customers.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                _header(context, customers.length),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kpiRow(customers),
                        const SizedBox(height: 20),
                        _table(filtered, lastOrders, provider),
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

  Widget _header(BuildContext context, int total) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Text('Customers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(width: 8),
          Text('$total Total', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const Spacer(),
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or email...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export is not available yet.')),
            ),
            icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF475569)),
            label: const Text('Export',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _showAddCustomer,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiRow(List<CustomerModel> customers) {
    final now = DateTime.now();
    final active = customers.where((c) => c.totalOrders > 0).length;
    final isNew = customers.where((c) {
      final at = c.createdAt;
      return at != null && at.year == now.year && at.month == now.month;
    }).length;

    final cards = [
      _kpi('Total', '${customers.length}', Icons.people_outline_rounded, const Color(0xFF1A4FD6)),
      _kpi('Active', '$active', Icons.verified_user_outlined, const Color(0xFF10B981)),
      _kpi('New', '$isNew', Icons.person_add_alt_1_outlined, const Color(0xFFA855F7)),
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

  Widget _kpi(String label, String value, IconData icon, Color color) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _table(
    List<CustomerModel> customers,
    Map<String, DateTime> lastOrders,
    AppProvider provider,
  ) {
    return Container(
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('All customers',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (customers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  provider.isLoading
                      ? 'Loading customers…'
                      : _searchQuery.trim().isEmpty
                          ? 'No customers yet. Add one to get started.'
                          : 'No customer matches "${_searchQuery.trim()}".',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: const Row(
                children: [
                  Expanded(flex: 4, child: _ColHead('CUSTOMER')),
                  Expanded(flex: 3, child: _ColHead('AREA')),
                  Expanded(flex: 2, child: _ColHead('ORDERS')),
                  Expanded(flex: 2, child: _ColHead('LIFETIME')),
                  Expanded(flex: 3, child: _ColHead('LAST ORDER')),
                  SizedBox(width: 32),
                ],
              ),
            ),
            for (final c in customers)
              _row(c, _lastOrderFor(c, lastOrders)),
          ],
        ],
      ),
    );
  }

  Widget _row(CustomerModel c, DateTime? lastOrder) {
    return InkWell(
      onTap: () => setState(() => _selected = c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(c.phone.isEmpty ? '—' : c.phone,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(c.area.trim().isEmpty ? '—' : c.area,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            ),
            Expanded(
              flex: 2,
              child: Text('${c.totalOrders}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            ),
            Expanded(
              flex: 2,
              child: Text('${Money.symbol}${c.totalSpent.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            Expanded(
              flex: 3,
              child: Text(lastOrder == null ? '—' : relativeTime(lastOrder),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            ),
            const SizedBox(
              width: 32,
              child: Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
      ),
    );
  }

  /// Takes no `BuildContext`: a parameter of that name would shadow
  /// `State.context`, and then the `mounted` check below would be guarding a
  /// different context than the one the snackbar uses.
  Future<void> _showAddCustomer() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final areaController = TextEditingController();
    final provider = context.read<AppProvider>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        bool saving = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Customer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('Full Name', nameController, 'e.g. Ramesh Kumar'),
                  _field('Phone Number', phoneController, '+919876543210',
                      keyboard: TextInputType.phone),
                  _field('Email', emailController, 'name@example.com',
                      keyboard: TextInputType.emailAddress),
                  _field('Area / Locality', areaController, 'e.g. HBR Layout, Bengaluru'),
                  if (error != null) ...[
                    const SizedBox(height: 6),
                    Text(error!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                  ],
                ],
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
                        final name = nameController.text.trim();
                        final phone = phoneController.text.trim();
                        if (name.isEmpty || phone.isEmpty) {
                          setDialogState(() => error = 'Name and phone are both required.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        final ok = await provider.addCustomer({
                          'name': name,
                          'phone': phone,
                          'email': emailController.text.trim(),
                          'area': areaController.text.trim(),
                        });
                        if (!ctx.mounted) return;
                        if (ok) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            saving = false;
                            error = provider.error ?? 'Could not add the customer.';
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4FD6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(saving ? 'Saving…' : 'Add Customer',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added.')),
      );
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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

  const _ColHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        color: Color(0xFF64748B),
      ),
    );
  }
}
