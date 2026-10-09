import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/scan_screen.dart';
import 'package:washnlaundrycrm/widgets/kpi_cards_row.dart';
import 'package:washnlaundrycrm/widgets/order_pipeline_card.dart';
import 'package:washnlaundrycrm/widgets/receipt_dialog.dart';
import 'package:washnlaundrycrm/widgets/revenue_chart_card.dart';
import 'package:washnlaundrycrm/widgets/sidebar_navigation.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: Scaffold(body: child)),
    );

OrderModel order(String number, {double total = 100}) => OrderModel(
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

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(1600, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('KPI cards', () {
    // The stats deliberately disagree with the seeded orders. That is the only
    // way the old bug is visible: "Orders today" used to render the length of
    // the whole order list and "Revenue today" the sum of every order ever
    // billed.
    final stats = {
      'orders_today': 3,
      'revenue_today': 1250,
      'ready_for_pickup': 4,
      'overdue': 2,
      'customers_total': 57,
      'customers_new_today': 6,
      'orders_today_change': 12.0,
      'revenue_today_change': -8.0,
    };

    final orders = [
      order('WASH-00001', total: 500),
      order('WASH-00002', total: 500),
      order('WASH-00003', total: 500),
      order('WASH-00004', total: 500),
      order('WASH-00005', total: 500),
    ];

    testWidgets('render the server figures, not the order list', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: orders, stats: stats);
      await tester.pumpWidget(host(provider, const KpiCardsRow()));
      await tester.pump();

      expect(find.text('3'), findsOneWidget); // not 5
      expect(find.text('₹1,250'), findsOneWidget); // not ₹2,500
      expect(find.text('57'), findsOneWidget); // not 1 distinct phone
    });

    testWidgets('render real change deltas, not a fixed "+1 new today"',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: orders, stats: stats);
      await tester.pumpWidget(host(provider, const KpiCardsRow()));
      await tester.pump();

      expect(find.text('▲ 12% vs yesterday'), findsOneWidget);
      expect(find.text('▼ 8% vs yesterday'), findsOneWidget);
      expect(find.text('+6 new today'), findsOneWidget);
      expect(find.text('+1 new today'), findsNothing);
    });

    testWidgets('show an em dash when there is nothing to compare against',
        (tester) async {
      // A missing comparison is not a 0% change.
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: orders, stats: {'orders_today': 3});
      await tester.pumpWidget(host(provider, const KpiCardsRow()));
      await tester.pump();

      expect(find.text('— vs yesterday'), findsNWidgets(2));
    });

    testWidgets('fall back to the local tally before stats arrive',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: orders);
      await tester.pumpWidget(host(provider, const KpiCardsRow()));
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
    });
  });

  group('Order pipeline', () {
    testWidgets('counts come from the server pipeline', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [order('WASH-00001')], stats: {
          'orders_today': 99,
          'pipeline': {
            'received': 2,
            'processing': 3,
            'ready': 4,
            'out_for_delivery': 1,
          },
        });
      await tester.pumpWidget(host(provider, const OrderPipelineCard()));
      await tester.pump();

      // The headline is the pipeline total, no longer "orders today".
      expect(find.text('10'), findsOneWidget);
      expect(find.text('99'), findsNothing);
    });
  });

  group('Revenue chart', () {
    testWidgets('plots the real series rather than an invented sawtooth',
        (tester) async {
      final series = List.generate(
        14,
        (i) => {'date': '2026-08-${i + 1}', 'day': i + 1, 'amount': (i + 1) * 10.0},
      );
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(stats: {'revenue_series': series});
      await tester.pumpWidget(host(provider, const RevenueChartCard()));
      await tester.pump();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final groups = chart.data.barGroups;
      expect(groups, hasLength(14));
      expect(groups.first.barRods.first.toY, 10.0);
      expect(groups.last.barRods.first.toY, 140.0);

      // The axis follows the series' own days, not a hardcoded 16..29.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('16'), findsNothing);

      // The headline is the window total, not one day's revenue.
      expect(find.text('₹1,050'), findsOneWidget);
    });

    testWidgets('says so when there is no revenue to plot', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(stats: {});
      await tester.pumpWidget(host(provider, const RevenueChartCard()));
      await tester.pump();

      expect(find.byType(BarChart), findsNothing);
      expect(find.text('No revenue recorded in the last 14 days'), findsOneWidget);
    });
  });

  group('Sidebar identity', () {
    testWidgets('shows the loaded shop and owner', (tester) async {
      // A multi-word owner so the avatar initials are visibly *derived* rather
      // than coincidentally equal to the name, which is what made the old
      // hardcoded 'AK' invisible against the seed.
      final provider = AppProvider(autoLoad: false)..seedForTest(
          shop: {'id': 1, 'name': 'washing', 'owner_name': 'Aditya Kumar'});
      await tester.pumpWidget(host(provider, const SidebarNavigation()));
      await tester.pump();

      expect(find.text('washing'), findsOneWidget);
      expect(find.text('Aditya Kumar'), findsOneWidget);
      expect(find.text('ADITY'), findsOneWidget); // the avatar long form
    });

    testWidgets('shows a placeholder before the shop loads', (tester) async {
      final provider = AppProvider(autoLoad: false);
      await tester.pumpWidget(host(provider, const SidebarNavigation()));
      await tester.pump();

      // The literals used to match the seed, which is why nobody noticed them.
      expect(find.text('washing'), findsNothing);
      expect(find.text('Your shop'), findsOneWidget);
      expect(find.text('USER'), findsOneWidget);
    });

    testWidgets('carries no subscription plan badge', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(shop: {'id': 1, 'name': 'washing', 'owner_name': 'AK'});
      await tester.pumpWidget(host(provider, const SidebarNavigation()));
      await tester.pump();

      // There are no plan tiers; `Shop.plan` was dropped in migration 0008.
      expect(find.text('Pro '), findsNothing);
      expect(find.text('Active'), findsNothing);
    });
  });

  group('Scan lookup', () {
    Future<void> searchFor(WidgetTester tester, AppProvider provider, String q) async {
      await tester.pumpWidget(host(provider, const ScanScreen()));
      await tester.pump();
      await tester.tap(find.text('Manual'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, q);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
      await tester.pump();
    }

    testWidgets('a miss reports a miss instead of another order\'s receipt',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(
          orders: [order('WASH-00001'), order('WASH-00002')],
          shop: {'id': 1, 'name': 'washing', 'order_prefix': 'WASH'});

      await searchFor(tester, provider, 'WASH-99999');

      expect(find.byType(ReceiptDialog), findsNothing);
      expect(find.textContaining('No order found for "WASH-99999"'), findsOneWidget);
    });

    testWidgets('a hit opens that order', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(
          orders: [order('WASH-00001'), order('WASH-00002')],
          shop: {'id': 1, 'name': 'washing', 'order_prefix': 'WASH'});

      await searchFor(tester, provider, 'WASH-00002');
      await tester.pump();

      expect(find.byType(ReceiptDialog), findsOneWidget);
      expect(find.text('WASH-00002'), findsWidgets);
    });

    testWidgets('an empty order list does not throw', (tester) async {
      // The old `orElse` was `orders.isNotEmpty ? first : first`, which threw.
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: []);

      await searchFor(tester, provider, 'WASH-00001');

      expect(tester.takeException(), isNull);
      expect(find.byType(ReceiptDialog), findsNothing);
    });

    testWidgets('the hint uses the shop\'s own order prefix', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(shop: {'id': 1, 'order_prefix': 'WA3P'});
      await tester.pumpWidget(host(provider, const ScanScreen()));
      await tester.pump();
      await tester.tap(find.text('Manual'));
      await tester.pump();

      expect(find.text('Order ID (e.g. WA3P-00001)'), findsOneWidget);
      expect(find.textContaining('LB-1001'), findsNothing);
    });

    testWidgets('the fixed-520px content shrinks to fit a phone width '
        'without overflowing', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 1200)
        ..devicePixelRatio = 1.0;
      final provider = AppProvider(autoLoad: false)..seedForTest();
      await tester.pumpWidget(host(provider, const ScanScreen()));
      await tester.pump();

      expect(find.text('Scan & Tags'), findsOneWidget);
    });
  });
}
