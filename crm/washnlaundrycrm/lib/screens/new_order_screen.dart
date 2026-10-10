import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/role_views.dart';
import '../models/garment_model.dart';
import '../models/order_model.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_shell.dart';
import '../widgets/fulfillment_type_selector.dart';
import '../widgets/order_media_picker.dart';
import '../widgets/sidebar_navigation.dart';
import '../utils/money.dart';

class NewOrderScreen extends StatefulWidget {
  final CustomerModel? initialCustomer;
  const NewOrderScreen({super.key, this.initialCustomer});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  /// Empty means "All". Matches on [GarmentItemModel.categoryName].
  String _selectedCategory = '';

  /// Phone width only: the cart panel is slid up over the item list. (Below
  /// the wide breakpoint the cart no longer sits at the very bottom of the
  /// page; a bar pinned to the bottom opens it.)
  bool _cartOpen = false;
  String _searchQuery = '';

  /// Photos/videos being attached to this order (review step).
  final OrderMediaController _media = OrderMediaController();

  /// Null until a customer is picked or passed via initialCustomer.
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

  /// Shop pickup's "Expected ready", or the Delivery date for the two
  /// carried types — saved as `scheduled_date`. [_deliveryWindow] is the
  /// chosen Delivery slot, saved as `scheduled_time`; Shop pickup has none.
  DateTime? _readyBy;
  _SlotWindow? _deliveryWindow;

  /// Home pickup only: the day and slot the agent collects from the customer.
  DateTime? _pickupDate;
  _SlotWindow? _pickupWindow;

  /// The live app's Discount field defaults to `%`, with a `₹` toggle.
  double _discountValue = 0;
  bool _discountIsPercent = true;
  late final TextEditingController _notesController;
  late final TextEditingController _discountController;
  late final TextEditingController _addressController;

  /// Default the seed data already encodes (`seed_db.py`: ₹50 for
  /// HOME_DELIVERY and ONLINE) — a starting point, not a fixed charge.
  /// Editable in the Order Summary once a carried fulfilment type is picked,
  /// since the real fee varies by distance/order and shouldn't be hardcoded.
  static const _deliveryFee = 50.0;
  double _deliveryCharge = 0;
  late final TextEditingController _deliveryChargeController;

  /// Both Home pickup and Home delivery carry the order one way or the
  /// other, and the live app bills its ₹50 Delivery line on either.
  bool get _isCarriedDelivery => DeliveryType.isCarried(_deliveryType);

  static const _slotStartHour = 9; // 9 AM
  static const _slotEndHour = 22; // 10 PM — last fallback slot is 9–10 PM

  static const _notesMaxLength = 200;

  /// The shop's own Pickup/Delivery slots (Settings), which is what the live
  /// app offers ("9:00 AM - 11:00 AM" …). A shop that hasn't configured any
  /// falls back to hourly windows, 9 AM to 10 PM, so a carried order can
  /// still be scheduled.
  List<_SlotWindow> _windowsFor(AppProvider provider, String kind) {
    final configured =
        (kind == TimeSlotModel.pickup ? provider.pickupSlots : provider.deliverySlots)
            .where((s) => s.isActive)
            .map(_SlotWindow.fromSlot)
            .whereType<_SlotWindow>()
            .toList();
    if (configured.isNotEmpty) return configured;
    return [
      for (var h = _slotStartHour; h < _slotEndHour; h++)
        _SlotWindow(h * 60, (h + 1) * 60),
    ];
  }

  /// A slot is only unavailable relative to "right now" — once it has ended
  /// today. On any later date every slot stays selectable.
  bool _isWindowPast(DateTime date, _SlotWindow w) {
    final now = DateTime.now();
    return DateUtils.isSameDay(date, now) &&
        w.endMinute <= now.hour * 60 + now.minute;
  }

