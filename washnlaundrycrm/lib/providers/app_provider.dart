import 'package:flutter/foundation.dart';

import '../models/garment_model.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
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

  List<AttendanceModel> _attendance = [];
  List<AttendanceModel> get attendance => _attendance;

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
    List<ServiceAreaModel>? serviceAreas,
    List<TimeSlotModel>? pickupSlots,
    List<TimeSlotModel>? deliverySlots,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? shop,
  }) {
    if (orders != null) _orders = orders;
    if (garments != null) _garments = garments;
    if (categories != null) _categories = categories;
    if (customers != null) _customers = customers;
    if (staff != null) _staff = staff;
    if (expenses != null) _expenses = expenses;
    if (serviceAreas != null) _serviceAreas = serviceAreas;
    if (pickupSlots != null) _pickupSlots = pickupSlots;
    if (deliverySlots != null) _deliverySlots = deliverySlots;
    if (stats != null) _stats = stats;
    if (shop != null) _shop = shop;
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
          o.customerPhone.contains(query);
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
        return _orders.where((o) => o.paymentStatus == PaymentStatus.unpaid).toList();
      case 'PARTIAL':
        return _orders.where((o) => o.paymentStatus == PaymentStatus.partial).toList();
      default:
        return _orders.where((o) => o.status == filter.toUpperCase()).toList();
    }
  }

  // ── Derived counters, all using the canonical status constants ─────────────

  int get ordersToday => _orders.length;

  double get revenueToday => _orders.fold(0.0, (sum, o) => sum + o.totalAmount);

  int get readyForPickup => _countByStatus(OrderStatus.ready);

  int get overdueCount => _orders.where((o) => o.isOverdue).length;

  int get customersToday => _orders.map((o) => o.customerPhone).toSet().length;

  int get receivedCount => _countByStatus(OrderStatus.placed);

  int get processingCount =>
      _countByStatus(OrderStatus.processing) + _countByStatus(OrderStatus.ironing);

  int get readyCount => _countByStatus(OrderStatus.ready);

  int get outForDeliveryCount => _countByStatus(OrderStatus.outForDelivery);

  int get deliveredCount => _countByStatus(OrderStatus.delivered);

  int _countByStatus(String status) =>
      _orders.where((o) => o.status == status).length;

  // ── Loading ────────────────────────────────────────────────────────────────

  Future<void> loadDataFromBackend() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiService.fetchOrders(),
        ApiService.fetchGarmentItems(),
        ApiService.fetchCategories(),
        ApiService.fetchCustomers(),
        ApiService.fetchStaff(),
        ApiService.fetchExpenses(),
        ApiService.fetchAttendance(),
        ApiService.fetchServiceAreas(),
        ApiService.fetchTimeSlots(kind: TimeSlotModel.pickup),
        ApiService.fetchTimeSlots(kind: TimeSlotModel.delivery),
        ApiService.fetchDashboardStats(),
        ApiService.fetchShop(),
      ]);

      _orders = results[0] as List<OrderModel>;
      _garments = results[1] as List<GarmentItemModel>;
      _categories = results[2] as List<GarmentCategoryModel>;
      _customers = results[3] as List<CustomerModel>;
      _staff = results[4] as List<StaffModel>;
      _expenses = results[5] as List<ExpenseModel>;
      _attendance = results[6] as List<AttendanceModel>;
      _serviceAreas = results[7] as List<ServiceAreaModel>;
      _pickupSlots = results[8] as List<TimeSlotModel>;
      _deliverySlots = results[9] as List<TimeSlotModel>;
      _stats = results[10] as Map<String, dynamic>;
      _shop = results[11] as Map<String, dynamic>?;
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

  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final updated = await ApiService.updateOrderStatus(orderId, status);
      _replaceOrder(updated);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
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
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
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
        final startOfWeek = startOfToday.subtract(Duration(days: today.weekday - 1));
        return !day.isBefore(startOfWeek) && !day.isAfter(startOfToday);
      case OrderDateRange.thisMonth:
        return when.year == today.year && when.month == today.month;
      case OrderDateRange.lastMonth:
        final previous = DateTime(today.year, today.month - 1);
        return when.year == previous.year && when.month == previous.month;
    }
  }
}
