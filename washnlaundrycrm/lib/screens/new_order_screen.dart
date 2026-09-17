import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/garment_model.dart';
import '../models/order_model.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_shell.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/sidebar_navigation.dart';
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

  // No method picker in the real app's Checkout review either — just
  // whether payment was collected. Kept fixed at the backend's own default.
  final String _paymentMethod = 'CASH';
  // "Collect payment now" was removed from Checkout review at the user's
  // request — every order placed from here now starts unpaid, same as this
  // already-false default did for the common case.
  bool _submitting = false;

  /// Store Pickup by default — checkout used to hardcode this, so there was
  /// no way to bill a Home Pickup / Home Delivery / Online order without
  /// editing it afterward.
  String _deliveryType = DeliveryType.storePickup;

  /// Whether the cart has handed off to the Checkout review step (Fulfilment,
  /// Ready by, Notes) — a second screen the real app shows before actually
  /// placing the order, still under `/new-order`.
  bool _showCheckoutReview = false;
  DateTime? _readyBy;
  double _discountAmount = 0;
  late final TextEditingController _notesController;
  late final TextEditingController _discountController;

  /// Default the seed data already encodes (`seed_db.py`: ₹50 for
  /// HOME_DELIVERY and ONLINE) — a starting point, not a fixed charge.
  /// Editable in the Order Summary once a carried fulfilment type is picked,
  /// since the real fee varies by distance/order and shouldn't be hardcoded.
  static const _deliveryFee = 50.0;
  double _deliveryCharge = 0;
  late final TextEditingController _deliveryChargeController;

  bool get _isCarriedDelivery =>
      _deliveryType == DeliveryType.homeDelivery ||
      _deliveryType == DeliveryType.online;

  static const _slotStartHour = 9; // 9 AM
  static const _slotEndHour = 22; // 10 PM — last slot is 9–10 PM

  /// Shop Pickup is ready whenever it's actually done — the counter default
  /// is simply "now". Anything carried (Home Delivery / Pickup from Home)
  /// needs real lead time, so its default is the first still-selectable
  /// hourly slot today, or 9 AM tomorrow once today's slots have all passed.
  DateTime _readyByDefaultFor(String deliveryType) {
    final now = DateTime.now();
    if (deliveryType == DeliveryType.storePickup) return now;
    final today = _readySlotStarts(now).where((s) => !_isSlotDisabled(s));
    if (today.isNotEmpty) return today.first;
    return DateTime(now.year, now.month, now.day + 1, _slotStartHour);
  }

  /// The hourly slot start times a carried fulfilment type can pick between,
  /// 9 AM through 9 PM (each a 1-hour window ending by 10 PM), for whatever
  /// date [forDate] falls on — not off any shop-configured Pickup/Delivery
  /// slot list, so it still works for a shop that hasn't set any up.
  List<DateTime> _readySlotStarts(DateTime forDate) => [
        for (var h = _slotStartHour; h < _slotEndHour; h++)
          DateTime(forDate.year, forDate.month, forDate.day, h),
      ];

  /// A slot is only disabled relative to "right now" — on any day other than
  /// today every slot stays selectable, since lead time isn't an issue for a
  /// future date.
  bool _isSlotDisabled(DateTime slot) {
    final now = DateTime.now();
    return DateUtils.isSameDay(slot, now) && slot.hour < now.hour;
  }

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _discountController = TextEditingController(text: '0');
    _deliveryChargeController =
        TextEditingController(text: _deliveryFee.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _discountController.dispose();
    _deliveryChargeController.dispose();
    super.dispose();
  }

  static const _walkInName = 'Walk-in customer';
  static const _walkInPhone = '';

  String get _customerName => _customer?.name ?? _walkInName;
  String get _customerPhone => _customer?.phone ?? _walkInPhone;

  double _subtotalFor(List<GarmentItemModel> garments) {
    double sum = 0.0;
    for (final g in garments) {
      final qty = _cartQuantities[g.id] ?? 0;
      if (qty > 0) sum += g.price * qty;
    }
    return sum;
  }

  int get _totalItems => _cartQuantities.values.fold(0, (a, b) => a + b);

  List<OrderItemModel> _cartItems(List<GarmentItemModel> garments) {
    final items = <OrderItemModel>[];
    for (final g in garments) {
      final qty = _cartQuantities[g.id] ?? 0;
      if (qty == 0) continue;
      items.add(OrderItemModel(
        itemTitle: g.name,
        serviceType: g.categoryName,
        quantity: qty,
        unit: g.unit,
        unitPrice: g.price,
        totalPrice: g.price * qty,
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

    // A category's own `isActive` is a separate flag from each item's —
    // GarmentItemModel doesn't carry a reference to it, so it's looked up
    // here rather than on the item itself. Built from *inactive* names
    // rather than active ones: if categories haven't loaded yet (or a test
    // only seeds garments), this must default to "not excluded", not to
    // "every category is unrecognized, hide everything."
    final inactiveCategoryNames = provider.categories
        .where((c) => !c.isActive)
        .map((c) => c.name)
        .toSet();

    // Inactive items (or items whose whole category is inactive) stay
    // orderable if already in the cart (the cart reads off the full
    // `garments` list, not this one) — only the browsing grid hides them,
    // matching Services' Items list, which now always hides inactive items
    // too rather than offering a toggle to reveal them.
    final filteredItems = garments.where((item) {
      final matchesCategory =
          _selectedCategory.isEmpty || item.categoryName == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final categoryIsActive =
          !inactiveCategoryNames.contains(item.categoryName);
      return item.isActive &&
          categoryIsActive &&
          matchesCategory &&
          matchesSearch;
    }).toList();

    final subtotal = _subtotalFor(garments);

    // Header + (grid or checkout review) — the left/top region either beside
    // the cart panel (wide) or above it (narrow, see SidebarNavigation.contentWideBreakpoint below).
    // `narrow` shrink-wraps the item grid/review instead of scrolling on
    // their own, since narrow mode puts the whole screen in one outer
    // SingleChildScrollView rather than splitting the height with the cart
    // section — see that branch below for why a flex split doesn't work.
    Widget buildMain({required bool narrow}) {
      return Column(
        mainAxisSize: narrow ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Top Header Bar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              key: Key('newOrderHeader'),
              children: [
                Text(
                  'New Order',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),

          if (_showCheckoutReview)
            narrow
                ? _buildCheckoutReview()
                : Expanded(child: _buildCheckoutReview())
          else ...[
            // Search & Filter Row
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            color: Color(0xFF94A3B8), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: 'Search items or scan a tag...',
                              hintStyle: TextStyle(
                                  fontSize: 13, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
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
                          label: Text(label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      isSel ? FontWeight.bold : FontWeight.w500,
                                  color: isSel
                                      ? Colors.white
                                      : const Color(0xFF334155))),
                          selected: isSel,
                          selectedColor: const Color(0xFF1A4FD6),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color: isSel
                                  ? const Color(0xFF1A4FD6)
                                  : const Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          onSelected: (_) =>
                              setState(() => _selectedCategory = value),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Items Grid / Table
            narrow
                ? _buildItemGrid(provider, filteredItems,
                    narrow: true, shrinkWrap: true)
                : Expanded(
                    child: _buildItemGrid(provider, filteredItems,
                        narrow: false)),
          ],
        ],
      );
    }

    // Customer card + (cart list/footer or checkout summary) — the
    // right/bottom region. Below SidebarNavigation.contentWideBreakpoint this is boxed and stacked
    // under buildMain instead of beside it; `narrow` shrink-wraps its inner
    // lists for the same reason as buildMain above.
    Widget buildCart({required bool narrow}) {
      return Column(
        mainAxisSize: narrow ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cart Header Title
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                const Text('Current order',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$_totalItems',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A4FD6))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (!_showCheckoutReview) ...[
            // Customer Selection Box
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _customerCard(),
            ),

            // Cart Items List / Empty State
            narrow
                ? _cartItemsBody(garments, shrinkWrap: true)
                : Expanded(child: _cartItemsBody(garments)),

            // Cart Summary Footer & Checkout Button — just the totals at
            // this stage. Fulfilment/Payment/Notes/Discount live on the
            // Checkout review screen, matching the real app's two-step
            // flow instead of collecting everything up front.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF64748B))),
                      Text('${Money.symbol}${subtotal.toInt()}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A))),
                      Text('${Money.symbol}${subtotal.toInt()}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (subtotal == 0 || _submitting)
                          ? null
                          : () => setState(() {
                                _readyBy ??= _readyByDefaultFor(_deliveryType);
                                _showCheckoutReview = true;
                              }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A4FD6),
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Checkout • ${Money.symbol}${subtotal.toInt()}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            narrow
                ? _buildOrderSummary(provider, garments, subtotal,
                    shrinkWrap: true)
                : Expanded(
                    child: _buildOrderSummary(provider, garments, subtotal)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= SidebarNavigation.contentWideBreakpoint) {
              return Row(
                children: [
                  // Main Center View
                  Expanded(child: buildMain(narrow: false)),

                  // Right Cart Panel Sidebar (Width: 320)
                  Container(
                    width: 320,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: buildCart(narrow: false),
                  ),
                ],
              );
            }

            // Below SidebarNavigation.contentWideBreakpoint the 320px cart panel has nowhere to go
            // beside the grid, so it moves below it instead. Both sections'
            // own fixed chrome (headers, customer card, footer) already
            // comes close to using up a real phone's full height on its
            // own — measured against a real 360dp-wide/800dp-tall phone
            // (Pixel-class `wm density` 480, i.e. devicePixelRatio 3) — so a
            // fixed flex split between them always clips one side or the
            // other. Instead the whole thing is one scroll view, and each
            // section shrink-wraps its own inner list rather than trying to
            // fill a fixed share of the height.
            return SingleChildScrollView(
              child: Column(
                children: [
                  buildMain(narrow: true),
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: buildCart(narrow: true),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The pre-checkout cart's item list or its empty state. `shrinkWrap`
  /// sizes the list to its content instead of expecting a bounded parent —
  /// see the narrow-mode branch in [build] for why that's needed there.
  Widget _cartItemsBody(List<GarmentItemModel> garments,
      {bool shrinkWrap = false}) {
    if (_cartQuantities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 32, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            const Text('No items yet',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            const Text('Tap products to add them to the order',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }
    // Iterates garments (not _cartItems) so each row has the garment's own id
    // to mutate _cartQuantities directly — the +/- stepper and delete button
    // live here now, not on the item card/table (see _addToCartControl).
    final inCart = garments.where((g) => (_cartQuantities[g.id] ?? 0) > 0).toList();
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: inCart.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, idx) => _cartLineRow(inCart[idx]),
    );
  }

  Widget _cartLineRow(GarmentItemModel g) {
    final qty = _cartQuantities[g.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                Text('${Money.symbol}${g.price.toInt()} each',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove,
                      size: 14, color: Color(0xFF1A4FD6)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => setState(() {
                    if (qty > 1) {
                      _cartQuantities[g.id] = qty - 1;
                    } else {
                      _cartQuantities.remove(g.id);
                    }
                  }),
                ),
                SizedBox(
                  width: 20,
                  child: Text('$qty',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A4FD6))),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.add, size: 14, color: Color(0xFF1A4FD6)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () =>
                      setState(() => _cartQuantities[g.id] = qty + 1),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: Color(0xFFDC2626)),
            tooltip: 'Remove from order',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => setState(() => _cartQuantities.remove(g.id)),
          ),
        ],
      ),
    );
  }

  /// Shared between the cart-stage right rail and the Checkout review's main
  /// content — the real app moves this card from one to the other when
  /// Checkout is tapped, but the widget itself is identical either place.
  Widget _customerCard() {
    return Container(
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_customerName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis),
                Text(
                  _customer == null ? 'Tap to add a customer' : _customerPhone,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _pickCustomer,
            child: Text(
              _customer == null ? 'Add' : 'Change',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4FD6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelBox({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _fulfilmentCard(String type, String label) {
    final isSel = _deliveryType == type;
    final icon = type == DeliveryType.homeDelivery
        ? Icons.local_shipping_rounded
        : type == DeliveryType.homePickup
            ? Icons.home_rounded
            : Icons.store_rounded;
    return GestureDetector(
      onTap: () => setState(() {
        _deliveryType = type;
        final carried =
            type == DeliveryType.homeDelivery || type == DeliveryType.online;
        _deliveryCharge = carried ? _deliveryFee : 0;
        _deliveryChargeController.text = _deliveryCharge.toStringAsFixed(0);
        // Switching fulfilment type changes what "ready" even means (now, vs
        // needing lead time) — re-default Ready by rather than leaving
        // whatever the previous type had selected.
        _readyBy = _readyByDefaultFor(type);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color:
                    isSel ? const Color(0xFF1A4FD6) : const Color(0xFF64748B)),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSel
                        ? const Color(0xFF1A4FD6)
                        : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }

  /// The Checkout review — the real app's second step before an order is
  /// actually placed: Fulfilment, Ready by, and Notes.
  /// `_readyBy` is guaranteed non-null by the time this builds (the Checkout
  /// button sets a default before flipping `_showCheckoutReview`).
  Widget _buildCheckoutReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _showCheckoutReview = false),
            icon: const Icon(Icons.arrow_back_rounded,
                size: 16, color: Color(0xFF475569)),
            label: const Text('Back to items',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569))),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          ),
          const SizedBox(height: 4),
          const Text('Checkout',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 20),
          _customerCard(),
          const SizedBox(height: 16),
          _panelBox(
            title: 'FULFILMENT',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    DeliveryType.storePickup,
                    DeliveryType.homePickup,
                    DeliveryType.homeDelivery,
                  ]
                      .map((type) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _fulfilmentCard(
                                  type, DeliveryType.label(type)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    const Text('Ready by',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const Spacer(),
                    Flexible(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () async {
                          final today = DateUtils.dateOnly(DateTime.now());
                          final picked = await AppDatePicker.pickDate(
                            context: context,
                            initialDate: _readyBy!,
                            firstDate: today,
                            lastDate: today.add(const Duration(days: 60)),
                          );
                          if (picked != null) {
                            setState(() => _readyBy = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                _readyBy!.hour,
                                _readyBy!.minute));
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Text(
                            DateFormat('EEE, d MMM, yyyy').format(_readyBy!),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_deliveryType == DeliveryType.storePickup)
                  Row(
                    children: [
                      const SizedBox(width: 24),
                      const Icon(Icons.access_time_rounded,
                          size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text('Ready at ${DateFormat('h a').format(_readyBy!)}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _readySlotStarts(_readyBy!).map((slot) {
                      final isSel = _readyBy!.hour == slot.hour;
                      final disabled = _isSlotDisabled(slot);
                      final end = slot.add(const Duration(hours: 1));
                      final startMeridiem = DateFormat('a').format(slot);
                      final endMeridiem = DateFormat('a').format(end);
                      // Drop the repeated "AM"/"PM" when both ends of the
                      // slot share one, so each chip is short enough for
                      // several to fit per row even on a phone-width screen.
                      final label = startMeridiem == endMeridiem
                          ? '${DateFormat('h').format(slot)}–'
                              '${DateFormat('h').format(end)} $startMeridiem'
                          : '${DateFormat('h a').format(slot)}–'
                              '${DateFormat('h a').format(end)}';
                      return ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        label: Text(label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: disabled
                                    ? const Color(0xFFCBD5E1)
                                    : (isSel
                                        ? Colors.white
                                        : const Color(0xFF334155)))),
                        selected: isSel,
                        selectedColor: const Color(0xFF1A4FD6),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: disabled
                            ? null
                            : (_) => setState(() => _readyBy = DateTime(
                                _readyBy!.year,
                                _readyBy!.month,
                                _readyBy!.day,
                                slot.hour,
                                slot.minute)),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panelBox(
            title: 'ORDER NOTES',
            child: TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g., Ring bell twice',
                hintStyle:
                    const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// The right rail once Checkout has been tapped: items, Subtotal, an
  /// editable Discount, Total, and the actual submit button.
  Widget _buildOrderSummary(
      AppProvider provider, List<GarmentItemModel> garments, double subtotal,
      {bool shrinkWrap = false}) {
    final total = (subtotal + _deliveryCharge - _discountAmount)
        .clamp(0, double.infinity)
        .toDouble();

    Widget summaryLine(String label, double amount) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('${Money.symbol}${amount.toInt()}',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
            ],
          ),
        );

    final itemsList = ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: _cartItems(garments).map((item) {
        return ListTile(
          title: Text(item.itemTitle,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          subtitle: Text(
              '${item.quantity}x @ ${Money.symbol}${item.unitPrice.toInt()}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          trailing: Text('${Money.symbol}${item.totalPrice.toInt()}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
        );
      }).toList(),
    );

    return Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('Order Summary',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
        ),
        const Divider(height: 1),
        shrinkWrap ? itemsList : Expanded(child: itemsList),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              summaryLine('Subtotal', subtotal),
              if (_isCarriedDelivery) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF64748B))),
                      SizedBox(
                        width: 100,
                        height: 32,
                        child: TextField(
                          controller: _deliveryChargeController,
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            prefixText: '${Money.symbol} ',
                            prefixStyle: const TextStyle(
                                fontSize: 13, color: Color(0xFF64748B)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (v) => setState(
                              () => _deliveryCharge = double.tryParse(v) ?? 0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  SizedBox(
                    width: 100,
                    height: 32,
                    child: TextField(
                      controller: _discountController,
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        prefixText: '${Money.symbol} ',
                        prefixStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) => setState(
                          () => _discountAmount = double.tryParse(v) ?? 0),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  Text('${Money.symbol}${total.toInt()}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () => _checkout(provider, garments, subtotal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A4FD6),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Place order',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemGrid(AppProvider provider, List<GarmentItemModel> items,
      {required bool narrow, bool shrinkWrap = false}) {
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

    // Wide screens get the same table treatment as the Services screen's
    // Items tab — Photo/Item/Unit/Price/Add to Cart — since a 4-wide
    // card grid wastes most of the row scanning prices. Narrow/phone widths
    // keep the card grid: the table's fixed columns have no room below
    // SidebarNavigation.contentWideBreakpoint, same reasoning as Services.
    if (!narrow) return _buildItemsTable(items);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _gridColumnsFor(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            // 0.76 holds up down to 2 columns (a card is still narrow enough
            // there to need the height). At 1 column the card gets nearly
            // the full screen width, so the same ratio makes it needlessly
            // tall (~420dp+) relative to a phone's viewport — widen it.
            childAspectRatio: columns == 1 ? 1.3 : 0.76,
          ),
          itemCount: items.length,
          itemBuilder: (context, idx) => _itemCard(items[idx]),
        );
      },
    );
  }

  Widget _tableColHead(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
          color: Color(0xFF64748B),
        ),
      );

  Widget _buildItemsTable(List<GarmentItemModel> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        key: const Key('itemsTable'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _tableColHead('ITEM')),
                  Expanded(flex: 2, child: _tableColHead('UNIT')),
                  Expanded(flex: 2, child: _tableColHead('PRICE')),
                  const SizedBox(width: 150, child: Text('')),
                ],
              ),
            ),
            for (final item in items) _buildItemTableRow(item),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTableRow(GarmentItemModel item) {
    final qty = _cartQuantities[item.id] ?? 0;
    final art = _artFor(item.name);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        color: qty > 0 ? const Color(0xFFF8FAFF) : null,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: item.imageUrl.isEmpty
                  ? Container(
                      color: const Color(0xFFF8FAFC),
                      child: Icon(art.icon, size: 20, color: art.color),
                    )
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF8FAFC),
                        child: Icon(art.icon, size: 20, color: art.color),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(item.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A))),
          ),
          Expanded(
            flex: 2,
            child: Text(item.unitLabel,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            flex: 2,
            child: Text('${Money.symbol}${item.price.toInt()}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A4FD6))),
          ),
          SizedBox(
            width: 150,
            child: Align(
              alignment: Alignment.centerRight,
              child: _addToCartControl(item, width: 140),
            ),
          ),
        ],
      ),
    );
  }

  /// The grid's own available width, independent of whether the cart panel
  /// beside it (wide) or below it (narrow, see [SidebarNavigation.contentWideBreakpoint]) is what
  /// made that width small.
  static int _gridColumnsFor(double width) {
    if (width < 380) return 1;
    if (width < 620) return 2;
    if (width < 900) return 3;
    return 4;
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
            decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
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
    final art = _artFor(item.name);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: qty > 0 ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
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
                          errorBuilder: (_, __, ___) => Center(
                              child:
                                  Icon(art.icon, size: 48, color: art.color)),
                        ),
                      ),
                    )
                  else
                    Center(child: Icon(art.icon, size: 48, color: art.color)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Name & Price
          Text(item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          Row(
            children: [
              Flexible(
                child: Text('${Money.symbol}${item.price.toInt()}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A4FD6))),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(item.unitLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Add to List / Counter Button
          _addToCartControl(item),
        ],
      ),
    );
  }

  /// The "+ Add to Cart" button, shared by the item card (full width) and the
  /// wide-width items table's Add to Cart column (fixed width) — same widget
  /// either place, so behaviour can't drift between the two layouts.
  ///
  /// Once an item is in the cart this becomes a static "In Cart" indicator —
  /// quantity +/- and removal live only in the cart panel now (see
  /// _cartLineRow), not here, so there's exactly one place to change either.
  Widget _addToCartControl(GarmentItemModel item, {double? width}) {
    final qty = _cartQuantities[item.id] ?? 0;
    return SizedBox(
      width: width ?? double.infinity,
      child: qty == 0
          ? OutlinedButton(
              onPressed: () => setState(() => _cartQuantities[item.id] = 1),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('+ Add to Cart',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A4FD6))),
            )
          : Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 15, color: Color(0xFF1A4FD6)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('In Cart · $qty',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A4FD6))),
                  ),
                ],
              ),
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

    // Matches the backend's own formula (serializers.py: subtotal + delivery
    // - discount) so the payload and what the server computes agree.
    final total = (subtotal + _deliveryCharge - _discountAmount)
        .clamp(0, double.infinity)
        .toDouble();
    // "Collect payment now" was removed from Checkout review — every order
    // placed from here starts unpaid; payment is collected later.
    const paid = 0.0;
    final notes = _notesController.text.trim();

    final payload = <String, dynamic>{
      // `order_number` is deliberately absent: the serializer marks it
      // read-only and the backend allocates the shop-prefixed sequence.
      if (_customer != null) 'customer': _customer!.id,
      'customer_name': _customerName,
      'customer_phone': _customerPhone,
      'status': OrderStatus.placed,
      'payment_status': PaymentStatus.unpaid,
      'payment_method': _paymentMethod,
      'delivery_type': _deliveryType,
      'delivery_charge': _deliveryCharge,
      'source': 'WEB',
      'subtotal': subtotal,
      'discount_amount': _discountAmount,
      'total_amount': total,
      'paid_amount': paid,
      'due_amount': total - paid,
      if (notes.isNotEmpty) 'notes': notes,
      if (_readyBy != null) ...{
        'scheduled_date': DateFormat('yyyy-MM-dd').format(_readyBy!),
        'scheduled_time': DateFormat('HH:mm:ss').format(_readyBy!),
      },
      'items': items.map((i) => i.toJson()).toList(),
    };

    setState(() => _submitting = true);
    final created = await provider.createNewOrder(payload);
    if (!mounted) return;
    setState(() => _submitting = false);

    // The order did not save. Keep the cart and review exactly as they are
    // so the counter staff can retry, and say so — never show a success
    // screen for a failed order.
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

    final shop = provider.shop;
    setState(() {
      _cartQuantities.clear();
      _customer = null;
      _showCheckoutReview = false;
      _readyBy = null;
      _discountAmount = 0;
      _deliveryType = DeliveryType.storePickup;
      _deliveryCharge = 0;
      _notesController.clear();
      _discountController.text = '0';
      _deliveryChargeController.text = _deliveryFee.toStringAsFixed(0);
    });

    if (!mounted) return;
    // Read off the *saved* order, so the number and totals on it are the
    // ones actually in the database.
    showDialog(
      context: context,
      builder: (_) => _OrderPlacedDialog(order: created, shop: shop),
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
      'pant':
          _ItemArt(Icons.airline_seat_legroom_extra_rounded, Color(0xFFD97706)),
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

/// Search-and-pick over the customers already on file, a walk-in escape
/// hatch, or — matching the real app's own "Existing customer" / "New
/// customer" tabs — create a brand-new customer without leaving New Order.
class _CustomerPickerDialog extends StatefulWidget {
  final AppProvider provider;

  const _CustomerPickerDialog({required this.provider});

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  String _query = '';
  bool _showNewCustomerForm = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _areaController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _submitNewCustomer() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Name and phone are both required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.provider.addCustomer({
      'name': name,
      'phone': phone,
      'email': _emailController.text.trim(),
      'area': _areaController.text.trim(),
    });
    if (!mounted) return;
    if (ok) {
      // addCustomer inserts the new record at the front of the list.
      Navigator.pop(context, widget.provider.customers.first);
    } else {
      setState(() {
        _saving = false;
        _error = widget.provider.error ?? 'Could not add the customer.';
      });
    }
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  selected ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color:
                  selected ? const Color(0xFF1A4FD6) : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _newCustomerField(
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = widget.provider.customers.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    final size = MediaQuery.sizeOf(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: math.min(440.0, size.width - 48),
        height: math.min(520.0, size.height - 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  const Text('Bill to',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                      child: _tab('Existing customer', !_showNewCustomerForm,
                          () => setState(() => _showNewCustomerForm = false))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _tab('New customer', _showNewCustomerForm,
                          () => setState(() => _showNewCustomerForm = true))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_showNewCustomerForm) ...[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _newCustomerField(
                          'Full Name', _nameController, 'e.g. Ramesh Kumar'),
                      _newCustomerField(
                          'Phone Number', _phoneController, '+919876543210',
                          keyboard: TextInputType.phone),
                      _newCustomerField(
                          'Email', _emailController, 'name@example.com',
                          keyboard: TextInputType.emailAddress),
                      _newCustomerField('Area / Locality', _areaController,
                          'e.g. HBR Layout, Bengaluru'),
                      if (_error != null) ...[
                        const SizedBox(height: 4),
                        Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFDC2626))),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submitNewCustomer,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A4FD6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_saving ? 'Adding…' : 'Add Customer',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          size: 20, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          onChanged: (v) => setState(() => _query = v),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: 'Search by name or phone',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: matches.isEmpty
                    ? const Center(
                        child: Text('No matching customers',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8))),
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
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569)),
                              ),
                            ),
                            title: Text(c.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A))),
                            subtitle: Text(c.phone,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B))),
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
                    // Empty id is the "no customer on file" sentinel the
                    // caller maps back to a walk-in.
                    onPressed: () => Navigator.pop(
                      context,
                      const CustomerModel(id: '', name: '', phone: ''),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Bill to walk-in customer',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569))),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The real app's post-checkout confirmation — a compact summary and real
/// next actions, shown once the order is actually saved. Distinct from
/// [ReceiptDialog] (still reachable via "View Receipt"): that one is the
/// itemized, printable/WhatsApp-able bill; this one is just "did it work,
/// and what next."
class _OrderPlacedDialog extends StatelessWidget {
  final OrderModel order;
  final Map<String, dynamic>? shop;

  const _OrderPlacedDialog({required this.order, required this.shop});

  @override
  Widget build(BuildContext context) {
    final isPaid = order.dueAmount <= 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: math.min(380.0, MediaQuery.sizeOf(context).width - 48),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF16A34A), size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Order Placed!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Your order has been created successfully',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Order ID',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Text('#${order.orderNumber}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _summaryRow('Customer', order.customerName),
            _summaryRow('Items', '${order.items.length}'),
            _summaryRow('Order Type', DeliveryType.label(order.deliveryType)),
            _summaryRow(
              'Payment',
              isPaid
                  ? 'Paid'
                  : 'Balance Due: ${Money.symbol}${order.dueAmount.toInt()}',
              valueColor:
                  isPaid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
            if (order.scheduledDate != null)
              _summaryRow(
                'Ready by',
                DateFormat('MMM d, yyyy').format(order.scheduledDate!) +
                    (order.scheduledTime.isEmpty
                        ? ''
                        : ', ${TimeSlotModel.formatTime(order.scheduledTime)}'),
              ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                Text('${Money.symbol}${order.totalAmount.toInt()}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A4FD6))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Cart/review state was already reset before this dialog was
                // shown, so this just needs to close itself.
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.add_rounded,
                    size: 18, color: Colors.white),
                label: const Text('New Order',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4FD6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => ReceiptDialog(order: order, shop: shop),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: const Text('View Receipt',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/orders/${order.id}');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: const Text('Order Details',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
