import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/tag_generator_panel.dart';

/// `/scan` — one sidebar destination for both "scan a tag" and "generate a
/// tag", as two tabs rather than two separate nav items. Generate Tags used
/// to be its own route (`/orders/:id/tags`, reachable only from the New
/// Order confirmation dialog); merged in here at the user's explicit
/// request for "a separate section in the left nav for generating [tags]
/// and [the] scanner" — one section, not two.
///
/// [initialOrderId] preselects an order straight into the Generate Tags tab
/// — how the New Order confirmation's "Print Tags" button reaches this now,
/// via `/scan?order=<id>` instead of pushing a dialog or a second route.
class ScanScreen extends StatefulWidget {
  final String? initialOrderId;

  const ScanScreen({super.key, this.initialOrderId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _selectedMode = 0; // 0: Camera, 1: Manual
  final TextEditingController _orderIdController = TextEditingController();

  /// Set when a lookup found nothing, so the screen can say so.
  String? _notFoundQuery;

  String? _tagOrderId;
  String _tagSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tagOrderId = widget.initialOrderId;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialOrderId != null ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orderIdController.dispose();
    super.dispose();
  }

  void _handleSearchOrder(AppProvider provider) {
    final query = _orderIdController.text.trim();
    if (query.isEmpty) return;

    // No `orElse` fallback: this used to return `orders.first` when nothing
    // matched, so a mistyped order number silently opened another customer's
    // receipt. A miss must read as a miss.
    final matches = provider.orders.where((o) =>
        o.orderNumber.toLowerCase() == query.toLowerCase() ||
        o.id.toLowerCase() == query.toLowerCase());

    if (matches.isEmpty) {
      setState(() => _notFoundQuery = query);
      return;
    }

    setState(() => _notFoundQuery = null);
    showDialog(
      context: context,
      builder: (_) => ReceiptDialog(order: matches.first, shop: provider.shop),
    );
  }

  /// A sample order number in this shop's own format, for the input hint.
  String _orderNumberExample(AppProvider provider) {
    final prefix = (provider.shop?['order_prefix'] as String?)?.trim();
    if (prefix != null && prefix.isNotEmpty) return '$prefix-00001';
    // Before the shop loads, show a real order number if we have one.
    return provider.orders.isNotEmpty
        ? provider.orders.first.orderNumber
        : 'WASH-00001';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(
        body: Column(
          children: [
            _header(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _scanTab(provider),
                  _generateTagsTab(provider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded,
                      size: 20, color: Color(0xFF1A4FD6)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scan & Tags',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A))),
                      Text('Look up an order, or generate its garment tags',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF1A4FD6),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF1A4FD6),
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Scan'),
              Tab(text: 'Generate Tags'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanTab(AppProvider provider) {
    return Center(
      child: ConstrainedBox(
        // Was a hard `SizedBox(width: 520)` — wider than every phone width,
        // guaranteed overflow. A max-width constraint lets it shrink instead
        // of forcing 520px.
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Segmented Mode Control (Camera / Manual)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMode = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedMode == 0
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedMode == 0
                                ? [
                                    BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2))
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  size: 16,
                                  color: _selectedMode == 0
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(
                                'Camera',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _selectedMode == 0
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedMode == 0
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMode = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedMode == 1
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedMode == 1
                                ? [
                                    BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2))
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.keyboard_outlined,
                                  size: 16,
                                  color: _selectedMode == 1
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(
                                'Manual',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _selectedMode == 1
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedMode == 1
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Scanner Box Container
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: _selectedMode == 0
                    ? Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded,
                                size: 48, color: Color(0xFF1A4FD6)),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Camera scanning isn't available yet. Use Manual to look up an order number.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 24),
                          // Disabled rather than live: this button used to
                          // open the *first* order's receipt with no camera
                          // involved.
                          ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Open scanner',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A4FD6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The example follows the shop's own prefix — the
                          // backend derives it from the shop name
                          // (`WASH-00001`), so the old hardcoded "LB-1001"
                          // matched nothing a user would ever type.
                          Text(
                            'Order ID (e.g. ${_orderNumberExample(provider)})',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _orderIdController,
                            onSubmitted: (_) => _handleSearchOrder(provider),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'Enter order number...',
                              hintStyle: const TextStyle(
                                  fontSize: 13, color: Color(0xFF94A3B8)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFCBD5E1))),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleSearchOrder(provider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A4FD6),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Search',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ),
                          if (_notFoundQuery != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                'No order found for "$_notFoundQuery".',
                                style: const TextStyle(
                                    fontSize: 12.5, color: Color(0xFFB91C1C)),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Scans a garment/basket tag or accepts a typed order ID, then opens the order.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _generateTagsTab(AppProvider provider) {
    OrderModel? selected;
    if (_tagOrderId != null) {
      for (final o in provider.orders) {
        if (o.id == _tagOrderId) {
          selected = o;
          break;
        }
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: selected == null
              ? _orderPicker(provider)
              : TagGeneratorPanel(
                  key: ValueKey(selected.id),
                  order: selected,
                  onChangeOrder: () => setState(() => _tagOrderId = null),
                ),
        ),
      ),
    );
  }

  Widget _orderPicker(AppProvider provider) {
    final query = _tagSearchQuery.trim().toLowerCase();
    final results = query.isEmpty
        ? const <OrderModel>[]
        : provider.orders
            .where((o) =>
                o.orderNumber.toLowerCase().contains(query) ||
                o.customerName.toLowerCase().contains(query))
            .take(10)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pick an order to generate tags for',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _tagSearchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search by order number or customer...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        if (query.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Start typing an order number or customer name.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
          )
        else if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No order matches "$query".',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < results.length; i++)
                  Container(
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : const Border(
                              top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        title: Text('#${results[i].orderNumber}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(results[i].customerName,
                            style: const TextStyle(fontSize: 12)),
                        trailing: Text('${results[i].items.length} item'
                            '${results[i].items.length == 1 ? '' : 's'}'),
                        onTap: () =>
                            setState(() => _tagOrderId = results[i].id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
