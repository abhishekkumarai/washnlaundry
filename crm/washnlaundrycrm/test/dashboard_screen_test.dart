import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/dashboard_screen.dart';

/// Until this file, `DashboardScreen` and every side panel it composes
/// (`NeedsAttentionCard`, `OrderChannelsCard`,
/// `StaffAttendanceCard`, `StoreHealthCard`, `RevenueAnalyticsCard`) were
/// never pumped by any test — real code with zero automated coverage,
/// verified only by hand against the live app per `wip.md`.
Widget host(AppProvider provider, {Size size = const Size(1600, 1200)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
}

OrderModel order(String number, {double total = 500}) => OrderModel(
      id: number,
      orderNumber: number,
      customerName: 'Someone',
      customerPhone: '9000000000',
      status: OrderStatus.placed,
      paymentStatus: PaymentStatus.unpaid,
      paymentMethod: 'CASH',
      totalAmount: total,
      paidAmount: 0,
      dueAmount: total,
      express: false,
      createdAt: DateTime(2026, 8, 1),
      items: const [],
    );

const fullStats = {
  'orders_today': 3,
  'revenue_today': 1250,
  'ready_for_pickup': 4,
  'overdue': 2,
  'customers_total': 57,
  'customers_new_today': 6,
  'orders_today_change': 12.0,
  'revenue_today_change': -8.0,
  'pipeline': {
    'received': 2,
    'processing': 3,
    'ready': 4,
    'out_for_delivery': 1,
  },
  'revenue_series': [
    {'date': '2026-07-30', 'day': 30, 'amount': 400.0},
    {'date': '2026-07-31', 'day': 31, 'amount': 620.0},
    {'date': '2026-08-01', 'day': 1, 'amount': 0.0},
  ],
  'needs_attention': {
    'scheduled_ahead': 3,
    'overdue_orders': 2,
    'unpaid_invoices': 4,
    'unpaid_outstanding': 5400,
    'online_orders': 6,
  },
  'order_channels': {
    'store_pickup': 5,
    'home_pickup': 2,
    'home_delivery': 3,
    'online': 1,
  },
  'staff_attendance': {
    'present': 4,
    'absent': 1,
    'leave': 1,
    'total_staff': 6,
  },
  'store_health': {
    'score': 82,
    'verdict': 'Excellent',
    'active_on_schedule': 9,
    'on_time_delivery': 96.0,
    'on_time_pickup': 91.0,
    'order_flow': 88.0,
    'collection_rate': 74.5,
  },
  'revenue_analytics': {
    'collection_progress': 68.0,
    'net_profit': 12500.0,
    'collected': 20000,
    'uncollected': 9400,
    'sales': 29400,
    'expenses': 8900,
  },
};

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(1900, 1600);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('DashboardScreen', () {
    testWidgets('renders every panel on a wide viewport', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [order('WASH-00001'), order('WASH-00002')], stats: fullStats);
      await tester.pumpWidget(host(provider));
      await tester.pump();

      expect(find.text('Quick Scan & Search'), findsNothing);
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Order channels'), findsOneWidget);
      expect(find.text('Staff attendance'), findsOneWidget);
      expect(find.text('Store Health'), findsOneWidget);
      expect(find.text('Revenue Analytics'), findsOneWidget);
      expect(find.text('Total staff: 6'), findsOneWidget);
      expect(find.text('9 active orders on schedule'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stacks into one column below the two-column breakpoint',
        (tester) async {
      // 1200 keeps the sidebar at its full 240px (>=1080 total), so this
      // isolates the dashboard's own 990px content-width breakpoint from the
      // sidebar's separate icon-rail breakpoint (`widget_test.dart` already
      // covers that one) — content width here is 1200-240=960, just under it.
      final view =
          TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
      view.physicalSize = const Size(1200, 1600);
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [order('WASH-00001')], stats: fullStats);
      await tester.pumpWidget(host(provider, size: const Size(1200, 1600)));
      await tester.pump();

      // Same content, just laid out in a single column below the breakpoint.
      expect(find.text('Store Health'), findsOneWidget);
      expect(find.text('Revenue Analytics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a missing nested stat block falls back to zeros, not a crash',
        (tester) async {
      // Every side panel defaults its own `Map<String, dynamic>?` cast to
      // `const {}` — this is what exercises that fallback for real, rather
      // than assuming the `as Map?` cast is safe.
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: const [], stats: const {'orders_today': 0});
      await tester.pumpWidget(host(provider));
      await tester.pump();

      expect(find.text('Total staff: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed load shows Retry, not a blank dashboard', (tester) async {
      // There is no server reachable in this test environment (same gap
      // noted throughout this suite for order/customer/expense creation), so
      // `loadDataFromBackend` always ends in its `catch` branch here — this
      // proves the screen survives that with an actionable error state
      // rather than crashing or hanging. The transient loading spinner in
      // between isn't asserted: the failure resolves within the same
      // microtask flush a single `pump()` performs, the same reason
      // `payroll_test.dart`'s History dialog only checks the settled state.
      final provider = AppProvider(autoLoad: false);
      await tester.pumpWidget(host(provider));
      await provider.loadDataFromBackend();
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow width: panels default expanded and collapse on tap',
        (tester) async {
      final view = TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!;
      view.physicalSize = const Size(700, 3200);
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [order('WASH-00001')], stats: fullStats);
      await tester.pumpWidget(host(provider, size: const Size(700, 3200)));
      await tester.pump();

      // Below DashboardScreen's own 990px breakpoint, panels render
      // collapsible and start expanded — same content visible as wide width.
      // The viewport is made tall enough that every panel, including the
      // single-column-stacked Store Health card, is on-screen without
      // needing a scroll first.
      expect(find.text('9 active orders on schedule'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsWidgets);

      await tester.tap(find.text('Store Health'));
      await tester.pump();
      expect(find.text('9 active orders on schedule'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Store Health'));
      await tester.pump();
      expect(find.text('9 active orders on schedule'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'wide width: panels are not collapsible — tapping the title does nothing',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [order('WASH-00001')], stats: fullStats);
      await tester.pumpWidget(host(provider));
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);

      await tester.tap(find.text('Store Health'));
      await tester.pump();
      expect(find.text('9 active orders on schedule'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'narrow width: scroll-to-top appears after scrolling and returns to the top',
        (tester) async {
      final view = TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!;
      view.physicalSize = const Size(700, 1600);
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [order('WASH-00001')], stats: fullStats);
      await tester.pumpWidget(host(provider, size: const Size(700, 1600)));
      await tester.pump();

      final fab = find.byKey(const Key('dashboard_scroll_to_top'));
      expect(fab, findsNothing);

      await tester.drag(
          find.byKey(const Key('dashboard_scroll_view')), const Offset(0, -600));
      await tester.pump();
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard_scroll_to_top')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wide width: scroll-to-top never appears even after scrolling',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [order('WASH-00001')], stats: fullStats);
      await tester.pumpWidget(host(provider));
      await tester.pump();

      await tester.drag(
          find.byKey(const Key('dashboard_scroll_view')), const Offset(0, -600));
      await tester.pump();

      expect(find.byKey(const Key('dashboard_scroll_to_top')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
