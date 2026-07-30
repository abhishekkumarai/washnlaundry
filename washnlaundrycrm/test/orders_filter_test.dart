import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';

OrderModel order({
  required String id,
  String number = 'WASH-00001',
  String name = 'Customer',
  String phone = '9000000000',
  String status = OrderStatus.placed,
  String payment = PaymentStatus.paid,
  bool overdue = false,
  DateTime? scheduled,
  DateTime? created,
}) {
  return OrderModel(
    id: id,
    orderNumber: number,
    customerName: name,
    customerPhone: phone,
    status: status,
    paymentStatus: payment,
    paymentMethod: 'CASH',
    totalAmount: 100,
    paidAmount: 100,
    dueAmount: 0,
    express: false,
    isOverdue: overdue,
    scheduledDate: scheduled,
    createdAt: created ?? DateTime.now(),
    items: const [],
  );
}

void main() {
  final now = DateTime.now();

  group('every filter chip maps to a distinct set', () {
    late AppProvider provider;

    setUp(() {
      provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [
          order(id: 'placed', status: OrderStatus.placed),
          order(id: 'processing', status: OrderStatus.processing),
          order(id: 'ironing', status: OrderStatus.ironing),
          order(id: 'ready', status: OrderStatus.ready),
          order(id: 'ofd', status: OrderStatus.outForDelivery),
          order(id: 'delivered', status: OrderStatus.delivered),
          order(id: 'cancelled', status: OrderStatus.cancelled),
          order(id: 'partial', payment: PaymentStatus.partial),
          order(id: 'unpaid', payment: PaymentStatus.unpaid),
          order(id: 'overdue', status: OrderStatus.processing, overdue: true),
          order(
            id: 'scheduled',
            status: OrderStatus.placed,
            scheduled: now.add(const Duration(days: 3)),
          ),
        ]);
    });

    List<String> ids(String filter) =>
        provider.ordersFor(filter: filter).map((o) => o.id).toList();

    test('ALL returns everything', () {
      expect(ids('ALL'), hasLength(11));
    });

    test('PLACED does not also return processing orders', () {
      // The old screen tested for PENDING/WASHING and lumped the two together.
      final result = ids(OrderStatus.placed);
      expect(result, contains('placed'));
      expect(result, isNot(contains('processing')));
    });

    test('PROCESSING excludes placed and ironing', () {
      final result = ids(OrderStatus.processing);
      expect(result, contains('processing'));
      expect(result, isNot(contains('placed')));
      expect(result, isNot(contains('ironing')));
    });

    test('READY, DELIVERED and CANCELLED each match only themselves', () {
      expect(ids(OrderStatus.ready), ['ready']);
      expect(ids(OrderStatus.delivered), ['delivered']);
      expect(ids(OrderStatus.cancelled), ['cancelled']);
    });

    test('OUT_FOR_DELIVERY is filterable at all', () {
      // Previously this chip had no branch and returned every order.
      expect(ids(OrderStatus.outForDelivery), ['ofd']);
    });

    test('PARTIAL and UNPAID filter on payment, not status', () {
      expect(ids('PARTIAL'), ['partial']);
      expect(ids('UNPAID'), ['unpaid']);
    });

    test('OVERDUE and SCHEDULED are derived', () {
      expect(ids('OVERDUE'), ['overdue']);
      expect(ids('SCHEDULED'), ['scheduled']);
    });

    test('no chip silently returns the whole list', () {
      for (final filter in [
        OrderStatus.placed,
        OrderStatus.processing,
        OrderStatus.ready,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
        OrderStatus.cancelled,
        'PARTIAL',
        'OVERDUE',
        'SCHEDULED',
        'UNPAID',
      ]) {
        expect(ids(filter).length, lessThan(11), reason: '$filter matched everything');
      }
    });
  });

  group('date ranges', () {
    final reference = DateTime(2026, 7, 15, 12); // a Wednesday

    test('all time accepts anything', () {
      expect(
        OrderDateRange.allTime.contains(DateTime(2020, 1, 1), now: reference),
        isTrue,
      );
    });

    test('today matches only the same calendar day', () {
      expect(
        OrderDateRange.today.contains(DateTime(2026, 7, 15, 1), now: reference),
        isTrue,
      );
      expect(
        OrderDateRange.today.contains(DateTime(2026, 7, 14, 23), now: reference),
        isFalse,
      );
    });

    test('this week runs Monday to today', () {
      expect(
        OrderDateRange.thisWeek.contains(DateTime(2026, 7, 13), now: reference),
        isTrue,
        reason: 'Monday of the current week',
      );
      expect(
        OrderDateRange.thisWeek.contains(DateTime(2026, 7, 12), now: reference),
        isFalse,
        reason: 'previous Sunday',
      );
    });

    test('this month and last month do not overlap', () {
      final date = DateTime(2026, 6, 20);
      expect(OrderDateRange.thisMonth.contains(date, now: reference), isFalse);
      expect(OrderDateRange.lastMonth.contains(date, now: reference), isTrue);
    });

    test('last month handles the January boundary', () {
      final january = DateTime(2026, 1, 10);
      expect(
        OrderDateRange.lastMonth.contains(DateTime(2025, 12, 5), now: january),
        isTrue,
      );
    });

    test('labels match the live dropdown', () {
      expect(
        OrderDateRange.values.map((r) => r.label),
        ['All time', 'Today', 'This Week', 'This Month', 'Last Month'],
      );
    });

    test('fromLabel round-trips and falls back safely', () {
      expect(OrderDateRange.fromLabel('This Week'), OrderDateRange.thisWeek);
      expect(OrderDateRange.fromLabel('nonsense'), OrderDateRange.allTime);
    });
  });

  group('filters combine', () {
    test('chip, range and search are all applied together', () {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [
          order(
            id: 'match',
            number: 'WASH-00042',
            name: 'Aditya Sharma',
            status: OrderStatus.ready,
            created: now,
          ),
          order(
            id: 'wrong-status',
            number: 'WASH-00043',
            name: 'Aditya Sharma',
            status: OrderStatus.delivered,
            created: now,
          ),
          order(
            id: 'wrong-name',
            number: 'WASH-00044',
            name: 'Rohan Verma',
            status: OrderStatus.ready,
            created: now,
          ),
          order(
            id: 'too-old',
            number: 'WASH-00045',
            name: 'Aditya Sharma',
            status: OrderStatus.ready,
            created: now.subtract(const Duration(days: 400)),
          ),
        ]);

      final result = provider.ordersFor(
        filter: OrderStatus.ready,
        range: OrderDateRange.today,
        search: 'aditya',
      );

      expect(result.map((o) => o.id), ['match']);
    });

    test('search matches order number and phone too', () {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [
          order(id: 'a', number: 'WASH-00042', phone: '9811223344'),
          order(id: 'b', number: 'WASH-00099', phone: '9000000000'),
        ]);

      expect(provider.ordersFor(search: '00042').map((o) => o.id), ['a']);
      expect(provider.ordersFor(search: '9811').map((o) => o.id), ['a']);
    });

    test('search is trimmed and case insensitive', () {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [order(id: 'a', name: 'Priya Sundaram')]);

      expect(provider.ordersFor(search: '  PRIYA  ').map((o) => o.id), ['a']);
    });
  });
}
