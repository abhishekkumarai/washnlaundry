import '../utils/money.dart';

/// Pricing units used by the catalogue. Mirrors `PricingUnit` in the backend.
class PricingUnit {
  static const piece = 'PC';
  static const kg = 'KG';
  static const sqft = 'SQFT';
  static const set = 'SET';

  /// The four codes, in the order the Add Item dropdown offers them.
  static const List<String> all = [piece, kg, sqft, set];

  /// Sentence case, exactly as the live app labels the unit — on the item card
  /// chip ("Per piece") and as the default of the Add Item modal's Unit select.
  static String label(String unit) {
    switch (unit) {
      case kg:
        return 'Per kg';
      case sqft:
        return 'Per sq. ft.';
      case set:
        return 'Per set';
      case piece:
      default:
        return 'Per piece';
    }
  }

  /// Short suffix as shown on price tags, e.g. "₹15 / pc".
  static String shortLabel(String unit) {
    switch (unit) {
      case kg:
        return 'kg';
      case sqft:
        return 'sq.ft';
      case set:
        return 'set';
      case piece:
      default:
        return 'pc';
    }
  }
}

/// One catalogue row: a single item, in a single category, at a single price.
///
/// The same garment can appear under several categories at different prices —
/// "Shirt" is ₹15 under Ironing and ₹40 under Wash & Iron. Those are two
/// separate rows, which is why the catalogue has 79 entries across 7 categories.
class GarmentItemModel {
  final String id;
  final String categoryId;
  final String categoryName;
  final String name;
  final double price;
  final String unit;
  final int turnaroundDays;
  final bool isActive;

  /// Product photo, or '' to fall back to the icon treatment. The client used
  /// to hold a map of item *names* to Unsplash URLs, so a rename lost the
  /// picture and a shop could never supply its own.
  final String imageUrl;

  const GarmentItemModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.price,
    this.unit = PricingUnit.piece,
    this.turnaroundDays = 1,
    this.isActive = true,
    this.imageUrl = '',
  });

  String get unitLabel => PricingUnit.label(unit);
  String get unitShortLabel => PricingUnit.shortLabel(unit);
  String get turnaroundLabel => '${turnaroundDays}d';

  factory GarmentItemModel.fromJson(Map<String, dynamic> json) {
    return GarmentItemModel(
      id: json['id'].toString(),
      categoryId: json['category']?.toString() ?? '',
      categoryName: json['category_name'] ?? 'General',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      unit: json['unit'] ?? PricingUnit.piece,
      turnaroundDays: json['turnaround_days'] ?? 1,
      isActive: json['is_active'] ?? true,
      imageUrl: json['image_url'] ?? '',
    );
  }
}

class GarmentCategoryModel {
  final String id;
  final String name;
  final String icon;
  final int displayOrder;
  final bool isActive;
  final int turnaroundDays;
  final int itemCount;
  final double minPrice;
  final double maxPrice;
  final List<GarmentItemModel> items;

  const GarmentCategoryModel({
    required this.id,
    required this.name,
    this.icon = 'Shirt',
    this.displayOrder = 0,
    this.isActive = true,
    this.turnaroundDays = 1,
    this.itemCount = 0,
    this.minPrice = 0,
    this.maxPrice = 0,
    this.items = const [],
  });

  /// "10–100 ₹", as the live Services screen renders it — symbol trailing,
  /// which is why this one does not go through [Money.format].
  String get priceRangeLabel =>
      '${minPrice.toStringAsFixed(0)}–${maxPrice.toStringAsFixed(0)} ${Money.symbol}';

