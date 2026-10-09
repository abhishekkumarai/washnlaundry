import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/garment_model.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../utils/money.dart';

class AppProvider extends ChangeNotifier {
  static const Map<int, String> routePaths = {
    0: '/dashboard',
    1: '/new-order',
    2: '/orders',
    3: '/customers',
    4: '/services',
    5: '/staff',
    6: '/attendance',
    7: '/payroll',
    8: '/expenses',
    9: '/reports',
    11: '/scan',
    13: '/settings',
    15: '/credits',
    16: '/chat',
  };

  static int navIndexForPath(String path) {
    final clean = path
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'^/+'), '')
        .split('?')
        .first;
    switch (clean) {
      case 'new-order':
      case 'new_order':
      case 'neworder':
      case 'create-order':
        return 1;
      case 'orders':
      case 'order':
        return 2;
      case 'customers':
      case 'customer':
        return 3;
      case 'services':
      case 'service':
      case 'items':
        return 4;
      case 'staff':
      case 'team':
      case 'employees':
        return 5;
      case 'attendance':
        return 6;
      case 'payroll':
        return 7;
      case 'expenses':
      case 'expense':
        return 8;
      case 'credits':
      case 'credit':
        return 15;
      case 'reports':
      case 'report':
        return 9;
      case 'scan':
      case 'qr':
        return 11;
      case 'settings':
      case 'shop-settings':
        return 13;
      case 'chat':
      case 'assistant':
      case 'support':
        return 16;
      case 'dashboard':
      case '':
      default:
        return 0;
    }
  }

  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  List<OrderModel> _orders = [];
  List<OrderModel> get orders => _orders;

  List<GarmentItemModel> _garments = [];
  List<GarmentItemModel> get garments => _garments;

  List<GarmentCategoryModel> _categories = [];
  List<GarmentCategoryModel> get categories => _categories;

  List<CustomerModel> _customers = [];
  List<CustomerModel> get customers => _customers;

  List<StaffModel> _staff = [];
  List<StaffModel> get staff => _staff;

  List<ExpenseModel> _expenses = [];
  List<ExpenseModel> get expenses => _expenses;

  List<CreditModel> _credits = [];
  List<CreditModel> get credits => _credits;

  List<CreditCategoryModel> _creditCategories = [];

  /// Every credit category, active or not, in display order — what Settings →
  /// Credit categories manages.
  List<CreditCategoryModel> get creditCategories => _creditCategories;

  /// What a new credit may be filed under.
  List<CreditCategoryModel> get activeCreditCategories =>
      _creditCategories.where((c) => c.isActive).toList();

  List<AttendanceModel> _attendance = [];
  List<AttendanceModel> get attendance => _attendance;

  /// True while a single day's register is being fetched. Separate from
  /// [isLoading], which covers the whole-shop load — stepping the Attendance
  /// date picker should not blank every other screen.
  bool _attendanceLoading = false;
  bool get attendanceLoading => _attendanceLoading;

  /// Failures from the day-scoped attendance calls, kept out of [error] on
  /// purpose. [error] means "this shop failed to load" and blanks a screen;
  /// a failed single-day fetch or save should surface inline while leaving the
  /// roster on screen.
  String? _attendanceError;
  String? get attendanceError => _attendanceError;

  /// Payroll is month-scoped, so it is not part of the whole-shop load — it is
  /// fetched when the screen opens and again whenever the month changes.
  PayrollSummaryModel? _payroll;
  PayrollSummaryModel? get payroll => _payroll;

  bool _payrollLoading = false;
  bool get payrollLoading => _payrollLoading;

  String? _payrollError;
  String? get payrollError => _payrollError;

  /// Reports are range-scoped, so like payroll they are fetched on demand
  /// rather than as part of the whole-shop load.
  ReportsModel? _reports;
  ReportsModel? get reports => _reports;

  bool _reportsLoading = false;
  bool get reportsLoading => _reportsLoading;

  String? _reportsError;
  String? get reportsError => _reportsError;

  List<ServiceAreaModel> _serviceAreas = [];
  List<ServiceAreaModel> get serviceAreas => _serviceAreas;

  List<TimeSlotModel> _pickupSlots = [];
  List<TimeSlotModel> get pickupSlots => _pickupSlots;

  List<TimeSlotModel> _deliverySlots = [];
  List<TimeSlotModel> get deliverySlots => _deliverySlots;

  Map<String, dynamic> _stats = {};
  Map<String, dynamic> get stats => _stats;

  Map<String, dynamic>? _shop;
  Map<String, dynamic>? get shop => _shop;

  String? _activeTenantId;
  String? get activeTenantId => _activeTenantId;

  List<Map<String, dynamic>> _availableShops = [];
  List<Map<String, dynamic>> get availableShops => _availableShops;

  void setAvailableShops(List<Map<String, dynamic>> shops) {
    _availableShops = shops;
    notifyListeners();
  }

  void setActiveTenant(String? tenantId) {
    _activeTenantId = tenantId;
    if (tenantId != null) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('active_tenant_id', tenantId);
      });
    }
    notifyListeners();
  }

  Future<void> switchShop(String tenantSlugOrId) async {
    _activeTenantId = tenantSlugOrId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_tenant_id', tenantSlugOrId);
    notifyListeners();
    await loadDataFromBackend();
  }

  /// Single writer for [Money]'s statics — call this wherever `_shop` is set.
  void _applyShopFormatting() {
    Money.configure(
      symbol: _shop?['currency_symbol'] as String?,
      locale: _shop?['locale'] as String?,
    );
  }

  MetaModel _meta = const MetaModel();
  MetaModel get meta => _meta;

  // ── Shop-driven settings ───────────────────────────────────────────────────
  //
  // Each of these replaces a hardcoded Dart constant. The fallback is the
  // constant it replaced, so the app still behaves before the shop loads —
  // but the shop is now the authority.

  double get expressMultiplier =>
      (_shop?['express_multiplier'] as num?)?.toDouble() ?? 1.5;

  double get defaultMonthlyWage =>
      (_shop?['default_monthly_wage'] as num?)?.toDouble() ?? 18000.0;

  String get defaultStaffRole =>
      (_shop?['default_staff_role'] as String?)?.trim().isNotEmpty == true
          ? _shop!['default_staff_role'] as String
          : 'Washer';

  String get currencySymbol =>
      (_shop?['currency_symbol'] as String?)?.trim().isNotEmpty == true
          ? _shop!['currency_symbol'] as String
          : '₹';

  String get locale => (_shop?['locale'] as String?)?.trim().isNotEmpty == true
      ? _shop!['locale'] as String
      : 'en_IN';

  /// Payment methods as the backend defines them. Falls back to the four the
  /// model declares so a failed `/meta/` fetch cannot empty every dropdown.
  List<ChoiceModel> get paymentMethods => _meta.paymentMethods.isNotEmpty
      ? _meta.paymentMethods
      : const [
          ChoiceModel(value: 'CASH', label: 'Cash'),
          ChoiceModel(value: 'UPI', label: 'UPI'),
          ChoiceModel(value: 'CARD', label: 'Card'),
          ChoiceModel(value: 'BANK_TRANSFER', label: 'Bank Transfer'),
        ];

  List<ChoiceModel> get expenseCategories => _meta.expenseCategories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Non-null when the last load failed. Screens should render an error state
  /// with a retry rather than showing an empty list as if the shop were idle.
  String? _error;
  String? get error => _error;
  bool get hasError => _error != null;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  /// Set [autoLoad] to false to build a provider without hitting the network —
  /// used by tests, which seed state directly via [seedForTest].
  // `initialPath` used to seed `_currentNavIndex` from `Uri.base.path` here —
  // go_router now owns parsing the URL (see lib/router.dart), and each
  // GoRoute's builder calls setNavIndex on the way in, so a second reader of
  // the same URL here would just get overwritten on first frame.
  AppProvider({bool autoLoad = true}) {
    if (autoLoad) loadDataFromBackend();
  }

  @visibleForTesting
  void seedForTest({
    List<OrderModel>? orders,
    List<GarmentItemModel>? garments,
    List<GarmentCategoryModel>? categories,
    List<CustomerModel>? customers,
    List<StaffModel>? staff,
    List<ExpenseModel>? expenses,
    List<CreditModel>? credits,
    List<CreditCategoryModel>? creditCategories,
    List<AttendanceModel>? attendance,
    PayrollSummaryModel? payroll,
    ReportsModel? reports,
    List<ServiceAreaModel>? serviceAreas,
    List<TimeSlotModel>? pickupSlots,
    List<TimeSlotModel>? deliverySlots,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? shop,
    MetaModel? meta,
  }) {
    if (orders != null) _orders = orders;
    if (garments != null) _garments = garments;
    if (categories != null) _categories = categories;
    if (customers != null) _customers = customers;
    if (staff != null) _staff = staff;
    if (expenses != null) _expenses = expenses;
    if (credits != null) _credits = credits;
    if (creditCategories != null) _creditCategories = creditCategories;
    if (attendance != null) _attendance = attendance;
    if (payroll != null) _payroll = payroll;
    if (reports != null) _reports = reports;
    if (serviceAreas != null) _serviceAreas = serviceAreas;
    if (pickupSlots != null) _pickupSlots = pickupSlots;
    if (deliverySlots != null) _deliverySlots = deliverySlots;
    if (stats != null) _stats = stats;
    if (shop != null) {
      _shop = shop;
      _applyShopFormatting();
    }
    if (meta != null) _meta = meta;
    notifyListeners();
  }

  /// User's manual sidebar preference. Ignored (forced collapsed) below the
  /// layout breakpoint — see [SidebarNavigation].
  bool _sidebarCollapsed = false;
  bool get sidebarCollapsed => _sidebarCollapsed;

  void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
    notifyListeners();
  }

  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<OrderModel> get filteredOrders {
    if (_searchQuery.trim().isEmpty) return _orders;
    final q = _searchQuery.toLowerCase();
    return _orders
        .where((o) =>
            o.customerName.toLowerCase().contains(q) ||
            o.orderNumber.toLowerCase().contains(q) ||
            o.customerPhone.contains(q))
        .toList();
  }

  /// Orders matching a filter chip, a date range and a search term — the three
  /// controls on the Orders screen, applied together.
  List<OrderModel> ordersFor({
    String filter = 'ALL',
    OrderDateRange range = OrderDateRange.allTime,
    String search = '',
  }) {
    final query = search.trim().toLowerCase();
    return ordersForFilter(filter).where((o) {
      if (!range.contains(o.createdAt)) return false;
      if (query.isEmpty) return true;
      return o.orderNumber.toLowerCase().contains(query) ||
          o.customerName.toLowerCase().contains(query) ||
          o.customerPhone.contains(query) ||
          o.items.any((i) => i.itemTitle.toLowerCase().contains(query));
    }).toList();
  }

  /// Orders matching one of the Orders-screen filter chips. `OVERDUE`,
  /// `SCHEDULED`, `UNPAID` and `PARTIAL` are derived, not stored statuses.
  List<OrderModel> ordersForFilter(String filter) {
    switch (filter.toUpperCase()) {
      case 'ALL':
        return _orders;
      case 'OVERDUE':
        return _orders.where((o) => o.isOverdue).toList();
      case 'SCHEDULED':
        final today = DateTime.now();
        return _orders
            .where((o) =>
                o.scheduledDate != null &&
                o.scheduledDate!.isAfter(today) &&
                o.status != OrderStatus.delivered &&
                o.status != OrderStatus.cancelled)
            .toList();
      case 'UNPAID':
        return _orders
            .where((o) => o.paymentStatus == PaymentStatus.unpaid)
            .toList();
      case 'PARTIAL':
        return _orders
            .where((o) => o.paymentStatus == PaymentStatus.partial)
            .toList();
      default:
        return _orders.where((o) => o.status == filter.toUpperCase()).toList();
    }
  }

  // ── Dashboard counters ─────────────────────────────────────────────────────
  //
  // These come from `/api/dashboard/stats/`, which scopes them properly — the
  // server knows what "today" means and sums *collected* rather than *billed*
  // revenue. They used to be derived from `_orders` here, which answered a
  // different question than the card titles claimed: "Orders today" was the
  // length of the whole order list and "Revenue today" was every order ever
  // billed, which also disagreed with the Revenue Analytics panel directly
  // below it on the same screen.
  //
  // The local derivation survives only as a fallback for the window before the
  // first fetch lands, and for tests that seed orders without stats.

  int _stat(String key, int fallback) =>
      (_stats[key] as num?)?.toInt() ?? fallback;

  int get ordersToday => _stat('orders_today', _orders.length);

  double get revenueToday =>
      (_stats['revenue_today'] as num?)?.toDouble() ??
      _orders.fold(0.0, (sum, o) => sum + o.totalAmount);

  int get readyForPickup =>
      _stat('ready_for_pickup', _countByStatus(OrderStatus.ready));

  int get overdueCount =>
      _stat('overdue', _orders.where((o) => o.isOverdue).length);

  int get customersTotal => _stat(
      'customers_total', _orders.map((o) => o.customerPhone).toSet().length);

  /// Percentage change against yesterday. Null means "nothing to compare
  /// against" — rendered as an em dash, never as 0%.
  double? get ordersTodayChange =>
      (_stats['orders_today_change'] as num?)?.toDouble();

  double? get revenueTodayChange =>
      (_stats['revenue_today_change'] as num?)?.toDouble();

  int? get customersNewToday =>
      (_stats['customers_new_today'] as num?)?.toInt();

  /// Total amount owed by a customer on orders that have already been delivered.
  /// Computed dynamically from orders so any status transition or payment reflects immediately.
  double deliveredDuesForCustomer(CustomerModel customer) {
    final matching = _orders.where((o) {
      final matches = (o.customerId.isNotEmpty && customer.id.isNotEmpty && o.customerId == customer.id) ||
          (customer.phone.isNotEmpty && o.customerPhone == customer.phone);
      return matches && o.status == OrderStatus.delivered && o.dueAmount > 0;
    });
    final fromOrders = matching.fold(0.0, (sum, o) => sum + o.dueAmount);
    if (fromOrders == 0 && customer.deliveredDueAmount > 0) {
      return customer.deliveredDueAmount;
    }
    return fromOrders;
  }

  /// List of delivered unpaid orders for a specific customer.
  List<OrderModel> deliveredUnpaidOrdersFor(CustomerModel customer) {
    return _orders.where((o) {
      final matches = (o.customerId.isNotEmpty && customer.id.isNotEmpty && o.customerId == customer.id) ||
          (customer.phone.isNotEmpty && o.customerPhone == customer.phone);
      return matches && o.status == OrderStatus.delivered && o.dueAmount > 0;
    }).toList();
  }

  /// Aggregate amount owed across all customers on orders that have been delivered.
  double get totalDeliveredDues {
    return _orders
        .where((o) => o.status == OrderStatus.delivered && o.dueAmount > 0)
        .fold(0.0, (sum, o) => sum + o.dueAmount);
  }

  /// Total count of unique customers who currently have delivered unpaid orders.
  int get customersWithDeliveredDuesCount {
    final owingKeys = <String>{};
    for (final o in _orders) {
      if (o.status == OrderStatus.delivered && o.dueAmount > 0) {
        if (o.customerId.isNotEmpty) {
          owingKeys.add(o.customerId);
        } else if (o.customerPhone.isNotEmpty) {
          owingKeys.add(o.customerPhone);
        }
      }
    }
    return owingKeys.length;
  }

  /// The last 14 days of revenue, oldest first. Empty until the stats land.
  List<RevenueSeriesPointModel> get revenueSeries {
    final raw = _stats['revenue_series'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RevenueSeriesPointModel.fromJson)
        .toList();
  }

  /// Pipeline counts as the server groups them, falling back to the local
  /// status tallies before the first fetch.
  int get pipelineReceived => _pipeline('received', receivedCount);
  int get pipelineProcessing => _pipeline('processing', processingCount);
  int get pipelineReady => _pipeline('ready', readyCount);
  int get pipelineOutForDelivery =>
      _pipeline('out_for_delivery', outForDeliveryCount);

  int _pipeline(String key, int fallback) {
    final data = _stats['pipeline'];
    if (data is! Map) return fallback;
    return (data[key] as num?)?.toInt() ?? fallback;
  }

  // ── Derived counters, all using the canonical status constants ─────────────

  int get receivedCount => _countByStatus(OrderStatus.placed);

  int get processingCount =>
      _countByStatus(OrderStatus.processing) +
      _countByStatus(OrderStatus.ironing);

  int get readyCount => _countByStatus(OrderStatus.ready);

  int get outForDeliveryCount => _countByStatus(OrderStatus.outForDelivery);

  int get deliveredCount => _countByStatus(OrderStatus.delivered);

  int _countByStatus(String status) =>
      _orders.where((o) => o.status == status).length;

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Which role the signed-in user has ('owner' or 'staff'); set from
  /// `AuthProvider` in main.dart. Staff's API access stops at orders,
  /// customers, the catalogue and shop details, so they skip the owner-only
  /// fetches below (a 403 there would fail the whole load).
  String role = 'owner';

  /// The staff version of [loadDataFromBackend]: only what staff may read.
  Future<void> _loadForStaff() async {
    try {
      final results = await Future.wait([
        ApiService.fetchOrders(),
        ApiService.fetchGarmentItems(includeInactive: true),
        ApiService.fetchCategories(),
        ApiService.fetchCustomers(),
        ApiService.fetchServiceAreas(),
        ApiService.fetchTimeSlots(kind: TimeSlotModel.pickup),
        ApiService.fetchTimeSlots(kind: TimeSlotModel.delivery),
        ApiService.fetchShop(),
        ApiService.fetchMeta(),
      ]);
      _orders = results[0] as List<OrderModel>;
      _garments = results[1] as List<GarmentItemModel>;
      _categories = results[2] as List<GarmentCategoryModel>;
      _customers = results[3] as List<CustomerModel>;
      _serviceAreas = results[4] as List<ServiceAreaModel>;
      _pickupSlots = results[5] as List<TimeSlotModel>;
      _deliverySlots = results[6] as List<TimeSlotModel>;
      _shop = results[7] as Map<String, dynamic>?;
      _applyShopFormatting();
      _meta = results[8] as MetaModel;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Something went wrong loading your shop: $e';
    }
  }

  /// The customer version of [loadDataFromBackend]: scoped orders, rate card, shop info.
  Future<void> _loadForCustomer() async {
    try {
      final results = await Future.wait([
        ApiService.fetchMyOrders(),
        ApiService.fetchRateCard(),
      ]);
      final rawOrders = results[0] as List<Map<String, dynamic>>;
      _orders = rawOrders.map(OrderModel.fromJson).toList();
      _categories = (results[1] as List<Map<String, dynamic>>).map((c) {
        return GarmentCategoryModel(
          id: c['name'] ?? '',
          name: c['name'] ?? '',
          items: ((c['items'] as List?) ?? const []).map((i) {
            return GarmentItemModel(
              id: i['name'] ?? '',
              name: i['name'] ?? '',
              categoryId: c['name'] ?? '',
              categoryName: c['name'] ?? '',
              price: (i['price'] ?? 0).toDouble(),
              unit: i['unit'] ?? 'PIECE',
            );
          }).toList(),
        );
      }).toList();
      try {
        final shop = await ApiService.fetchShop();
        _shop = shop;
        _applyShopFormatting();
      } catch (_) {}
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Something went wrong loading your orders: $e';
    }
  }

  Future<void> loadDataFromBackend() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (role == 'customer') {
      await _loadForCustomer();
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (role == 'staff') {
      await _loadForStaff();
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        ApiService.fetchOrders(),
        // Inactive items must still be fetched — Services' item list and
        // the category Active/Inactive pill both need to see them to render
        // correctly; filtering out inactive items at the fetch meant neither
        // had inactive data to work with in the first place.
        ApiService.fetchGarmentItems(includeInactive: true),
        ApiService.fetchCategories(),
        ApiService.fetchCustomers(),
        ApiService.fetchStaff(),
        ApiService.fetchExpenses(),
        ApiService.fetchCredits(),
        ApiService.fetchAttendance(),
        ApiService.fetchServiceAreas(),
        ApiService.fetchTimeSlots(kind: TimeSlotModel.pickup),
        ApiService.fetchTimeSlots(kind: TimeSlotModel.delivery),
        ApiService.fetchDashboardStats(),
        ApiService.fetchShop(),
        ApiService.fetchMeta(),
        ApiService.fetchCreditCategories(),
      ]);

      _orders = results[0] as List<OrderModel>;
      _garments = results[1] as List<GarmentItemModel>;
      _categories = results[2] as List<GarmentCategoryModel>;
      _customers = results[3] as List<CustomerModel>;
      _staff = results[4] as List<StaffModel>;
      _expenses = results[5] as List<ExpenseModel>;
      _credits = results[6] as List<CreditModel>;
      _attendance = results[7] as List<AttendanceModel>;
      _serviceAreas = results[8] as List<ServiceAreaModel>;
      _pickupSlots = results[9] as List<TimeSlotModel>;
      _deliverySlots = results[10] as List<TimeSlotModel>;
      _stats = results[11] as Map<String, dynamic>;
      _shop = results[12] as Map<String, dynamic>?;
      _applyShopFormatting();
      _meta = results[13] as MetaModel;
      _creditCategories = results[14] as List<CreditCategoryModel>;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Something went wrong loading your shop: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadDataFromBackend();

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Creates an order and returns the server's version of it — which carries
  /// the authoritative `order_number` (the backend allocates `WASH-000NN`;
  /// `order_number` is read-only on the serializer, so anything the client
  /// sends is discarded). Returns null on failure, with [error] set.
  ///
  /// Callers must honour the null: an order that failed to save must not be
  /// shown as if it succeeded.
  Future<OrderModel?> createNewOrder(Map<String, dynamic> payload) async {
    try {
      final newOrder = await ApiService.createOrder(payload);
      _orders.insert(0, newOrder);
      _error = null;
      notifyListeners();
      return newOrder;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateOrderStatus(String orderId, String status,
      {String? note}) async {
    try {
      final updated =
          await ApiService.updateOrderStatus(orderId, status, note: note);
      _replaceOrder(updated);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Edits the order header. Returns the saved order so the detail screen can
  /// re-render from the server's copy rather than its own optimistic guess.
  Future<OrderModel?> updateOrder(
      String orderId, Map<String, dynamic> payload) async {
    try {
      final updated = await ApiService.updateOrder(orderId, payload);
      _replaceOrder(updated);
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> collectPayment(String orderId, double amount) async {
    try {
      final updated = await ApiService.collectPayment(orderId, amount);
      _replaceOrder(updated);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// The order-detail "Collect Payment" dialog's submit action. Records the
  /// payment (skipped when [amount] is 0, e.g. "Pay Later") and, when
  /// [markDelivered] is true, also completes the delivery/pickup — this is
  /// how an order now reaches Delivered, replacing the old manual status
  /// option.
  Future<bool> collectPaymentAndMarkDelivered(
    String orderId, {
    required double amount,
    required String paymentMethod,
    required bool markDelivered,
  }) async {
    try {
      if (amount > 0) {
        final updated = await ApiService.collectPayment(orderId, amount,
            paymentMethod: paymentMethod);
        _replaceOrder(updated);
      }
      if (markDelivered) {
        final updated =
            await ApiService.updateOrderStatus(orderId, OrderStatus.delivered);
        _replaceOrder(updated);
      }
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCustomer(Map<String, dynamic> payload) async {
    try {
      final customer = await ApiService.createCustomer(payload);
      _customers.insert(0, customer);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCustomer(String id, Map<String, dynamic> payload) async {
    try {
      final updated = await ApiService.updateCustomer(id, payload);
      final index = _customers.indexWhere((c) => c.id == updated.id);
      if (index >= 0) {
        _customers[index] = updated;
      } else {
        _customers.insert(0, updated);
      }
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// The FK from `Order.customer` is `SET_NULL`, so a customer with order
  /// history can be deleted safely — their past orders keep their own
  /// snapshotted `customer_name`/`customer_phone` and just lose the link.
  Future<bool> deleteCustomer(String id) async {
    try {
      await ApiService.deleteCustomer(id);
      _customers.removeWhere((c) => c.id == id);
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addStaff(Map<String, dynamic> payload) async {
    try {
      final member = await ApiService.createStaff(payload);
      _staff.insert(0, member);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Creates a catalogue item, then reloads so category counts and price
  /// ranges pick it up (both are computed server-side).
  Future<bool> addGarmentItem(Map<String, dynamic> payload) async {
    try {
      await ApiService.saveGarmentItem(payload);
      await loadDataFromBackend();
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGarmentItem(
      String id, Map<String, dynamic> payload) async {
    try {
      await ApiService.saveGarmentItem(payload, id: id);
      await loadDataFromBackend();
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGarmentItem(String id) async {
    try {
      await ApiService.deleteGarmentItem(id);
      await loadDataFromBackend();
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Creates a service category. Like [addGarmentItem] this reloads rather than
  /// inserting locally, because `item_count` and `price_range` are server-side
  /// properties the POST response can't be trusted to keep current.
  ///
  /// Returns the new category's id, or null on failure with [error] set.
  Future<String?> addCategory(Map<String, dynamic> payload) async {
    try {
      final created = await ApiService.createCategory(payload);
      await loadDataFromBackend();
      _error = null;
      notifyListeners();
      return created.id;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCategory(String id, Map<String, dynamic> payload) async {
    try {
      await ApiService.updateCategory(id, payload);
      await loadDataFromBackend();
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      await ApiService.deleteCategory(id);
      await loadDataFromBackend();
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // ── Service areas ──────────────────────────────────────────────────────────

  Future<bool> addServiceArea(Map<String, dynamic> payload) async {
    try {
      final area = await ApiService.createServiceArea(payload);
      _serviceAreas = [..._serviceAreas, area];
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteServiceArea(String id) async {
    try {
      await ApiService.deleteServiceArea(id);
      _serviceAreas = _serviceAreas.where((a) => a.id != id).toList();
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // ── Time slots ─────────────────────────────────────────────────────────────

  List<TimeSlotModel> _slotsFor(String kind) =>
      kind == TimeSlotModel.delivery ? _deliverySlots : _pickupSlots;

  void _setSlotsFor(String kind, List<TimeSlotModel> slots) {
    // Kept in start_time order, matching the backend's Meta.ordering — so a
    // slot added mid-morning lands between its neighbours, not at the end.
    slots.sort((a, b) => a.startTime.compareTo(b.startTime));
    if (kind == TimeSlotModel.delivery) {
      _deliverySlots = slots;
    } else {
      _pickupSlots = slots;
    }
  }

  Future<bool> addTimeSlot(Map<String, dynamic> payload) async {
    try {
      final slot = await ApiService.createTimeSlot(payload);
      _setSlotsFor(slot.kind, [..._slotsFor(slot.kind), slot]);
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTimeSlot(String id, Map<String, dynamic> payload) async {
    try {
      final updated = await ApiService.updateTimeSlot(id, payload);
      _setSlotsFor(
        updated.kind,
        _slotsFor(updated.kind).map((s) => s.id == id ? updated : s).toList(),
      );
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTimeSlot(String kind, String id) async {
    try {
      await ApiService.deleteTimeSlot(id);
      _setSlotsFor(kind, _slotsFor(kind).where((s) => s.id != id).toList());
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStaff(String id, Map<String, dynamic> payload) async {
    try {
      final updated = await ApiService.updateStaff(id, payload);
      final index = _staff.indexWhere((s) => s.id == updated.id);
      if (index >= 0) {
        _staff[index] = updated;
      } else {
        _staff.insert(0, updated);
      }
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Persists the shop profile behind the Settings screen.
  Future<bool> saveShop(Map<String, dynamic> payload) async {
    final id = _shop?['id']?.toString();
    if (id == null) {
      _error = 'No shop loaded yet.';
      notifyListeners();
      return false;
    }
    try {
      _shop = await ApiService.updateShop(id, payload);
      _applyShopFormatting();
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // ── Attendance ─────────────────────────────────────────────────────────────

  /// `YYYY-MM-DD`, the shape Django's `DateField` parses. Done by hand rather
  /// than via intl so the provider stays free of formatting dependencies.
  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// The register for one day as `{staffId: status}`. A staff member with no
  /// row is simply absent from the map — that is "not marked yet", which is a
  /// different thing from ABSENT and the screen renders it differently.
  Map<String, String> attendanceFor(DateTime day) {
    final key = dateKey(day);
    return {
      for (final a in _attendance)
        if (a.date != null && dateKey(a.date!) == key) a.staffId: a.status,
    };
  }

  /// Returns the full [AttendanceModel] record for a staff member on a day,
  /// containing status, check-in time, and notes if recorded.
  AttendanceModel? attendanceRecord(DateTime day, String staffId) {
    final key = dateKey(day);
    for (final a in _attendance) {
      if (a.date != null && dateKey(a.date!) == key && a.staffId == staffId) {
        return a;
      }
    }
    return null;
  }

  /// Loads one day and merges it in, replacing whatever was held for that date.
  /// Cheaper than [loadDataFromBackend] when only the date picker moved.
  Future<void> loadAttendanceFor(DateTime day) async {
    _attendanceLoading = true;
    _attendanceError = null;
    notifyListeners();
    try {
      final fetched = await ApiService.fetchAttendance(date: dateKey(day));
      _mergeAttendance(day, fetched);
    } on ApiException catch (e) {
      _attendanceError = e.message;
    }
    _attendanceLoading = false;
    notifyListeners();
  }

  /// Loads all attendance records for a whole calendar month (e.g. for the
  /// monthly matrix / calendar heatmap) and merges them into the local cache.
  Future<void> loadAttendanceForMonth(DateTime month) async {
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    try {
      final fetched = await ApiService.fetchAttendance(month: monthStr);
      _attendance = [
        ..._attendance.where((a) {
          if (a.date == null) return true;
          final aMonth =
              '${a.date!.year}-${a.date!.month.toString().padLeft(2, '0')}';
          return aMonth != monthStr;
        }),
        ...fetched,
      ];
      notifyListeners();
    } on ApiException catch (e) {
      _attendanceError = e.message;
      notifyListeners();
    }
  }

  /// Saves a day's register. [marks] is `{staffId: status}`; only the staff
  /// present in the map are written, so leaving someone unmarked leaves their
  /// existing row alone rather than defaulting them to present.
  Future<bool> saveAttendance(
    DateTime day,
    Map<String, String> marks, {
    Map<String, String?>? checkInTimes,
    Map<String, String>? notes,
  }) async {
    try {
      final saved = await ApiService.saveAttendance(
        dateKey(day),
        [
          for (final entry in marks.entries)
            {
              'staff': int.tryParse(entry.key) ?? entry.key,
              'status': entry.value,
              if (checkInTimes != null && checkInTimes.containsKey(entry.key))
                'check_in_time': checkInTimes[entry.key],
              if (notes != null && notes.containsKey(entry.key))
                'notes': notes[entry.key],
            },
        ],
      );
      _mergeAttendance(day, saved);
      _attendanceError = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _attendanceError = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Marks all eligible active staff members as PRESENT for [day].
  Future<bool> markAllPresent(DateTime day) async {
    final activeStaff =
        staff.where((s) => s.status.toUpperCase() == 'ACTIVE').toList();
    final eligible = activeStaff.where((s) {
      if (s.startDate == null) return true;
      final dayOnly = DateTime(day.year, day.month, day.day);
      final startOnly = DateTime(s.startDate!.year, s.startDate!.month, s.startDate!.day);
      return !dayOnly.isBefore(startOnly);
    }).toList();

    final marks = <String, String>{};
    for (final s in eligible) {
      marks[s.id] = 'PRESENT';
    }
    return saveAttendance(day, marks);
  }

  void _mergeAttendance(DateTime day, List<AttendanceModel> rows) {
    final key = dateKey(day);
    _attendance = [
      ..._attendance.where((a) => a.date == null || dateKey(a.date!) != key),
      ...rows,
    ];
  }

  // ── Payroll ────────────────────────────────────────────────────────────────

  /// `YYYY-MM`, the shape `/api/payroll/` expects.
  static String monthKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

  Future<void> loadPayrollFor(DateTime month) async {
    _payrollLoading = true;
    _payrollError = null;
    notifyListeners();
    try {
      _payroll = await ApiService.fetchPayroll(month: monthKey(month));
    } on ApiException catch (e) {
      _payrollError = e.message;
    }
    _payrollLoading = false;
    notifyListeners();
  }

  /// Records a payout, then reloads the month — `paid`, `pending` and the
  /// PAID/PARTIAL/UNPAID status are all computed server-side, so a local guess
  /// at the new totals could disagree with the next fetch.
  Future<bool> recordSalaryPayment({
    required String staffId,
    required DateTime month,
    required double amount,
    String method = 'CASH',
    String note = '',
  }) async {
    try {
      await ApiService.recordSalaryPayment({
        'staff': int.tryParse(staffId) ?? staffId,
        'month': '${monthKey(month)}-01',
        'amount': amount,
        'method': method,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      });
      await loadPayrollFor(month);
      return _payrollError == null;
    } on ApiException catch (e) {
      _payrollError = e.message;
      notifyListeners();
      return false;
    }
  }

  /// One staff member's full payout history — unlike [payroll] this is not
  /// cached provider state, since the Payment History dialog fetches it fresh
  /// each time it opens rather than tracking a loading/error pair for it.
  /// Throws [ApiException] on failure; callers (a `FutureBuilder`) handle that.
  Future<List<SalaryPaymentModel>> fetchSalaryHistory(String staffId) =>
      ApiService.fetchSalaryPayments(staffId: staffId);

  /// Records an advance against [month]'s wages — comes off net pay rather
  /// than being logged as money already paid. See [recordSalaryPayment].
  Future<bool> recordSalaryAdvance({
    required String staffId,
    required DateTime month,
    required double amount,
    String method = 'CASH',
    String note = '',
  }) async {
    try {
      await ApiService.recordSalaryAdvance({
        'staff': int.tryParse(staffId) ?? staffId,
        'month': '${monthKey(month)}-01',
        'amount': amount,
        'method': method,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      });
      await loadPayrollFor(month);
      return _payrollError == null;
    } on ApiException catch (e) {
      _payrollError = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Settles every entry with a pending balance in one go — the header's
  /// "Pay all pending" action. Pays sequentially rather than in parallel so
  /// one failure doesn't leave a half-applied burst of concurrent requests,
  /// and stops at the first failure rather than pressing on past it.
  /// Returns how many entries were actually paid.
  Future<int> payAllPending(DateTime month, {String method = 'CASH'}) async {
    final pending = (_payroll?.entries ?? const <PayrollEntryModel>[])
        .where((e) => e.pendingAmount > 0)
        .toList();
    var paidCount = 0;
    for (final entry in pending) {
      final ok = await recordSalaryPayment(
        staffId: entry.staffId,
        month: month,
        amount: entry.pendingAmount,
        method: method,
        note: 'Paid via Pay all pending',
      );
      if (!ok) break;
      paidCount++;
    }
    return paidCount;
  }

  // ── Reports ────────────────────────────────────────────────────────────────

  Future<void> loadReportsFor(DateTime from, DateTime to) async {
    _reportsLoading = true;
    _reportsError = null;
    notifyListeners();
    try {
      _reports = await ApiService.fetchReports(
        from: dateKey(from),
        to: dateKey(to),
      );
    } on ApiException catch (e) {
      _reportsError = e.message;
    }
    _reportsLoading = false;
    notifyListeners();
  }

  Future<bool> addExpense(Map<String, dynamic> payload) async {
    try {
      final expense = await ApiService.createExpense(payload);
      _expenses.insert(0, expense);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateExpense(String id, Map<String, dynamic> payload) async {
    try {
      final updated = await ApiService.updateExpense(id, payload);
      final index = _expenses.indexWhere((e) => e.id == updated.id);
      if (index >= 0) {
        _expenses[index] = updated;
      } else {
        _expenses.insert(0, updated);
      }
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await ApiService.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCredit(Map<String, dynamic> payload) async {
    try {
      final credit = await ApiService.createCredit(payload);
      _credits.insert(0, credit);
      notifyListeners();
      _refreshCreditCategories();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCredit(String id, Map<String, dynamic> payload) async {
    try {
      final updated = await ApiService.updateCredit(id, payload);
      final index = _credits.indexWhere((c) => c.id == updated.id);
      if (index >= 0) {
        _credits[index] = updated;
      } else {
        _credits.insert(0, updated);
      }
      _error = null;
      notifyListeners();
      _refreshCreditCategories();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCredit(String id) async {
    try {
      await ApiService.deleteCredit(id);
      _credits.removeWhere((c) => c.id == id);
      _error = null;
      notifyListeners();
      _refreshCreditCategories();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Re-reads the category list so each one's credit count — which decides
  /// whether Settings offers Delete — follows credits being added or removed.
  /// Best-effort: a failed refresh just leaves the previous counts.
  Future<void> _refreshCreditCategories() async {
    try {
      _creditCategories = await ApiService.fetchCreditCategories();
      notifyListeners();
    } on ApiException {
      // Stale counts only affect whether Delete is offered, and the backend
      // still refuses to delete a category in use.
    }
  }

  /// Adds a credit category. Returns null on success, otherwise the backend's
  /// message (blank or duplicate name) for the form to show inline.
  Future<String?> addCreditCategory(String name) async {
    try {
      final created = await ApiService.createCreditCategory({
        'name': name,
        'display_order': _creditCategories.length,
      });
      _creditCategories = [..._creditCategories, created];
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Renames or turns a credit category on/off. A rename also reloads credits,
  /// since they carry the category by name. Null on success, else the error.
  Future<String?> updateCreditCategory(
      String id, Map<String, dynamic> payload) async {
    try {
      final updated = await ApiService.updateCreditCategory(id, payload);
      _creditCategories = [
        for (final c in _creditCategories) c.id == id ? updated : c,
      ];
      if (payload.containsKey('name')) {
        _credits = await ApiService.fetchCredits();
      }
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Deletes an unused credit category. Null on success, else the backend's
  /// refusal ("N credits use …") when it is in use.
  Future<String?> deleteCreditCategory(String id) async {
    try {
      await ApiService.deleteCreditCategory(id);
      _creditCategories = _creditCategories.where((c) => c.id != id).toList();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void _replaceOrder(OrderModel updated) {
    final index = _orders.indexWhere((o) => o.id == updated.id);
    if (index >= 0) {
      _orders[index] = updated;
    } else {
      _orders.insert(0, updated);
    }
    _error = null;
    notifyListeners();
  }
}

/// The date ranges offered by the Orders screen's dropdown, matching the live
/// app: All time / Today / This Week / This Month / Last Month.
enum OrderDateRange {
  allTime('All time'),
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  lastMonth('Last Month');

  const OrderDateRange(this.label);

  final String label;

  static OrderDateRange fromLabel(String label) => values.firstWhere(
        (r) => r.label == label,
        orElse: () => OrderDateRange.allTime,
      );

  /// Whether [when] falls inside this range, relative to [now]
  /// (injectable so the boundaries are testable).
  bool contains(DateTime when, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final day = DateTime(when.year, when.month, when.day);
    final startOfToday = DateTime(today.year, today.month, today.day);

    switch (this) {
      case OrderDateRange.allTime:
        return true;
      case OrderDateRange.today:
        return day == startOfToday;
      case OrderDateRange.thisWeek:
        // Week starts Monday, as it does on the live dashboard.
        final startOfWeek =
            startOfToday.subtract(Duration(days: today.weekday - 1));
        return !day.isBefore(startOfWeek) && !day.isAfter(startOfToday);
      case OrderDateRange.thisMonth:
        return when.year == today.year && when.month == today.month;
      case OrderDateRange.lastMonth:
        final previous = DateTime(today.year, today.month - 1);
        return when.year == previous.year && when.month == previous.month;
    }
  }
}
