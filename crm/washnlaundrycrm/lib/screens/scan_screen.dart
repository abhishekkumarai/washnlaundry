import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../utils/money.dart';
import '../widgets/app_shell.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/status_pill.dart';
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
  final TextEditingController _tagSearchController = TextEditingController();

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
    _tagSearchController.dispose();
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
      backgroundColor: const Color(0xFFF8F7F5),
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
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded,
                      size: 20, color: Color(0xFF182C4F)),
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
                              color: Color(0xFF141A24))),
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
            labelColor: const Color(0xFF182C4F),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF182C4F),
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
                  color: const Color(0xFFF1EFEA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
      borderRadius: BorderRadius.circular(8),
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
                                      ? const Color(0xFF141A24)
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
                                      ? const Color(0xFF141A24)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
      borderRadius: BorderRadius.circular(8),
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
                                      ? const Color(0xFF141A24)
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
                                      ? const Color(0xFF141A24)
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
                  border: Border.all(color: const Color(0xFFE4E0D8)),
                ),
                child: _selectedMode == 0
                    ? Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded,
                                size: 48, color: Color(0xFF182C4F)),
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
                              backgroundColor: const Color(0xFF182C4F),
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
                                      const BorderSide(color: Color(0xFFD9D5CB))),
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
                                backgroundColor: const Color(0xFF182C4F),
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

    if (selected != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TagGeneratorPanel(
              key: ValueKey(selected.id),
              order: selected,
              onChangeOrder: () => setState(() => _tagOrderId = null),
            ),
          ),
        ),
      );
    }

    return _ordersListForTags(provider);
  }

  Widget _ordersListForTags(AppProvider provider) {
    final query = _tagSearchQuery.trim().toLowerCase();
    final allOrders = provider.orders;
    final results = query.isEmpty
        ? allOrders
        : allOrders
            .where((o) =>
                o.orderNumber.toLowerCase().contains(query) ||
                o.customerName.toLowerCase().contains(query) ||
                o.customerPhone.toLowerCase().contains(query))
            .toList();

    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top-aligned search and header section
              _topSearchSection(allOrders.length, results.length),
              const SizedBox(height: 20),
              if (allOrders.isEmpty)
                _emptyAllOrdersView()
              else if (results.isEmpty)
                _emptySearchResultView(query)
              else if (isWide)
                _ordersTable(results)
              else
                _ordersCardList(results),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topSearchSection(int totalCount, int filteredCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick an order to generate tags for',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF141A24),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All orders are listed below. Click "Generate Tags" on any order to start the multi-step tag generator.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Text(
                '$filteredCount order${filteredCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF182C4F),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Search bar & Search button row aligned on top
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagSearchController,
                onChanged: (v) => setState(() => _tagSearchQuery = v),
                onSubmitted: (v) =>
                    setState(() => _tagSearchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by order number or customer...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _tagSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _tagSearchController.clear();
                            setState(() => _tagSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD9D5CB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE4E0D8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF182C4F), width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() =>
                    _tagSearchQuery = _tagSearchController.text.trim());
              },
              icon: const Icon(Icons.search_rounded,
                  size: 18, color: Colors.white),
              label: const Text(
                'Search',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF182C4F),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _emptyAllOrdersView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text('No orders found in the shop.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _emptySearchResultView(String query) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              'No order matches "$query".',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                _tagSearchController.clear();
                setState(() => _tagSearchQuery = '');
              },
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ordersTable(List<OrderModel> orders) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Table Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFFF8F7F5),
              child: const Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      'ORDER #',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'CUSTOMER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'GARMENTS & SERVICES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'AMOUNT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: Text(
                      'TAGS / ACTION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE4E0D8)),
            // Order Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1EFEA)),
              itemBuilder: (context, index) {
                final order = orders[index];
                final garmentCount =
                    order.items.fold<int>(0, (s, it) => s + it.quantity);
                final serviceSummary = order.items
                    .map((it) => it.serviceType.isNotEmpty
                        ? it.serviceType
                        : it.itemTitle)
                    .toSet()
                    .take(2)
                    .join(', ');

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _tagOrderId = order.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          // Column 1: Order #
                          SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${order.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF182C4F),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(order.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Column 2: Customer
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.customerName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF141A24),
                                  ),
                                ),
                                if (order.customerPhone.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    order.customerPhone,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Column 3: Garments & Services
                          Expanded(
                            flex: 3,
                            child: Text(
                              '$garmentCount item${garmentCount == 1 ? '' : 's'}'
                              '${serviceSummary.isNotEmpty ? ' · $serviceSummary' : ''}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          // Column 4: Amount & Payment
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Money.format(order.totalAmount),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF141A24),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: paymentColor(order.paymentStatus)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    order.paymentStatusLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: paymentColor(order.paymentStatus),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Column 5: Status
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: StatusPill(
                                status: order.status,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          // Column 6: Action Column with Generate Tags
                          SizedBox(
                            width: 160,
                            child: Align(
                              alignment: Alignment.center,
                              child: FilledButton.icon(
                                icon: const Icon(Icons.qr_code_2_rounded,
                                    size: 16),
                                label: const Text('Generate Tags'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF182C4F),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () =>
                                    setState(() => _tagOrderId = order.id),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _ordersCardList(List<OrderModel> orders) {
    return Column(
      children: [
        for (final order in orders)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E0D8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${order.orderNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF182C4F),
                      ),
                    ),
                    StatusPill(status: order.status, fontSize: 10.5),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF141A24),
                          ),
                        ),
                        if (order.customerPhone.isNotEmpty)
                          Text(
                            order.customerPhone,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Money.format(order.totalAmount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF141A24),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: paymentColor(order.paymentStatus)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            order.paymentStatusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: paymentColor(order.paymentStatus),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${order.items.fold<int>(0, (s, it) => s + it.quantity)} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                    label: const Text('Generate Tags'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF182C4F),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setState(() => _tagOrderId = order.id),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