  /// Picking an order type re-defaults its dates the way the live app does:
  /// pickup today, delivery / expected-ready tomorrow, no slot chosen yet.
  void _selectDeliveryType(String type) {
    final today = DateUtils.dateOnly(DateTime.now());
    _deliveryType = type;
    // No delivery charge for a signed-in customer (the backend zeroes it too).
    _deliveryCharge = _isCarriedDelivery && !_isSelfCustomer ? _deliveryFee : 0;
    _deliveryChargeController.text = _deliveryCharge.toStringAsFixed(0);
    _readyBy = today.add(const Duration(days: 1));
    _deliveryWindow = null;
    _pickupDate = type == DeliveryType.homePickup ? today : null;
    _pickupWindow = null;
    if (_isCarriedDelivery && _addressController.text.isEmpty) {
      _addressController.text = _customer?.address ?? '';
    }
  }

  double _discountFor(double subtotal) {
    final raw =
        _discountIsPercent ? subtotal * _discountValue / 100 : _discountValue;
    return raw.clamp(0, subtotal).toDouble();
  }

  @override
  void initState() {
    super.initState();
    // The submit button waits for uploads, so it has to repaint as they finish.
    _media.addListener(_onMediaChanged);
    _customer = widget.initialCustomer ?? _signedInCustomer();
    _deliveryType = _defaultDeliveryType;
    _notesController = TextEditingController();
    _discountController = TextEditingController();
    _addressController = TextEditingController();
    _deliveryChargeController =
        TextEditingController(text: _deliveryFee.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(covariant NewOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCustomer != oldWidget.initialCustomer) {
      _customer = widget.initialCustomer ?? _signedInCustomer();
    }
  }

  void _onMediaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _media.removeListener(_onMediaChanged);
    _media.dispose();
    _notesController.dispose();
    _discountController.dispose();
    _addressController.dispose();
    _deliveryChargeController.dispose();
    super.dispose();
  }

  /// A signed-in customer places orders for themselves: their own name and
  /// number instead of the walk-in placeholder, and no picker.
  CustomerModel? _signedInCustomer() {
    final auth = context.read<AuthProvider?>();
    if (auth?.role != 'customer') return null;
    final me = auth?.me?['customer'];
    if (me is! Map || '${me['id'] ?? ''}'.isEmpty) return null;
    return CustomerModel(
      id: '${me['id']}',
      name: '${me['name'] ?? ''}',
      phone: '${me['phone'] ?? ''}',
      email: '${me['email'] ?? ''}',
      address: '${me['address'] ?? ''}',
      area: '${me['area'] ?? ''}',
    );
  }

  /// A signed-in customer always books a Home pickup (the other two order
  /// types are hidden for them); everyone else starts on Shop pickup.
  String get _defaultDeliveryType => _isSelfCustomer
      ? DeliveryType.homePickup
      : DeliveryType.storePickup;

  bool get _isSelfCustomer =>
      context.signedInRoleOnce == 'customer' &&
      _customer != null;

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
    final allCategoryNames = <String>{
      ...ordered.where((n) => garments.any((g) => g.categoryName == n)),
      ...garments.map((g) => g.categoryName),
    };

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
    // Only categories you can actually order from get a chip: active, and with
    // at least one active item. (Services still lists the rest, shown as off.)
    final categoryNames = allCategoryNames
        .where((n) =>
            !inactiveCategoryNames.contains(n) &&
            garments.any((g) => g.categoryName == n && g.isActive))
        .toList();
    // A chip that has just disappeared (its category was switched off) must not
    // leave the grid filtered to nothing with no chip highlighted.
    final selectedCategory =
        categoryNames.contains(_selectedCategory) ? _selectedCategory : '';

