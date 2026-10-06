import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';

OrderModel order({
  String id = '1',
  String number = 'WA3P-00001',
  String name = 'Customer',
  String phone = '9000000000',
  String status = OrderStatus.placed,
  String payment = PaymentStatus.unpaid,
  bool overdue = false,
  DateTime? scheduled,
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
    paidAmount: 0,
    dueAmount: 100,
    express: false,
    isOverdue: overdue,
    scheduledDate: scheduled,
    createdAt: DateTime(2026, 7, 29),
    items: const [],
  );
}

void main() {
  late AppProvider provider;

  setUp(() {
    provider = AppProvider(autoLoad: false);
  });

  test('does not hit the network when autoLoad is false', () {
    expect(provider.orders, isEmpty);
    expect(provider.hasError, isFalse);
  });

  group('status counters use the canonical vocabulary', () {
    setUp(() {
      provider.seedForTest(orders: [
        order(id: '1', status: OrderStatus.placed),
        order(id: '2', status: OrderStatus.processing),
        order(id: '3', status: OrderStatus.ironing),
        order(id: '4', status: OrderStatus.ready),
        order(id: '5', status: OrderStatus.outForDelivery),
        order(id: '6', status: OrderStatus.delivered),
      ]);
    });

    test('received counts placed orders', () {
      expect(provider.receivedCount, 1);
    });

    test('processing folds in ironing, as the live pipeline does', () {
      expect(provider.processingCount, 2);
    });

    test('ready, out for delivery and delivered are distinct', () {
      expect(provider.readyCount, 1);
      expect(provider.outForDeliveryCount, 1);
      expect(provider.deliveredCount, 1);
    });
  });

  group('ordersForFilter', () {
    late DateTime today;

    setUp(() {
      today = DateTime.now();
      provider.seedForTest(orders: [
        order(id: '1', status: OrderStatus.placed, payment: PaymentStatus.unpaid),
        order(
          id: '2',
          status: OrderStatus.processing,
          payment: PaymentStatus.paid,
          overdue: true,
        ),
        order(
          id: '3',
          status: OrderStatus.placed,
          payment: PaymentStatus.paid,
          scheduled: today.add(const Duration(days: 3)),
        ),
        order(id: '4', status: OrderStatus.delivered, payment: PaymentStatus.partial),
        order(id: '5', status: OrderStatus.cancelled, payment: PaymentStatus.paid),
      ]);
    });

    test('ALL returns everything', () {
      expect(provider.ordersForFilter('ALL'), hasLength(5));
    });

    test('OVERDUE is derived from the flag, not a stored status', () {
      final result = provider.ordersForFilter('OVERDUE');
      expect(result.map((o) => o.id), ['2']);
    });

    test('SCHEDULED finds future-dated open orders', () {
      final result = provider.ordersForFilter('SCHEDULED');
      expect(result.map((o) => o.id), ['3']);
    });

    test('SCHEDULED excludes delivered and cancelled orders', () {
      provider.seedForTest(orders: [
        order(
          id: '9',
          status: OrderStatus.delivered,
          scheduled: today.add(const Duration(days: 5)),
        ),
      ]);
      expect(provider.ordersForFilter('SCHEDULED'), isEmpty);
    });

    test('UNPAID and PARTIAL filter on payment status', () {
      expect(provider.ordersForFilter('UNPAID').map((o) => o.id), ['1']);
      expect(provider.ordersForFilter('PARTIAL').map((o) => o.id), ['4']);
    });

    test('a stored status filters directly', () {
      expect(provider.ordersForFilter('CANCELLED').map((o) => o.id), ['5']);
    });

    test('filters are case insensitive', () {
      expect(provider.ordersForFilter('cancelled'), hasLength(1));
    });
  });

  group('search', () {
    setUp(() {
      provider.seedForTest(orders: [
        order(id: '1', number: 'WA3P-00001', name: 'Aditya', phone: '9876543210'),
        order(id: '2', number: 'WA3P-00002', name: 'Rohan', phone: '9811223344'),
      ]);
    });

    test('empty query returns everything', () {
      expect(provider.filteredOrders, hasLength(2));
    });

    test('matches on customer name, case insensitively', () {
      provider.setSearchQuery('aditya');
      expect(provider.filteredOrders.map((o) => o.id), ['1']);
    });

    test('matches on order number', () {
      provider.setSearchQuery('WA3P-00002');
      expect(provider.filteredOrders.map((o) => o.id), ['2']);
    });

    test('matches on phone', () {
      provider.setSearchQuery('9811');
      expect(provider.filteredOrders.map((o) => o.id), ['2']);
    });

    test('no match returns empty', () {
      provider.setSearchQuery('zzz');
      expect(provider.filteredOrders, isEmpty);
    });
  });

  test('nav index changes notify listeners', () {
    var notified = 0;
    provider.addListener(() => notified++);
    provider.setNavIndex(4);
    expect(provider.currentNavIndex, 4);
    expect(notified, 1);
  });

  test('overdue count reads the server flag', () {
    provider.seedForTest(orders: [
      order(id: '1', overdue: true),
      order(id: '2', overdue: false),
    ]);
    expect(provider.overdueCount, 1);
  });
}
