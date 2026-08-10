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

  const GarmentItemModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.price,
    this.unit = PricingUnit.piece,
    this.turnaroundDays = 1,
    this.isActive = true,
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
    );
  }
}

class GarmentCategoryModel {
  final String id;
  final String name;
  final String icon;
  final int displayOrder;
  final bool isActive;
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
    this.itemCount = 0,
    this.minPrice = 0,
    this.maxPrice = 0,
    this.items = const [],
  });

  /// "10–100 ₹", as the live Services screen renders it.
  String get priceRangeLabel =>
      '${minPrice.toStringAsFixed(0)}–${maxPrice.toStringAsFixed(0)} ₹';

  factory GarmentCategoryModel.fromJson(Map<String, dynamic> json) {
    final range = json['price_range'] as Map<String, dynamic>? ?? const {};
    final rawItems = json['items'] as List? ?? const [];
    return GarmentCategoryModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      icon: json['icon'] ?? 'Shirt',
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
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
  final double dailyWage;
  final String status;
  final bool isDeliveryAgent;
  final bool hasAppLogin;

  const StaffModel({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    this.dailyWage = 0,
    this.status = 'ACTIVE',
    this.isDeliveryAgent = false,
    this.hasAppLogin = false,
  });

  bool get isActive => status == 'ACTIVE';

  factory StaffModel.fromJson(Map<String, dynamic> json) => StaffModel(
        id: json['id'].toString(),
        name: json['name'] ?? '',
        role: json['role'] ?? '',
        phone: json['phone'] ?? '',
        dailyWage: (json['daily_wage'] ?? 0).toDouble(),
        status: json['status'] ?? 'ACTIVE',
        isDeliveryAgent: json['is_delivery_agent'] ?? false,
        hasAppLogin: json['has_app_login'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'phone': phone,
        'daily_wage': dailyWage,
        'status': status,
        'is_delivery_agent': isDeliveryAgent,
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
