import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/models/order_model.dart';

void main() {
  group('PricingUnit', () {
    test('labels every unit the live catalogue uses', () {
      expect(PricingUnit.label(PricingUnit.piece), 'per pc');
      expect(PricingUnit.label(PricingUnit.kg), 'per kg');
      expect(PricingUnit.label(PricingUnit.sqft), 'per sq.ft');
      expect(PricingUnit.label(PricingUnit.set), 'per set');
    });

    test('falls back to per pc for unknown units', () {
      expect(PricingUnit.label('WAT'), 'per pc');
    });

    test('short labels are used on price tags', () {
      expect(PricingUnit.shortLabel(PricingUnit.sqft), 'sq.ft');
      expect(PricingUnit.shortLabel(PricingUnit.kg), 'kg');
    });
  });

  group('GarmentItemModel', () {
    test('parses a catalogue row', () {
      final item = GarmentItemModel.fromJson({
        'id': 1,
        'category': 3,
        'category_name': 'Ironing',
        'name': 'Shirt',
        'price': 15.0,
        'unit': 'PC',
        'turnaround_days': 2,
        'is_active': true,
      });

      expect(item.id, '1');
      expect(item.categoryName, 'Ironing');
      expect(item.price, 15.0);
      expect(item.unitLabel, 'per pc');
      expect(item.turnaroundLabel, '2d');
    });

    test('parses a per-kg item', () {
      final item = GarmentItemModel.fromJson({
        'id': 24,
        'name': 'Regular Cloths (Per Kg)',
        'price': 85,
        'unit': 'KG',
      });

      expect(item.price, 85.0);
      expect(item.unitShortLabel, 'kg');
    });

    test('tolerates a sparse payload', () {
      final item = GarmentItemModel.fromJson({'id': 9, 'name': 'Mystery'});
      expect(item.price, 0.0);
      expect(item.unit, PricingUnit.piece);
      expect(item.isActive, isTrue);
    });
  });

  group('GarmentCategoryModel', () {
    test('renders the price range the Services screen shows', () {
      final category = GarmentCategoryModel.fromJson({
        'id': 1,
        'name': 'Ironing',
        'item_count': 23,
        'price_range': {'min': 10, 'max': 100},
        'items': const [],
      });

      expect(category.itemCount, 23);
      expect(category.priceRangeLabel, '10–100 ₹');
    });

    test('parses nested items', () {
      final category = GarmentCategoryModel.fromJson({
        'id': 1,
        'name': 'Household',
        'items': [
          {'id': 1, 'name': 'Carpet (Vacuum)', 'price': 15, 'unit': 'SQFT'},
        ],
      });

      expect(category.items, hasLength(1));
      expect(category.items.first.unitShortLabel, 'sq.ft');
    });
  });

  group('OrderStatus', () {
    test('progression matches the live step bar', () {
      expect(OrderStatus.progression, [
        'PLACED',
        'PROCESSING',
        'IRONING',
        'READY',
        'OUT_FOR_DELIVERY',
        'DELIVERED',
      ]);
    });

    test('cancelled is outside the progression', () {
      expect(OrderStatus.progression, isNot(contains(OrderStatus.cancelled)));
    });

    test('labels are human readable', () {
      expect(OrderStatus.label(OrderStatus.outForDelivery), 'Out for Delivery');
      expect(OrderStatus.label(OrderStatus.ironing), 'Ironing');
    });

    test('unknown statuses pass through rather than crashing', () {
      expect(OrderStatus.label('WASHING'), 'WASHING');
    });
  });

  group('OrderModel', () {
    Map<String, dynamic> payload({
      String status = 'READY',
      Map<String, dynamic> extra = const {},
    }) =>
        {
          'id': 'abc',
          'order_number': 'WA3P-00001',
          'customer_name': 'Me',
          'customer_phone': '+914277905904',
          'status': status,
          'payment_status': 'UNPAID',
          'payment_method': 'CASH',
          'delivery_type': 'HOME_DELIVERY',
          'source': 'MOBILE_APP',
          'subtotal': 200.0,
          'delivery_charge': 50.0,
          'total_amount': 250.0,
          'paid_amount': 0.0,
          'due_amount': 250.0,
          'express': false,
          'is_overdue': false,
          'created_at': '2026-07-29T10:20:00Z',
          'placed_at': '2026-07-29T10:20:00Z',
          'processing_at': '2026-07-29T10:21:00Z',
          'ready_at': '2026-07-29T10:21:30Z',
          'items': [
            {
              'item_title': 'Sports Shoes',
              'service_type': 'Shoe Cleaning',
              'status': 'READY',
              'quantity': 1,
              'unit': 'PC',
              'unit_price': 200.0,
              'total_price': 200.0,
            }
          ],
          ...extra,
        };

    test('parses money fields including the delivery charge', () {
      final order = OrderModel.fromJson(payload());
      expect(order.subtotal, 200.0);
      expect(order.deliveryCharge, 50.0);
      expect(order.totalAmount, 250.0);
    });

    test('exposes readable labels', () {
      final order = OrderModel.fromJson(payload());
      expect(order.statusLabel, 'Ready');
      expect(order.deliveryTypeLabel, 'Home Delivery');
      expect(order.sourceLabel, 'Mobile App');
      expect(order.paymentStatusLabel, 'Unpaid');
    });

    test('builds the timeline from stage stamps, oldest first', () {
      final order = OrderModel.fromJson(payload());
      expect(order.timeline.map((e) => e.status).toList(),
          ['PLACED', 'PROCESSING', 'READY']);
    });

    test('omits stages that were never reached', () {
      final order = OrderModel.fromJson(payload());
      expect(order.stageTimestamps.containsKey(OrderStatus.delivered), isFalse);
    });

    test('progressIndex tracks the step bar', () {
      expect(OrderModel.fromJson(payload()).progressIndex, 3);
      expect(
        OrderModel.fromJson(payload(status: 'PLACED')).progressIndex,
        0,
      );
    });

    test('cancelled orders sit outside the progression', () {
      final order = OrderModel.fromJson(
        payload(status: 'CANCELLED', extra: {'cancelled_at': '2026-07-29T11:00:00Z'}),
      );
      expect(order.isCancelled, isTrue);
      expect(order.progressIndex, -1);
    });

    test('parses nested items with their unit and per-item status', () {
      final item = OrderModel.fromJson(payload()).items.single;
      expect(item.itemTitle, 'Sports Shoes');
      expect(item.status, OrderStatus.ready);
      expect(item.unitShortLabel, 'pc');
      expect(item.totalPrice, 200.0);
    });

    test('reads the server-computed overdue flag', () {
      final order = OrderModel.fromJson(payload(extra: {'is_overdue': true}));
      expect(order.isOverdue, isTrue);
    });

    test('survives a minimal payload', () {
      final order = OrderModel.fromJson({'id': 'x', 'customer_name': 'A'});
      expect(order.status, OrderStatus.placed);
      expect(order.items, isEmpty);
      expect(order.timeline, isEmpty);
    });
  });

  group('CustomerModel', () {
    test('parses lifetime metrics', () {
      final customer = CustomerModel.fromJson({
        'id': 'c1',
        'name': 'Me',
        'phone': '+914277905904',
        'area': 'HBR Layout',
        'total_orders': 4,
        'total_spent': 1000.0,
        'avg_order_value': 250.0,
      });

      expect(customer.area, 'HBR Layout');
      expect(customer.avgOrderValue, 250.0);
    });
  });

  group('TimeSlotModel', () {
    test('null capacity reads as Unlimited', () {
      final slot = TimeSlotModel.fromJson({
        'id': 1,
        'kind': 'PICKUP',
        'start_time': '09:00:00',
        'end_time': '11:00:00',
        'capacity': null,
      });
      expect(slot.capacityLabel, 'Unlimited');
    });

    test('capacity is surfaced when set', () {
      final slot = TimeSlotModel.fromJson({
        'id': 2,
        'kind': 'DELIVERY',
        'start_time': '14:00:00',
        'end_time': '16:00:00',
        'capacity': 20,
      });
      expect(slot.capacityLabel, '20');
    });
  });
}