  factory GarmentCategoryModel.fromJson(Map<String, dynamic> json) {
    final range = json['price_range'] as Map<String, dynamic>? ?? const {};
    final rawItems = json['items'] as List? ?? const [];
    return GarmentCategoryModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      icon: json['icon'] ?? 'Shirt',
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      turnaroundDays: json['turnaround_days'] ?? 1,
      itemCount: json['item_count'] ?? rawItems.length,
      minPrice: (range['min'] ?? 0).toDouble(),
      maxPrice: (range['max'] ?? 0).toDouble(),
      items: rawItems
          .map((i) => GarmentItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String area;
  final int totalOrders;
  final double totalSpent;
  final double dueAmount;
  final double avgOrderValue;
  final DateTime? createdAt;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.area = '',
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.dueAmount = 0,
    this.avgOrderValue = 0,
    this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      area: json['area'] ?? '',
      totalOrders: json['total_orders'] ?? 0,
      totalSpent: (json['total_spent'] ?? 0).toDouble(),
      dueAmount: (json['due_amount'] ?? 0).toDouble(),
      avgOrderValue: (json['avg_order_value'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'area': area,
      };
}

class StaffModel {
  final String id;
  final String name;
  final String role;
  final String phone;
  final double monthlyWage;
  final String status;
  final bool hasAppLogin;

  const StaffModel({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    this.monthlyWage = 0,
    this.status = 'ACTIVE',
    this.hasAppLogin = false,
  });

  bool get isActive => status == 'ACTIVE';

  factory StaffModel.fromJson(Map<String, dynamic> json) => StaffModel(
        id: json['id'].toString(),
        name: json['name'] ?? '',
        role: json['role'] ?? '',
        phone: json['phone'] ?? '',
        monthlyWage: (json['monthly_wage'] ?? 0).toDouble(),
        status: json['status'] ?? 'ACTIVE',
        hasAppLogin: json['has_app_login'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'phone': phone,
        'monthly_wage': monthlyWage,
        'status': status,
        'has_app_login': hasAppLogin,
      };
}

class ExpenseModel {
  final String id;
  final String title;
  final String category;
  final double amount;
  final String paymentMethod;
  final DateTime? date;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    this.paymentMethod = 'CASH',
    this.date,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'].toString(),
        title: json['title'] ?? '',
        category: json['category'] ?? 'Supplies',
        amount: (json['amount'] ?? 0).toDouble(),
        paymentMethod: json['payment_method'] ?? 'CASH',
        date: DateTime.tryParse(json['date'] ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        'amount': amount,
        'payment_method': paymentMethod,
      };
}

class AttendanceModel {
  final String id;
  final String staffId;
  final String staffName;
  final DateTime? date;
  final String status;

  const AttendanceModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    this.date,
    this.status = 'PRESENT',
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) => AttendanceModel(
        id: json['id'].toString(),
        staffId: json['staff'].toString(),
        staffName: json['staff_name'] ?? '',
        date: DateTime.tryParse(json['date'] ?? ''),
        status: json['status'] ?? 'PRESENT',
      );
}

class ServiceAreaModel {
  final String id;
  final String name;
  final String pinCode;
  final bool isActive;

  const ServiceAreaModel({
    required this.id,
    required this.name,
    this.pinCode = '',
    this.isActive = true,
  });

  factory ServiceAreaModel.fromJson(Map<String, dynamic> json) => ServiceAreaModel(
        id: json['id'].toString(),
        name: json['name'] ?? '',
        pinCode: json['pin_code'] ?? '',
        isActive: json['is_active'] ?? true,
      );
}

/// One staff member's payroll for one month, as `/api/payroll/` computes it.
///
/// Everything here is derived server-side: wages earned come from the
/// attendance register times a per-day rate (the monthly wage divided by
/// however many days that month has), and [paidAmount] from the month's
/// SalaryPayment rows. Nothing is stored on the staff record, so these cannot
/// drift out of step with the register.
class PayrollEntryModel {
  final String staffId;
  final String staffName;
  final String role;
  final double monthlyWage;
  final double daysWorked;
  final double totalSalary;
  final double paidAmount;
  final double pendingAmount;

  /// PAID / PARTIAL / UNPAID — the same vocabulary orders use.
  final String status;

  const PayrollEntryModel({
    required this.staffId,
    required this.staffName,
    this.role = '',
    this.monthlyWage = 0,
    this.daysWorked = 0,
    this.totalSalary = 0,
    this.paidAmount = 0,
    this.pendingAmount = 0,
    this.status = 'UNPAID',
  });

  factory PayrollEntryModel.fromJson(Map<String, dynamic> json) => PayrollEntryModel(
        staffId: json['staff'].toString(),
        staffName: json['staff_name'] ?? '',
        role: json['role'] ?? '',
        monthlyWage: (json['monthly_wage'] ?? 0).toDouble(),
        daysWorked: (json['days_worked'] ?? 0).toDouble(),
        totalSalary: (json['total_salary'] ?? 0).toDouble(),
        paidAmount: (json['paid_amount'] ?? 0).toDouble(),
        pendingAmount: (json['pending_amount'] ?? 0).toDouble(),
        status: json['status'] ?? 'UNPAID',
      );

  /// "24" or "23.5" — half-days are real, so a whole number should not gain a
  /// misleading ".0".
  String get daysWorkedLabel =>
      daysWorked == daysWorked.roundToDouble() ? daysWorked.toInt().toString() : '$daysWorked';
}

/// A month of payroll: the rows plus the four KPI totals above them.
class PayrollSummaryModel {
  final DateTime? month;
  final List<PayrollEntryModel> entries;
  final double totalPayroll;
  final double paid;
  final double pending;
  final int staffCount;

  const PayrollSummaryModel({
    this.month,
    this.entries = const [],
    this.totalPayroll = 0,
    this.paid = 0,
    this.pending = 0,
    this.staffCount = 0,
  });

  factory PayrollSummaryModel.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PayrollSummaryModel(
      month: DateTime.tryParse(json['month'] ?? ''),
      entries: ((json['entries'] as List?) ?? const [])
          .map((e) => PayrollEntryModel.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      totalPayroll: (totals['total_payroll'] ?? 0).toDouble(),
      paid: (totals['paid'] ?? 0).toDouble(),
      pending: (totals['pending'] ?? 0).toDouble(),
      staffCount: (totals['staff_count'] ?? 0).toInt(),
    );
  }
}

/// One labelled slice of a breakdown — a status, a delivery type or a service.
class ReportBreakdownModel {
  final String key;
  final String label;
  final int count;

  const ReportBreakdownModel({this.key = '', required this.label, this.count = 0});

  factory ReportBreakdownModel.fromJson(Map<String, dynamic> json) => ReportBreakdownModel(
        key: json['key'] ?? '',
        label: json['label'] ?? '',
        count: (json['count'] ?? 0).toInt(),
      );
}

/// One month of the revenue-vs-expenses chart, in rupees.
///
/// Absolute amounts, not the hand-typed 0..1 ratios the screen used to be
/// handed — the widget normalises against the series maximum itself.
class ReportMonthModel {
  final String label;
  final double revenue;
  final double expenses;

  const ReportMonthModel({this.label = '', this.revenue = 0, this.expenses = 0});

  factory ReportMonthModel.fromJson(Map<String, dynamic> json) => ReportMonthModel(
        label: json['label'] ?? '',
        revenue: (json['revenue'] ?? 0).toDouble(),
        expenses: (json['expenses'] ?? 0).toDouble(),
      );
}

/// One `{value, label}` pair from `/api/meta/`.
class ChoiceModel {
  final String value;
  final String label;

  const ChoiceModel({required this.value, required this.label});

  factory ChoiceModel.fromJson(Map<String, dynamic> json) => ChoiceModel(
        value: json['value']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );
}

/// The canonical vocabularies, served rather than hand-mirrored.
///
/// Payment methods are why this exists: the app used to carry three separate
/// hardcoded lists — New Order offered three methods, Expenses and Payroll
/// four in different orders — against a backend field with no choices at all.
class MetaModel {
  final List<ChoiceModel> orderStatuses;
  final List<ChoiceModel> paymentStatuses;
  final List<ChoiceModel> deliveryTypes;
  final List<ChoiceModel> orderSources;
  final List<ChoiceModel> pricingUnits;
  final List<ChoiceModel> paymentMethods;
  final List<ChoiceModel> expenseCategories;
  final List<ChoiceModel> attendanceStatuses;

  const MetaModel({
    this.orderStatuses = const [],
    this.paymentStatuses = const [],
    this.deliveryTypes = const [],
    this.orderSources = const [],
    this.pricingUnits = const [],
    this.paymentMethods = const [],
    this.expenseCategories = const [],
    this.attendanceStatuses = const [],
  });

  bool get isEmpty => paymentMethods.isEmpty;

  static List<ChoiceModel> _list(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ChoiceModel.fromJson)
        .toList();
  }

  factory MetaModel.fromJson(Map<String, dynamic> json) => MetaModel(
        orderStatuses: _list(json['order_statuses']),
        paymentStatuses: _list(json['payment_statuses']),
        deliveryTypes: _list(json['delivery_types']),
        orderSources: _list(json['order_sources']),
        pricingUnits: _list(json['pricing_units']),
        paymentMethods: _list(json['payment_methods']),
        expenseCategories: _list(json['expense_categories']),
        attendanceStatuses: _list(json['attendance_statuses']),
      );
}

/// One day of the dashboard's 14-day revenue series.
///
/// [day] is the day-of-month the server labelled the point with, so the axis
/// follows the real calendar. The chart used to hardcode days 16..29 and
/// invent the amounts.
class RevenueSeriesPointModel {
  final String date;
  final int day;
  final double amount;

  const RevenueSeriesPointModel({
    this.date = '',
    this.day = 0,
    this.amount = 0,
  });

  factory RevenueSeriesPointModel.fromJson(Map<String, dynamic> json) =>
      RevenueSeriesPointModel(
        date: json['date'] ?? '',
        day: (json['day'] ?? 0).toInt(),
        amount: (json['amount'] ?? 0).toDouble(),
      );
}

/// How much was collected by each payment method, with the share already
/// worked out server-side rather than parsed back out of a display string.
class PaymentMixModel {
  final String method;
  final double amount;
  final double percent;

  const PaymentMixModel({required this.method, this.amount = 0, this.percent = 0});

  factory PaymentMixModel.fromJson(Map<String, dynamic> json) => PaymentMixModel(
        method: json['method'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        percent: (json['percent'] ?? 0).toDouble(),
      );

  /// Payment methods that are acronyms and must not be title-cased — plain
  /// capitalisation turns UPI into "Upi", which is how nobody writes it.
  static const _acronyms = {'UPI', 'POS', 'QR', 'NEFT', 'IMPS', 'RTGS', 'COD'};

  /// "BANK_TRANSFER" -> "Bank Transfer", but "UPI" stays "UPI".
  String get methodLabel => method
      .split('_')
      .map((w) => w.isEmpty || _acronyms.contains(w.toUpperCase())
          ? w.toUpperCase()
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Everything on the Reports screen for one date range, from `/api/reports/`.
///
/// The nullable fields are null when there is nothing to measure — an idle
/// period is not a 0% margin, and the screen renders the two differently.
class ReportsModel {
  final DateTime? from;
  final DateTime? to;
  final double revenue;
  final double? revenueChange;
  final double collected;
  final double? collectedPercent;
  final double outstanding;
  final double expenses;
  final double? expensesChange;
  final double netProfit;
  final double? netProfitChange;
  final double? margin;
  final int orderCount;
  final double averageOrderValue;
  final List<ReportMonthModel> monthlySeries;
  final List<ReportBreakdownModel> byStatus;
  final List<ReportBreakdownModel> byType;
  final List<ReportBreakdownModel> byService;
  final List<PaymentMixModel> paymentMix;

  const ReportsModel({
    this.from,
    this.to,
    this.revenue = 0,
    this.revenueChange,
    this.collected = 0,
    this.collectedPercent,
    this.outstanding = 0,
    this.expenses = 0,
    this.expensesChange,
    this.netProfit = 0,
    this.netProfitChange,
    this.margin,
    this.orderCount = 0,
    this.averageOrderValue = 0,
    this.monthlySeries = const [],
    this.byStatus = const [],
    this.byType = const [],
    this.byService = const [],
    this.paymentMix = const [],
  });

  static double? _optionalDouble(dynamic value) =>
      value == null ? null : (value as num).toDouble();

  static List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) =>
      ((raw as List?) ?? const [])
          .map((e) => parse((e as Map).cast<String, dynamic>()))
          .toList();

  factory ReportsModel.fromJson(Map<String, dynamic> json) => ReportsModel(
        from: DateTime.tryParse(json['from'] ?? ''),
        to: DateTime.tryParse(json['to'] ?? ''),
        revenue: (json['revenue'] ?? 0).toDouble(),
        revenueChange: _optionalDouble(json['revenue_change']),
        collected: (json['collected'] ?? 0).toDouble(),
        collectedPercent: _optionalDouble(json['collected_percent']),
        outstanding: (json['outstanding'] ?? 0).toDouble(),
        expenses: (json['expenses'] ?? 0).toDouble(),
        expensesChange: _optionalDouble(json['expenses_change']),
        netProfit: (json['net_profit'] ?? 0).toDouble(),
        netProfitChange: _optionalDouble(json['net_profit_change']),
        margin: _optionalDouble(json['margin']),
        orderCount: (json['order_count'] ?? 0).toInt(),
        averageOrderValue: (json['average_order_value'] ?? 0).toDouble(),
        monthlySeries: _list(json['monthly_series'], ReportMonthModel.fromJson),
        byStatus: _list(json['by_status'], ReportBreakdownModel.fromJson),
        byType: _list(json['by_type'], ReportBreakdownModel.fromJson),
        byService: _list(json['by_service'], ReportBreakdownModel.fromJson),
        paymentMix: _list(json['payment_mix'], PaymentMixModel.fromJson),
      );

  /// "▲ 12% vs last period" / "▼ 8% vs last period", or null when there was no
  /// preceding period to compare against.
  static String? changeLabel(double? change) {
    if (change == null) return null;
    final arrow = change >= 0 ? '▲' : '▼';
    return '$arrow ${change.abs().toStringAsFixed(change.abs() % 1 == 0 ? 0 : 1)}% vs last period';
  }
}

/// A bookable pickup or delivery window.
///
/// [capacity] is the max orders per day for the slot; null means unlimited.
class TimeSlotModel {
  static const pickup = 'PICKUP';
  static const delivery = 'DELIVERY';

  final String id;
  final String kind;
  final String startTime;
  final String endTime;
  final int? capacity;
  final bool isActive;
  final String label;

  const TimeSlotModel({
    required this.id,
    required this.kind,
    required this.startTime,
    required this.endTime,
    this.capacity,
    this.isActive = true,
    this.label = '',
  });

  String get capacityLabel => capacity == null ? 'Unlimited' : '$capacity';

  /// "9:00 AM - 11:00 AM". The server's [label] can't be used for the slot row
  /// because it carries the kind prefix ("Pickup 09:00 AM - 11:00 AM").
  String get timeRangeLabel => '${formatTime(startTime)} - ${formatTime(endTime)}';

  /// "09:00:00" (Django `TimeField`) -> "9:00 AM".
  static String formatTime(String apiTime) {
    final parts = apiTime.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '');
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '');
    if (hour == null || minute == null) return apiTime;
    final suffix = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// "9:00 AM" -> "09:00:00". Returns null if [display] isn't a 12-hour time.
  static String? parseTime(String display) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(display.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!) % 12;
    if (match.group(3)!.toUpperCase() == 'PM') hour += 12;
    return '${hour.toString().padLeft(2, '0')}:${match.group(2)}:00';
  }

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) => TimeSlotModel(
        id: json['id'].toString(),
        kind: json['kind'] ?? pickup,
        startTime: json['start_time'] ?? '',
        endTime: json['end_time'] ?? '',
        capacity: json['capacity'],
        isActive: json['is_active'] ?? true,
        label: json['label'] ?? '',
      );
}
