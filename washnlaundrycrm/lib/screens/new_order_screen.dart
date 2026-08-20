import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/garment_model.dart';
import '../models/order_model.dart';
import '../utils/navigation.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/panel_card.dart';
import '../utils/money.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  /// Empty means "All". Matches on [GarmentItemModel.categoryName].
  String _selectedCategory = '';
  String _searchQuery = '';

  /// Null until a customer is picked — the order then bills to a walk-in.
  CustomerModel? _customer;

  /// Keyed by [GarmentItemModel.id].
  final Map<String, int> _cartQuantities = {};
  final Map<String, bool> _expressToggles = {};

  String _paymentMethod = 'CASH';
  bool _markPaid = true;
  bool _submitting = false;

  /// Store Pickup by default — checkout used to hardcode this, so there was
  /// no way to bill a Home Pickup / Home Delivery / Online order without
  /// editing it afterward.
  String _deliveryType = DeliveryType.storePickup;

  /// Flat delivery fee for anything the shop has to carry, matching the rule
  /// the seed data already encodes (`seed_db.py`: ₹50 for HOME_DELIVERY and
  /// ONLINE, nothing for a pickup the customer makes themselves).
  static const _deliveryFee = 50.0;

  double get _deliveryCharge =>
      _deliveryType == DeliveryType.homeDelivery || _deliveryType == DeliveryType.online
          ? _deliveryFee
          : 0.0;

  static const _walkInName = 'Walk-in customer';
  static const _walkInPhone = '';

  String get _customerName => _customer?.name ?? _walkInName;
  String get _customerPhone => _customer?.phone ?? _walkInPhone;

  /// The express surcharge is shop policy, not app policy — it used to be a
  /// `const double _expressMultiplier = 1.5` at the top of this file, so no
  /// shop could charge anything else. The EXPRESS switch on a product card
  /// still only affects that card's lines.
  double get _expressMultiplier =>
      context.read<AppProvider>().expressMultiplier;

  double _priceFor(GarmentItemModel g) =>
      _expressToggles[g.id] == true ? g.price * _expressMultiplier : g.price;

  double _subtotalFor(List<GarmentItemModel> garments) {
    double sum = 0.0;
    for (final g in garments) {
      final qty = _cartQuantities[g.id] ?? 0;
      if (qty > 0) sum += _priceFor(g) * qty;
    }
    return sum;
  }

  int get _totalItems => _cartQuantities.values.fold(0, (a, b) => a + b);

  List<OrderItemModel> _cartItems(List<GarmentItemModel> garments) {
    final items = <OrderItemModel>[];
    for (final g in garments) {
      final qty = _cartQuantities[g.id] ?? 0;
      if (qty == 0) continue;
      final price = _priceFor(g);
      items.add(OrderItemModel(
        itemTitle: g.name,
        serviceType: g.categoryName,
        quantity: qty,
        unit: g.unit,
        unitPrice: price,
        totalPrice: price * qty,
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final garments = provider.garments;

    // Category order follows the Services catalogue; any category that only
    // exists on an item falls in behind it.
    final ordered = <String>[
      for (final c in provider.categories) c.name,
    ];
    final categoryNames = <String>{
      ...ordered.where((n) => garments.any((g) => g.categoryName == n)),
      ...garments.map((g) => g.categoryName),
    }.toList();

    final filteredItems = garments.where((item) {
      final matchesCategory =
          _selectedCategory.isEmpty || item.categoryName == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final subtotal = _subtotalFor(garments);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),

          // Main Center View
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF475569)),
                        onPressed: () => context.goSection(0),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'New Order',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF64748B)),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF1A4FD6),
                        child: Text(
                          initialsFor((provider.shop?['owner_name'] as String?) ??
                              (provider.shop?['name'] as String?)),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search & Filter Row
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText: 'Search items or scan a tag...',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Filter Pills Row
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categoryNames.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final label = idx == 0 ? 'All' : categoryNames[idx - 1];
                            final value = idx == 0 ? '' : categoryNames[idx - 1];
                            final isSel = value == _selectedCategory;
                            return ChoiceChip(
                              label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF334155))),
                              selected: isSel,
                              selectedColor: const Color(0xFF1A4FD6),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (_) => setState(() => _selectedCategory = value),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Items Grid
                Expanded(
                  child: _buildItemGrid(provider, filteredItems),
                ),
              ],
            ),
          ),

          // Right Cart Panel Sidebar (Width: 320)
          Container(
            width: 320,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cart Header Title
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Text('Current order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$_totalItems', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Customer Selection Box
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            _customerName.isEmpty ? 'W' : _customerName[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                              Text(
                                _customer == null ? 'Tap to add a customer' : _customerPhone,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _pickCustomer,
                          child: Text(
                            _customer == null ? 'Add' : 'Change',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Cart Items List / Empty State
                Expanded(
                  child: _cartQuantities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, size: 32, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 12),
                              const Text('No items yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const Text('Tap products to add them to the order', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: _cartItems(garments).map((item) {
                            return ListTile(
                              title: Text(item.itemTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              subtitle: Text('${item.quantity}x @ ${Money.symbol}${item.unitPrice.toInt()}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              trailing: Text('${Money.symbol}${item.totalPrice.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            );
                          }).toList(),
                        ),
                ),

                // Cart Summary Footer & Checkout Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      // Delivery — how the order leaves the shop. Checkout
                      // used to hardcode Store Pickup on every order, which
                      // also meant the ₹50 delivery fee could never be billed.
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Delivery', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: DeliveryType.labels.keys.map((type) {
                          final isSel = _deliveryType == type;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _deliveryType = type),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFFEEF2FF) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      DeliveryType.label(type),
                                      maxLines: 1,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Payment method — what the shop is collecting in, and
                      // whether they've been paid yet. Previously hardcoded to
                      // "paid by UPI" on every single order.
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Payment', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                      const SizedBox(height: 6),
                      // Equal thirds: the rail is only 280px inside its padding,
                      // so intrinsically-sized chips overflow it.
                      // The methods the backend accepts, not this screen's own
                      // three — Bank Transfer was offered on Expenses and
                      // Payroll but silently missing here.
                      Row(
                        children: provider.paymentMethods.map((choice) {
                          final method = choice.value;
                          final isSel = _paymentMethod == method;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _paymentMethod = method),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFFEEF2FF) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
                                  ),
                                  // The rail is only 280px inside its padding
                                  // and there are now four methods, so a long
                                  // label like "Bank Transfer" must shrink
                                  // rather than overflow.
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      choice.label,
                                      maxLines: 1,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('Paid in full', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          const Spacer(),
                          Switch(
                            value: _markPaid,
                            activeColor: const Color(0xFF1A4FD6),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) => setState(() => _markPaid = val),
                          ),
                        ],
                      ),
                      const Divider(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          Text('${Money.symbol}${subtotal.toInt()}', style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                        ],
                      ),
                      if (_deliveryCharge > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text('${Money.symbol}${_deliveryCharge.toInt()}', style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('${Money.symbol}${(subtotal + _deliveryCharge).toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (subtotal == 0 || _submitting)
                              ? null
                              : () => _checkout(provider, garments, subtotal),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A4FD6),
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Checkout • ${Money.symbol}${(subtotal + _deliveryCharge).toInt()}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemGrid(AppProvider provider, List<GarmentItemModel> items) {
    if (provider.isLoading && provider.garments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.hasError && provider.garments.isEmpty) {
      return _emptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load the catalogue',
        subtitle: provider.error ?? 'Something went wrong.',
        action: TextButton(
          onPressed: provider.refresh,
          child: const Text('Retry'),
        ),
      );
    }

    if (items.isEmpty) {
      return _emptyState(
        icon: Icons.search_off_rounded,
        title: 'No items here',
        subtitle: _searchQuery.isNotEmpty
            ? 'Nothing matches "$_searchQuery".'
            : 'This category has no active items yet.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.76,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) => _itemCard(items[idx]),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          SizedBox(
            width: 320,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }

  Widget _itemCard(GarmentItemModel item) {
    final qty = _cartQuantities[item.id] ?? 0;
    final isExpress = _expressToggles[item.id] ?? false;
    final art = _artFor(item.name);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qty > 0 ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garment Image / Placeholder Box
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Real product photography when the catalogue has it; the
                  // icon treatment is the fallback, not the only option.
                  // `_artFor` remains a stand-in keyed on the item name — it
                  // picks an icon, never a picture, so it cannot go stale the
                  // way the old Unsplash-by-name map did.
                  if (item.imageUrl.isNotEmpty)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Center(child: Icon(art.icon, size: 48, color: art.color)),
                        ),
                      ),
                    )
                  else
                    Center(child: Icon(art.icon, size: 48, color: art.color)),
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Text(
                      item.turnaroundLabel,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Name & Price
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Row(
            children: [
              Text('${Money.symbol}${_priceFor(item).toInt()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
              const SizedBox(width: 4),
              Text(item.unitLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 10),

          // Express Toggle Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFF59E0B)),
                    Text('EXPRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ],
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: isExpress,
                    activeColor: const Color(0xFF1A4FD6),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) => setState(() => _expressToggles[item.id] = val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Add to List / Counter Button
          qty == 0
              ? SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _cartQuantities[item.id] = 1),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('+ Add to List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                  ),
                )
              : Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16, color: Color(0xFF1A4FD6)),
                        onPressed: () => setState(() {
                          if (qty > 1) {
                            _cartQuantities[item.id] = qty - 1;
                          } else {
                            _cartQuantities.remove(item.id);
                          }
                        }),
                      ),
                      Text('$qty', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF1A4FD6)),
                        onPressed: () => setState(() => _cartQuantities[item.id] = qty + 1),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _pickCustomer() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final picked = await showDialog<CustomerModel?>(
      context: context,
      builder: (_) => _CustomerPickerDialog(provider: provider),
    );
    // A dismissed dialog returns null and must not clear the current pick;
    // "Bill to walk-in" returns the sentinel below.
    if (picked == null) return;
    setState(() => _customer = picked.id.isEmpty ? null : picked);
  }

  Future<void> _checkout(
    AppProvider provider,
    List<GarmentItemModel> garments,
    double subtotal,
  ) async {
    final items = _cartItems(garments);
    if (items.isEmpty) return;

    final anyExpress = _cartQuantities.keys.any((id) => _expressToggles[id] == true);
    final total = subtotal + _deliveryCharge;
    final paid = _markPaid ? total : 0.0;

    final payload = <String, dynamic>{
      // `order_number` is deliberately absent: the serializer marks it
      // read-only and the backend allocates the shop-prefixed sequence.
      if (_customer != null) 'customer': _customer!.id,
      'customer_name': _customerName,
      'customer_phone': _customerPhone,
      'status': OrderStatus.placed,
      'payment_status': _markPaid ? PaymentStatus.paid : PaymentStatus.unpaid,
      'payment_method': _paymentMethod,
      'delivery_type': _deliveryType,
      'delivery_charge': _deliveryCharge,
      'source': 'WEB',
      'subtotal': subtotal,
      'total_amount': total,
      'paid_amount': paid,
      'due_amount': total - paid,
      'express': anyExpress,
      'items': items.map((i) => i.toJson()).toList(),
    };

    setState(() => _submitting = true);
    final created = await provider.createNewOrder(payload);
    if (!mounted) return;
    setState(() => _submitting = false);

    // The order did not save. Keep the cart exactly as it is so the counter
    // staff can retry, and say so — never show a receipt for a failed order.
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text(
            'Could not save this order: ${provider.error ?? 'unknown error'}',
            style: const TextStyle(fontSize: 13),
          ),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _checkout(provider, garments, subtotal),
          ),
        ),
      );
      return;
    }

    setState(() {
      _cartQuantities.clear();
      _expressToggles.clear();
      _customer = null;
    });

    if (!mounted) return;
    // Render the receipt from the *saved* order, so the number and totals on
    // it are the ones actually in the database.
    showDialog(
      context: context,
      builder: (_) => ReceiptDialog(order: created, shop: provider.shop),
    );
  }

  /// Stand-in for the live app's product photography. Known garments get a
  /// hand-picked icon; anything else falls back to a stable pick derived from
  /// the name, so a given item always looks the same.
  static _ItemArt _artFor(String name) {
    const known = <String, _ItemArt>{
      'shirt': _ItemArt(Icons.dry_cleaning_rounded, Color(0xFF3B82F6)),
      't-shirt': _ItemArt(Icons.checkroom_rounded, Color(0xFFF97316)),
      'kurta': _ItemArt(Icons.strikethrough_s_rounded, Color(0xFF06B6D4)),
      'pant': _ItemArt(Icons.airline_seat_legroom_extra_rounded, Color(0xFFD97706)),
      'jeans': _ItemArt(Icons.checkroom_outlined, Color(0xFF2563EB)),
      'shorts': _ItemArt(Icons.dry_cleaning_outlined, Color(0xFF10B981)),
      'saree': _ItemArt(Icons.woman_rounded, Color(0xFFEC4899)),
      'blazer': _ItemArt(Icons.business_center_rounded, Color(0xFF64748B)),
      'curtain': _ItemArt(Icons.curtains_rounded, Color(0xFF8B5CF6)),
      'blanket': _ItemArt(Icons.bed_rounded, Color(0xFF0EA5E9)),
      'carpet': _ItemArt(Icons.texture_rounded, Color(0xFFA16207)),
      'shoe': _ItemArt(Icons.ice_skating_rounded, Color(0xFF14B8A6)),
    };

    final lower = name.toLowerCase();
    for (final entry in known.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    const fallbackIcons = [
      Icons.checkroom_rounded,
      Icons.dry_cleaning_rounded,
      Icons.local_laundry_service_rounded,
      Icons.woman_rounded,
      Icons.business_center_rounded,
    ];
    const fallbackColors = [
      Color(0xFF3B82F6),
      Color(0xFFF97316),
      Color(0xFF10B981),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return _ItemArt(
      fallbackIcons[hash % fallbackIcons.length],
      fallbackColors[hash % fallbackColors.length],
    );
  }
}

class _ItemArt {
  final IconData icon;
  final Color color;
  const _ItemArt(this.icon, this.color);
}

/// Search-and-pick over the customers already on file, with a walk-in escape
/// hatch. Creating a brand-new customer lives on the Customers screen; this
/// only attaches an existing one to the order.
class _CustomerPickerDialog extends StatefulWidget {
  final AppProvider provider;

  const _CustomerPickerDialog({required this.provider});

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = widget.provider.customers.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 440,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  const Text('Bill to', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name or phone',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: matches.isEmpty
                  ? const Center(
                      child: Text('No matching customers', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final c = matches[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFE2E8F0),
                            child: Text(
                              c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                          title: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          subtitle: Text(c.phone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  // Empty id is the "no customer on file" sentinel the caller
                  // maps back to a walk-in.
                  onPressed: () => Navigator.pop(
                    context,
                    const CustomerModel(id: '', name: '', phone: ''),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Bill to walk-in customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