    final filteredItems = garments.where((item) {
      final matchesCategory =
          selectedCategory.isEmpty || item.categoryName == selectedCategory;
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
              border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
            ),
            child: _showCheckoutReview
                ? _reviewHeader(showStepper: !narrow)
                : const Row(
                    key: Key('newOrderHeader'),
                    children: [
                      Text(
                        'New Order',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF141A24)),
                      ),
                    ],
                  ),
          ),

          if (_showCheckoutReview)
            narrow
                ? _buildCheckoutReview(provider)
                : Expanded(child: _buildCheckoutReview(provider))
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
                      color: const Color(0xFFF1EFEA),
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
                        final isSel = value == selectedCategory;
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
                          selectedColor: const Color(0xFF182C4F),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color: isSel
                                  ? const Color(0xFF182C4F)
                                  : const Color(0xFFE4E0D8)),
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
          // Cart Header Title — the review step's Order Summary carries its
          // own title instead, as on the live app.
          if (!_showCheckoutReview) ...[
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                const Text('Current order',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF141A24))),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$_totalItems',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF182C4F))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ],

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
                border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
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
                              fontSize: 13, color: Color(0xFF141A24))),
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
                              color: Color(0xFF141A24))),
                      Text('${Money.symbol}${subtotal.toInt()}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF141A24))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (subtotal == 0 || _submitting)
                          ? null
                          : () {
                              if (_customer == null) {
                                _showCustomerRequiredDialog();
                                return;
                              }
                              setState(() {
                                if (_readyBy == null) {
                                  _selectDeliveryType(_deliveryType);
                                }
                                _showCheckoutReview = true;
                                _cartOpen = false;
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF182C4F),
                        disabledBackgroundColor: const Color(0xFFD9D5CB),
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
      backgroundColor: const Color(0xFFF8F7F5),
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
                          Border(left: BorderSide(color: Color(0xFFE4E0D8))),
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
            // Browsing step on a phone: the items get the whole screen, a bar
            // pinned to the bottom shows what is in the cart, and tapping it
            // slides the cart up over the list. The review step (after
            // Checkout) keeps the stacked layout below, since its form and
            // Order Summary need the room.
            if (!_showCheckoutReview) {
              final hasItems = _cartQuantities.isNotEmpty;
              final panelOpen = _cartOpen;
              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: hasItems ? 88 : 0),
                    child: buildMain(narrow: true),
                  ),
                  if (hasItems && !panelOpen)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _cartBar(subtotal),
                    ),
                  if (panelOpen) ...[
                    Positioned.fill(
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: InkWell(
                          key: const Key('cartScrim'),
                          onTap: () => setState(() => _cartOpen = false),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: constraints.maxHeight * 0.88,
                      child: Material(
                        key: const Key('cartPanel'),
                        color: Colors.white,
                        elevation: 8,
                        clipBehavior: Clip.antiAlias,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
                        child: Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 4, 0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9D5CB),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Close',
                                    icon: const Icon(Icons.close_rounded,
                                        color: Color(0xFF64748B)),
                                    onPressed: () =>
                                        setState(() => _cartOpen = false),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: buildCart(narrow: false)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  buildMain(narrow: true),
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE4E0D8)),
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

  /// Phone-width bar pinned to the bottom while the cart has items: how many,
  /// the running total, and a tap target that slides the cart up.
  Widget _cartBar(double subtotal) {
    final n = _totalItems;
    return Material(
      key: const Key('cartBar'),
      color: const Color(0xFF182C4F),
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _cartOpen = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_outlined,
                  color: Color(0xFFFAF9F6), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                          text: '$n ${n == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                              color: Color(0xFFFAF9F6),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const TextSpan(
                          text: '  ·  ',
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 14)),
                      TextSpan(
                          text: '${Money.symbol}${subtotal.toInt()}',
                          style: const TextStyle(
                              color: Color(0xFFFAF9F6),
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Text('View order',
                  style: TextStyle(
                      color: Color(0xFFFAF9F6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFFFAF9F6), size: 20),
            ],
          ),
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
                color: Color(0xFFF1EFEA),
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
                    color: Color(0xFF141A24))),
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
                        color: Color(0xFF141A24))),
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
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove,
                      size: 14, color: Color(0xFF182C4F)),
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
                          color: Color(0xFF182C4F))),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.add, size: 14, color: Color(0xFF182C4F)),
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
        color: const Color(0xFFF8F7F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE4E0D8),
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
                        color: Color(0xFF141A24)),
                    overflow: TextOverflow.ellipsis),
                Text(
                  _customer == null ? 'Tap to add a customer' : _customerPhone,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          if (!_isSelfCustomer)
          TextButton(
            onPressed: _pickCustomer,
            child: Text(
              _customer == null ? 'Add' : 'Change',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF182C4F)),
            ),
          ),
        ],
      ),
    );
  }

  static const _ink = Color(0xFF141A24);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE4E0D8);
  static const _brand = Color(0xFF182C4F);

  /// Review step's header: back arrow, "Review order", and the live app's
  /// 1 Items ✓ — 2 Review — 3 Done stepper (dropped on narrow widths).
  Widget _reviewHeader({required bool showStepper}) {
    Widget step(String n, String label, {bool done = false, bool active = false}) {
      final fill = active ? _brand : Colors.white;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: active ? _brand : _line),
            ),
            child: Text(n,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : _muted)),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? _brand : _ink)),
          if (done) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF16A34A)),
          ],
        ],
      );
    }

    Widget connector() => Container(
        width: 28,
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: _line);

    return Row(
      key: const Key('newOrderHeader'),
      children: [
        IconButton(
          tooltip: 'Back to items',
          onPressed: () => setState(() => _showCheckoutReview = false),
          style: IconButton.styleFrom(
            side: const BorderSide(color: _line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 18, color: _ink),
        ),
        const SizedBox(width: 12),
        const Text('Review order',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
        if (showStepper)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                step('1', 'Items', done: true),
                connector(),
                step('2', 'Review', active: true),
                connector(),
                step('3', 'Done'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reviewCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
      );

  /// The live app's review customer block: avatar, name, phone, and an
  /// outlined Change button (Add, while still billing a walk-in).
  Widget _reviewCustomerCard() {
    return _reviewCard(
      title: 'Customer',
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFEFF6FF),
            child: Text(
              _customerName.isEmpty ? 'W' : _customerName[0].toUpperCase(),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _brand),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_customerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
                const SizedBox(height: 2),
                if (_customer != null)
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 13, color: _muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(_customerPhone,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontSize: 13, color: _muted)),
                      ),
                    ],
                  )
                else
                  const Text('Tap to add a customer',
                      style: TextStyle(fontSize: 13, color: _muted)),
              ],
            ),
          ),
          if (!_isSelfCustomer)
          OutlinedButton(
            onPressed: _pickCustomer,
            style: OutlinedButton.styleFrom(
              foregroundColor: _brand,
              side: const BorderSide(color: _line),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_customer == null ? 'Add' : 'Change',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// A bordered date row: calendar icon, small label over the date, chevron.
  Widget _dateField(
      String label, DateTime date, ValueChanged<DateTime> onPicked,
      {DateTime? minDate}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final today = DateUtils.dateOnly(DateTime.now());
        // `minDate` lets a field start later than today (Delivery date can't
        // be on or before the Pickup date).
        final first = minDate == null || minDate.isBefore(today) ? today : minDate;
        final picked = await AppDatePicker.pickDate(
          context: context,
          initialDate: date.isBefore(first) ? first : date,
          firstDate: first,
          lastDate: first.add(const Duration(days: 60)),
        );
        if (picked != null) setState(() => onPicked(DateUtils.dateOnly(picked)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: _muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _muted)),
                  Text(DateFormat('EEE d MMM').format(date),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _ink)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _slotPicker({
    required List<_SlotWindow> windows,
    required DateTime date,
    required _SlotWindow? selected,
    required ValueChanged<_SlotWindow> onSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: windows.map((w) {
        final isSel = selected == w;
        final disabled = _isWindowPast(date, w);
        return OutlinedButton(
          key: ValueKey('slot-${w.startMinute}'),
          onPressed: disabled ? null : () => setState(() => onSelected(w)),
          style: OutlinedButton.styleFrom(
            backgroundColor: isSel ? _brand : Colors.white,
            foregroundColor: isSel ? Colors.white : _ink,
            disabledForegroundColor: const Color(0xFFD9D5CB),
            side: BorderSide(color: isSel ? _brand : _line),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            minimumSize: const Size(0, 44),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(w.label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        );
      }).toList(),
    );
  }

  InputDecoration _boxDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brand)),
      );

  /// The Checkout review — the real app's second step before an order is
  /// actually placed: Customer, then Fulfillment type with whatever dates, slots
  /// and address that type needs, then Notes. `_readyBy` is guaranteed
  /// non-null by the time this builds (Checkout calls [_selectDeliveryType]
  /// before flipping `_showCheckoutReview`).
  Widget _buildCheckoutReview(AppProvider provider) {
    final isPickup = _deliveryType == DeliveryType.homePickup;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reviewCustomerCard(),
          const SizedBox(height: 16),
          _reviewCard(
            title: 'Fulfillment type',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FulfillmentTypeSelector(
                  value: _deliveryType,
                  only: _isSelfCustomer ? {DeliveryType.homePickup} : null,
                  onChanged: (t) => setState(() => _selectDeliveryType(t)),
                ),
                const SizedBox(height: 16),
                if (!_isCarriedDelivery)
                  _dateField('Expected ready', _readyBy!,
                      (d) => _readyBy = d)
                else ...[
                  if (isPickup) ...[
                    _dateField('Pickup date', _pickupDate!, (d) {
                      _pickupDate = d;
                      if (_pickupWindow != null &&
                          _isWindowPast(d, _pickupWindow!)) {
                        _pickupWindow = null;
                      }
                      // Delivery is always after pickup: push it out if the
                      // new pickup date caught up with it.
                      if (!_readyBy!.isAfter(d)) {
                        _readyBy = d.add(const Duration(days: 1));
                        _deliveryWindow = null;
                      }
                    }),
                    _fieldLabel('Pickup slot'),
                    _slotPicker(
                      windows: _windowsFor(provider, TimeSlotModel.pickup),
                      date: _pickupDate!,
                      selected: _pickupWindow,
                      onSelected: (w) => _pickupWindow = w,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _dateField('Delivery date', _readyBy!, (d) {
                    _readyBy = d;
                    if (_deliveryWindow != null &&
                        _isWindowPast(d, _deliveryWindow!)) {
                      _deliveryWindow = null;
                    }
                  },
                      minDate: isPickup
                          ? _pickupDate!.add(const Duration(days: 1))
                          : null),
                  _fieldLabel('Delivery slot'),
                  _slotPicker(
                    windows: _windowsFor(provider, TimeSlotModel.delivery),
                    date: _readyBy!,
                    selected: _deliveryWindow,
                    onSelected: (w) => _deliveryWindow = w,
                  ),
                  _fieldLabel(isPickup ? 'Pickup address' : 'Delivery address'),
                  TextField(
                    controller: _addressController,
                    minLines: 2,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14),
                    decoration: _boxDecoration('Enter full address'),
                  ),
                ],
                _fieldLabel('Notes for this order (optional)'),
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 4,
                  maxLength: _notesMaxLength,
                  style: const TextStyle(fontSize: 14),
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      Text('$currentLength / $maxLength',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8))),
                  decoration: _boxDecoration(
                      'Stain details, folding preference, gate code…'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _reviewCard(
            title: 'Photos & videos (optional)',
            child: OrderMediaPicker(controller: _media),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// The right rail once Checkout has been tapped: items grouped by service
  /// (as the live app does), Discount with a %/₹ toggle, Subtotal, Delivery,
  /// Total, Balance Due, and the actual submit button.
  Widget _buildOrderSummary(
      AppProvider provider, List<GarmentItemModel> garments, double subtotal,
      {bool shrinkWrap = false}) {
    final discount = _discountFor(subtotal);
    final total = (subtotal + _deliveryCharge - discount)
        .clamp(0, double.infinity)
        .toDouble();

    Widget summaryLine(String label, Widget value) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: _muted)),
              value,
            ],
          ),
        );

    // Group lines under their service, keeping first-seen order.
    final groups = <String, List<OrderItemModel>>{};
    for (final item in _cartItems(garments)) {
      groups.putIfAbsent(item.serviceType, () => []).add(item);
    }

    final itemsList = ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        for (final entry in groups.entries) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(entry.key,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155))),
                ),
                Text(
                    '${Money.symbol}${entry.value.fold<double>(0, (a, i) => a + i.totalPrice).toInt()}',
                    style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          for (final item in entry.value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Builder(builder: (_) {
                    final art = _artFor(item.itemTitle);
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: art.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(art.icon, size: 20, color: art.color),
                    );
                  }),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.itemTitle,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _ink)),
                        Text('× ${item.quantity}',
                            style:
                                const TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                  Text('${Money.symbol}${item.totalPrice.toInt()}',
                      style: const TextStyle(fontSize: 14, color: _ink)),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );

    Widget unitToggle(String label, bool percent) {
      final isSel = _discountIsPercent == percent;
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _discountIsPercent = percent),
        child: Container(
          width: 30,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSel ? _brand : Colors.transparent),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSel ? _brand : _muted)),
        ),
      );
    }

    return Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Order Summary',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
        ),
        shrinkWrap ? itemsList : Expanded(child: itemsList),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Column(
            children: [
              // A signed-in customer sees neither the Discount field nor the
              // Delivery line.
              if (!_isSelfCustomer) ...[
              Row(
                children: [
                  const Text('Discount',
                      style: TextStyle(fontSize: 14, color: _muted)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(fontSize: 14),
                        decoration: _boxDecoration('Enter discount').copyWith(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                unitToggle('%', true),
                                unitToggle(Money.symbol, false),
                              ],
                            ),
                          ),
                        ),
                        onChanged: (v) => setState(
                            () => _discountValue = double.tryParse(v) ?? 0),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              ],
              summaryLine(
                  'Subtotal',
                  Text('${Money.symbol}${subtotal.toInt()}',
                      style: const TextStyle(fontSize: 14, color: _ink))),
              if (_isCarriedDelivery && !_isSelfCustomer)
                summaryLine(
                  'Delivery',
                  SizedBox(
                    width: 90,
                    height: 32,
                    child: TextField(
                      controller: _deliveryChargeController,
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        prefixText: '${Money.symbol} ',
                        prefixStyle:
                            const TextStyle(fontSize: 14, color: _muted),
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
                ),
              if (discount > 0 && !_isSelfCustomer)
                summaryLine(
                    'Discount',
                    Text('−${Money.symbol}${discount.toInt()}',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF16A34A)))),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _ink)),
                  Text('${Money.symbol}${total.toInt()}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _ink)),
                ],
              ),
              const SizedBox(height: 12),
              // Every order placed here starts unpaid (see _checkout), so
              // the whole total is the balance due.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance Due',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB91C1C))),
                  Text('${Money.symbol}${total.toInt()}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting || _media.isUploading
                      ? null
                      : () => _checkout(provider, garments, subtotal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    disabledBackgroundColor: const Color(0xFFD9D5CB),
                    padding: const EdgeInsets.symmetric(vertical: 18),
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
                      : Text('Place order · ${Money.symbol}${total.toInt()}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
          padding: EdgeInsets.symmetric(
              horizontal: columns == 1 ? 14 : 20, vertical: 8),
          gridDelegate: columns == 1
              // Compact rows: a fixed row height instead of an aspect ratio.
              ? const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 72,
                )
              : SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.76,
                ),
          itemCount: items.length,
          itemBuilder: (context, idx) => columns == 1
              ? _itemRowCompact(items[idx])
              : _itemCard(items[idx]),
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
          border: Border.all(color: const Color(0xFFE4E0D8)),
        ),
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F7F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _tableColHead('ITEM')),
                  Expanded(flex: 2, child: _tableColHead('SERVICE TYPE')),
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
        border: const Border(top: BorderSide(color: Color(0xFFE4E0D8))),
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
                      color: const Color(0xFFF8F7F5),
                      child: Icon(art.icon, size: 20, color: art.color),
                    )
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF8F7F5),
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
                    color: Color(0xFF141A24))),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.categoryName.isEmpty ? 'General' : item.categoryName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
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
                    color: Color(0xFF182C4F))),
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
    // Phones get one column of compact rows (see _itemRowCompact), not big
    // cards: a card is ~270dp tall there and shows two or three items per
    // screen.
    if (width < 620) return 1;
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
                color: Color(0xFFF1EFEA), shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
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

  /// Phone-width item: photo, name + price, and the Add button on one short
  /// row. Same cart control and in-cart highlight as [_itemCard], at a
  /// fraction of the height.
  Widget _itemRowCompact(GarmentItemModel item) {
    final qty = _cartQuantities[item.id] ?? 0;
    final art = _artFor(item.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: qty > 0 ? const Color(0xFF182C4F) : const Color(0xFFE4E0D8)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: const Color(0xFFF8F7F5),
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(art.icon, size: 24, color: art.color),
                    )
                  : Icon(art.icon, size: 24, color: art.color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF141A24))),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('${Money.symbol}${item.price.toInt()}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF182C4F))),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(item.unitLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _addToCartControl(item, width: 112),
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
            color: qty > 0 ? const Color(0xFF182C4F) : const Color(0xFFE4E0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garment Image / Placeholder Box
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7F5),
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
                  color: Color(0xFF141A24))),
          Row(
            children: [
              Flexible(
                child: Text('${Money.symbol}${item.price.toInt()}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF182C4F))),
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
                side: const BorderSide(color: Color(0xFFE4E0D8)),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('+ Add to Cart',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF182C4F))),
            )
          : Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 15, color: Color(0xFF182C4F)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('In Cart · $qty',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF182C4F))),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showCustomerRequiredDialog() async {
    final shouldPick = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_search_rounded,
                    color: Color(0xFF182C4F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Required',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A24),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Action needed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'A customer is mandatory to create an order. Please select an existing customer or add a new customer to proceed.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogCtx, true),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text(
              'Select / Add Customer',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF182C4F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );

    if (shouldPick == true && mounted) {
      await _pickCustomer();
    }
  }

  Future<void> _pickCustomer() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final picked = await showDialog<CustomerModel?>(
      context: context,
      builder: (_) => _CustomerPickerDialog(provider: provider),
    );
    // A dismissed dialog returns null and must not clear the current pick;
    if (picked == null) return;
    if (picked.id.isNotEmpty) {
      setState(() => _customer = picked);
    }
  }

  Future<void> _checkout(
    AppProvider provider,
    List<GarmentItemModel> garments,
    double subtotal,
  ) async {
    final items = _cartItems(garments);
    if (items.isEmpty) return;

    if (_customer == null) {
      await _showCustomerRequiredDialog();
      return;
    }

    if (_media.isUploading || _media.hasFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _media.isUploading
                    ? 'Wait for the photos/videos to finish uploading'
                    : 'Retry or remove the photos/videos that failed',
                style: const TextStyle(fontSize: 13))),
      );
      return;
    }

    // A carried order is scheduled against real slots — the live app won't
    // place one without them, and neither do we.
    final missingSlot = _deliveryType == DeliveryType.homePickup &&
            _pickupWindow == null
        ? 'Pick a pickup slot'
        : _isCarriedDelivery && _deliveryWindow == null
            ? 'Pick a delivery slot'
            : null;
    if (missingSlot != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(missingSlot, style: const TextStyle(fontSize: 13))),
      );
      return;
    }
    // The delivery date must be after the pickup date (the pickers already
    // enforce it; this guards any other path to checkout).
    if (_deliveryType == DeliveryType.homePickup &&
        _pickupDate != null &&
        _readyBy != null &&
        !_readyBy!.isAfter(_pickupDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Delivery date must be after the pickup date',
                style: TextStyle(fontSize: 13))),
      );
      return;
    }

    // Matches the backend's own formula (serializers.py: subtotal + delivery
    // - discount) so the payload and what the server computes agree.
    final discount = _discountFor(subtotal);
    final total = (subtotal + _deliveryCharge - discount)
        .clamp(0, double.infinity)
        .toDouble();
    // "Collect payment now" was removed from Checkout review — every order
    // placed from here starts unpaid; payment is collected later.
    const paid = 0.0;
    final notes = _notesController.text.trim();
    final address = _addressController.text.trim();

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
      'discount_amount': discount,
      'total_amount': total,
      'paid_amount': paid,
      'due_amount': total - paid,
      if (notes.isNotEmpty) 'notes': notes,
      if (_media.readyIds.isNotEmpty) 'media_ids': _media.readyIds,
      if (_readyBy != null)
        'scheduled_date': DateFormat('yyyy-MM-dd').format(_readyBy!),
      if (_isCarriedDelivery && _deliveryWindow != null)
        'scheduled_time': _deliveryWindow!.apiStart,
      if (_deliveryType == DeliveryType.homePickup) ...{
        'pickup_date': DateFormat('yyyy-MM-dd').format(_pickupDate!),
        'pickup_time': _pickupWindow!.apiStart,
      },
      if (_isCarriedDelivery && address.isNotEmpty) 'address': address,
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

    setState(() {
      _cartQuantities.clear();
      _customer = _signedInCustomer();
      _showCheckoutReview = false;
      _readyBy = null;
      _deliveryWindow = null;
      _pickupDate = null;
      _pickupWindow = null;
      _discountValue = 0;
      _discountIsPercent = true;
      _deliveryType = _defaultDeliveryType;
      _deliveryCharge = 0;
      _notesController.clear();
      _media.clear();
      _addressController.clear();
      _discountController.clear();
      _deliveryChargeController.text = _deliveryFee.toStringAsFixed(0);
    });

    if (!mounted) return;
    // Go straight to the new order's details page instead of a popup.
    context.go('/orders/${created.id.isNotEmpty ? created.id : created.orderNumber}');
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
      'curtain': _ItemArt(Icons.curtains_rounded, Color(0xFF2563EB)),
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
      Color(0xFF2563EB),
      Color(0xFF06B6D4),
    ];
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return _ItemArt(
      fallbackIcons[hash % fallbackIcons.length],
      fallbackColors[hash % fallbackColors.length],
    );
  }
}

