import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/widgets/order_tracking_card.dart';

Map<String, dynamic> _track({String status = 'EN_ROUTE'}) => {
      'tracking': true,
      'kind': 'DELIVERY',
      'status': status,
      'otp': status == 'COMPLETED' ? null : '4821',
      'pickup': {'lat': 25.5941, 'lng': 85.1376},
      'drop': {'lat': 25.61, 'lng': 85.16},
      'rider': {'name': 'Ravi', 'phone': '8888888888'},
      'location': {'lat': 25.60, 'lng': 85.15, 'at': '2026-10-15T01:00:00Z'},
    };

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('shows nothing when the order has no rider task', (t) async {
    await t.pumpWidget(_host(OrderTrackingCard(
        orderNumber: 'WA-1',
        showTiles: false,
        fetch: (_) async => {'tracking': false})));
    await t.pump();
    expect(find.byKey(const Key('order-tracking-card')), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('shows status, rider, OTP and a rider marker while en route',
      (t) async {
    await t.pumpWidget(_host(OrderTrackingCard(
        orderNumber: 'WA-1', showTiles: false, fetch: (_) async => _track())));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('On the way'), findsOneWidget);
    expect(find.text('Rider: Ravi'), findsOneWidget);
    expect(find.byKey(const Key('tracking-otp')), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
    expect(find.byKey(const Key('rider-marker')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('hides OTP and marker once completed, then stops polling',
      (t) async {
    var calls = 0;
    await t.pumpWidget(_host(OrderTrackingCard(
      orderNumber: 'WA-1',
      showTiles: false,
      pollInterval: const Duration(milliseconds: 100),
      fetch: (_) async => ++calls < 2 ? _track() : _track(status: 'COMPLETED'),
    )));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('rider-marker')), findsOneWidget);
    await t.pump(const Duration(milliseconds: 150));
    await t.pump();
    expect(calls, 2);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const Key('tracking-otp')), findsNothing);
    expect(find.byKey(const Key('rider-marker')), findsNothing);
    await t.pump(const Duration(milliseconds: 500));
    expect(calls, 2, reason: 'polling stops after completion');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a failed poll keeps the last good state and shows Reconnecting',
      (t) async {
    var calls = 0;
    await t.pumpWidget(_host(OrderTrackingCard(
      orderNumber: 'WA-1',
      showTiles: false,
      pollInterval: const Duration(milliseconds: 100),
      fetch: (_) async {
        if (++calls == 1) return _track();
        throw Exception('offline');
      },
    )));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    await t.pump();
    expect(find.text('Reconnecting…'), findsOneWidget);
    expect(find.byKey(const Key('rider-marker')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
