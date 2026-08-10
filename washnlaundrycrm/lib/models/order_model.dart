import 'garment_model.dart';

/// Canonical order statuses. Mirrors `OrderStatus` in the backend, which in
/// turn mirrors app.laundrybill.com. Never compare against ad-hoc strings —
/// use these constants so the three layers can't drift apart again.
class OrderStatus {
  static const placed = 'PLACED';
  static const processing = 'PROCESSING';
  static const ironing = 'IRONING';
  static const ready = 'READY';
  static const outForDelivery = 'OUT_FOR_DELIVERY';
  static const delivered = 'DELIVERED';
  static const cancelled = 'CANCELLED';

  /// The happy path, in order. Used by the order-detail step bar.
  static const progression = [
    placed,
    processing,
    ironing,
    ready,
    outForDelivery,
    delivered,
  ];

  static const labels = {
    placed: 'Placed',
    processing: 'Processing',
    ironing: 'Ironing',
    ready: 'Ready',
    outForDelivery: 'Out for Delivery',
    delivered: 'Delivered',
    cancelled: 'Cancelled',
  };

  static String label(String status) => labels[status] ?? status;
}

class PaymentStatus {
  static const paid = 'PAID';
  static const partial = 'PARTIAL';
  static const unpaid = 'UNPAID';

  static const labels = {paid: 'Paid', partial: 'Partial', unpaid: 'Unpaid'};

  static String label(String status) => labels[status] ?? status;
}

class DeliveryType {
  static const storePickup = 'STORE_PICKUP';
  static const homePickup = 'HOME_PICKUP';
  static const homeDelivery = 'HOME_DELIVERY';
  static const online = 'ONLINE';

  static const labels = {
    storePickup: 'Store Pickup',
    homePickup: 'Home Pickup',
    homeDelivery: 'Home Delivery',
    online: 'Online',
  };

  static String label(String type) => labels[type] ?? type;
}

class OrderSource {
  static const labels = {
    'WEB': 'Web Dashboard',
    'MOBILE_APP': 'Mobile App',
    'PUBLIC_PAGE': 'Public Page',
    'STAFF_APP': 'Staff App',
    'AGENT_APP': 'Agent App',
  };

  static String label(String source) => labels[source] ?? source;
}

/// A single stage stamp, for the order-detail timeline.
class TimelineEntry {
  final String status;
  final DateTime at;

  const TimelineEntry(this.status, this.at);

  String get label => OrderStatus.label(status);
}

class OrderItemModel {
  final String itemTitle;
  final String serviceType;
  final String status;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;

  const OrderItemModel({
    required this.itemTitle,
    required this.serviceType,
    this.status = OrderStatus.placed,
    required this.quantity,
    this.unit = PricingUnit.piece,
    required this.unitPrice,
    required this.totalPrice,
  });