/// One bookable window on the review step, in minutes since midnight —
/// either a shop-configured [TimeSlotModel] or an hourly fallback.
class _SlotWindow {
  final int startMinute;
  final int endMinute;
  const _SlotWindow(this.startMinute, this.endMinute);

  static _SlotWindow? fromSlot(TimeSlotModel slot) {
    int? minutes(String t) {
      final parts = t.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      return (h == null || m == null) ? null : h * 60 + m;
    }

    final start = minutes(slot.startTime);
    final end = minutes(slot.endTime);
    return (start == null || end == null) ? null : _SlotWindow(start, end);
  }

  static String _hhmm(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  /// "HH:MM:SS", for a Django `TimeField`.
  String get apiStart => '${_hhmm(startMinute)}:00';

  /// "9:00 AM - 11:00 AM", as the live app labels its slot buttons.
  String get label => '${TimeSlotModel.formatTime(_hhmm(startMinute))} - '
      '${TimeSlotModel.formatTime(_hhmm(endMinute))}';

  @override
  bool operator ==(Object other) =>
      other is _SlotWindow &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);
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
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error =
          'Mobile number must be exactly 10 digits starting with 6-9 (no ISD / country code or leading 0).');
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
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  selected ? const Color(0xFF182C4F) : const Color(0xFFE4E0D8)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color:
                  selected ? const Color(0xFF182C4F) : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _newCustomerField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
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
            inputFormatters: inputFormatters,
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
                          color: Color(0xFF141A24))),
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
                        'Phone Number (10 digits only, no ISD code)',
                        _phoneController,
                        '9876543210',
                        keyboard: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
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
                      backgroundColor: const Color(0xFF182C4F),
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
                    border: Border.all(color: const Color(0xFFD9D5CB)),
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
                              backgroundColor: const Color(0xFFE4E0D8),
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
                                    color: Color(0xFF141A24))),
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
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showNewCustomerForm = true),
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('+ Add New Customer',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF182C4F))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF182C4F)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
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