  String get unitShortLabel => PricingUnit.shortLabel(unit);

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      itemTitle: json['item_title'] ?? 'Garment Item',
      serviceType: json['service_type'] ?? '',
      status: json['status'] ?? OrderStatus.placed,
      quantity: json['quantity'] ?? 1,
      unit: json['unit'] ?? PricingUnit.piece,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'item_title': itemTitle,
        'service_type': serviceType,
        'status': status,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'total_price': totalPrice,
      };
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;

  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final String deliveryType;
  final String source;

  final double subtotal;
  final double deliveryCharge;
  final double discountAmount;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;

  final bool express;
  final bool isOverdue;
  final String? notes;
  final DateTime? scheduledDate;
  final String? assignedAgentName;

  /// Who or what raised the order — a person for a counter sale, a channel
  /// name otherwise. Empty falls back to [sourceLabel]; see [createdByLabel].
  final String createdBy;

  final DateTime createdAt;
  final Map<String, DateTime> stageTimestamps;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    this.customerId = '',
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    this.deliveryType = DeliveryType.storePickup,
    this.source = 'WEB',
    this.subtotal = 0,
    this.deliveryCharge = 0,
    this.discountAmount = 0,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueAmount,
    required this.express,
    this.isOverdue = false,
    this.notes,
    this.scheduledDate,
    this.assignedAgentName,
    this.createdBy = '',
    required this.createdAt,
    this.stageTimestamps = const {},
    required this.items,
  });

  String get statusLabel => OrderStatus.label(status);
  String get paymentStatusLabel => PaymentStatus.label(paymentStatus);
  String get deliveryTypeLabel => DeliveryType.label(deliveryType);
  String get sourceLabel => OrderSource.label(source);

  /// What the timeline writes after "Created by".
  String get createdByLabel => createdBy.trim().isEmpty ? sourceLabel : createdBy.trim();

  /// True when nobody delivers this order — the customer collects it.
  /// Drives the step-bar wording and which fulfilment panel is shown.
  bool get isCollectedInStore =>
      deliveryType == DeliveryType.storePickup || deliveryType == DeliveryType.homePickup;

  /// The four stages the live step bar shows, in order. `Out for Delivery` is
  /// deliberately absent: the real app collapses it into the Timeline, and a
  /// collected order never passes through it at all.
  List<String> get stepStatuses => [
        OrderStatus.placed,
        OrderStatus.processing,
        OrderStatus.ready,
        OrderStatus.delivered,
      ];

  /// Step labels, which depend on who ends up holding the garments.
  List<String> get stepLabels => [
        'Order Placed',
        'Processing',
        isCollectedInStore ? 'Ready for Pickup' : 'Ready',
        isCollectedInStore ? 'Picked Up' : 'Delivered',
      ];

  /// Index into [stepLabels] of the furthest stage reached. -1 for cancelled,
  /// which sits outside the progression. `Ironing` counts as Processing and
  /// `Out for Delivery` as Ready, since neither has its own step.
  int get stepIndex {
    if (isCancelled) return -1;
    switch (status) {
      case OrderStatus.delivered:
        return 3;
      case OrderStatus.outForDelivery:
      case OrderStatus.ready:
        return 2;
      case OrderStatus.ironing:
      case OrderStatus.processing:
        return 1;
      default:
        return 0;
    }
  }

  bool get isCancelled => status == OrderStatus.cancelled;

  /// How far along the happy path this order is, for the step bar.
  /// Returns -1 for cancelled orders, which sit outside the progression.
  int get progressIndex =>
      isCancelled ? -1 : OrderStatus.progression.indexOf(status);

  /// Every stage this order has actually reached, oldest first.
  List<TimelineEntry> get timeline {
    final entries = stageTimestamps.entries
        .map((e) => TimelineEntry(e.key, e.value))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return entries;
  }

  static const _stageJsonKeys = {
    OrderStatus.placed: 'placed_at',
    OrderStatus.processing: 'processing_at',
    OrderStatus.ironing: 'ironing_at',
    OrderStatus.ready: 'ready_at',
    OrderStatus.outForDelivery: 'out_for_delivery_at',
    OrderStatus.delivered: 'delivered_at',
    OrderStatus.cancelled: 'cancelled_at',
  };

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];

    final stamps = <String, DateTime>{};
    _stageJsonKeys.forEach((status, key) {
      final parsed = DateTime.tryParse(json[key] ?? '');
      if (parsed != null) stamps[status] = parsed;
    });

    return OrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number'] ?? '',
      customerId: json['customer']?.toString() ?? '',
      customerName: json['customer_name'] ?? 'Customer',
      customerPhone: json['customer_phone'] ?? '',
      status: json['status'] ?? OrderStatus.placed,
      paymentStatus: json['payment_status'] ?? PaymentStatus.unpaid,
      paymentMethod: json['payment_method'] ?? 'CASH',
      deliveryType: json['delivery_type'] ?? DeliveryType.storePickup,
      source: json['source'] ?? 'WEB',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      deliveryCharge: (json['delivery_charge'] ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      dueAmount: (json['due_amount'] ?? 0).toDouble(),
      express: json['express'] ?? false,
      isOverdue: json['is_overdue'] ?? false,
      notes: json['notes'],
      scheduledDate: DateTime.tryParse(json['scheduled_date'] ?? ''),
      assignedAgentName: json['assigned_agent_name'],
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      stageTimestamps: stamps,
      items: rawItems
          .map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
