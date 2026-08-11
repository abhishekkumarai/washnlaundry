import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/reports_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(2200, 1800);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  const report = ReportsModel(
    revenue: 62000,
    revenueChange: 12,
    collected: 48000,
    collectedPercent: 77.4,
    outstanding: 14000,
    expenses: 9000,
    expensesChange: -8,
    netProfit: 39000,
    netProfitChange: 15,
    margin: 81.3,
    orderCount: 40,
    averageOrderValue: 1550,
    monthlySeries: [
      ReportMonthModel(label: 'Jun', revenue: 30000, expenses: 8000),
      ReportMonthModel(label: 'Jul', revenue: 62000, expenses: 9000),
    ],
    byStatus: [
      ReportBreakdownModel(key: 'IRONING', label: 'Ironing', count: 7),
      ReportBreakdownModel(key: 'DELIVERED', label: 'Delivered', count: 20),
    ],
    byType: [
      ReportBreakdownModel(key: 'HOME_DELIVERY', label: 'Home Delivery', count: 25),
    ],
    byService: [
      ReportBreakdownModel(label: 'Dry Cleaning', count: 12),
    ],
    paymentMix: [
      PaymentMixModel(method: 'UPI', amount: 30000, percent: 62.5),
      PaymentMixModel(method: 'BANK_TRANSFER', amount: 18000, percent: 37.5),
    ],
  );

  group('ReportsScreen', () {
    testWidgets('figures come from the provider, not the old literals',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(reports: report);
      await tester.pumpWidget(host(provider, const ReportsScreen()));
      await tester.pump();

      // Indian digit grouping, as the screen has always used.
      expect(find.text('₹62,000'), findsOneWidget);
      expect(find.text('₹48,000'), findsOneWidget);
      expect(find.text('40'), findsWidgets);

      // Every one of these was hardcoded before.
      expect(find.text('₹4,850'), findsNothing);
      expect(find.text('₹3,900'), findsNothing);
      expect(find.text('₹3,650'), findsNothing);
      expect(find.text('75%'), findsNothing);
    });

    testWidgets('the status breakdown can no longer say Washing', (tester) async {
      // 'Washing' was in the hardcoded list long after the status was deleted
      // from the model. Breakdowns are server-driven now, so it cannot return.
      final provider = AppProvider(autoLoad: false)..seedForTest(reports: report);
      await tester.pumpWidget(host(provider, const ReportsScreen()));
      await tester.pump();

      expect(find.text('Washing'), findsNothing);
      expect(find.text('Ironing'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('the payment mix labels are humanised', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(reports: report);
      await tester.pumpWidget(host(provider, const ReportsScreen()));
      await tester.pump();

      expect(find.text('Bank Transfer'), findsOneWidget);
      expect(find.text('₹30,000 (63%)'), findsOneWidget);
    });

    testWidgets('missing measurements render an em dash, not a zero',
        (tester) async {
      // An idle period is not a 0% margin — the dashboard's Store Health panel
      // established this rule and Reports follows it.
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(reports: const ReportsModel());
      await tester.pumpWidget(host(provider, const ReportsScreen()));
      await tester.pump();

      expect(find.text('—'), findsWidgets);
      expect(find.text('0%'), findsNothing);
    });

    testWidgets('an empty period renders without dividing by zero', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(reports: const ReportsModel());
      await tester.pumpWidget(host(provider, const ReportsScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('No history yet.'), findsOneWidget);
      expect(find.text('Nothing collected in this period.'), findsOneWidget);
    });

    testWidgets('the period label is real month arithmetic, not July 2026',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(reports: report);
      await tester.pumpWidget(host(provider, const ReportsScreen()));
      await tester.pump();

      const monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      final now = DateTime.now();
      expect(find.text('${monthNames[now.month - 1]} ${now.year}'), findsOneWidget);
    });

    testWidgets('Last Month re-labels rather than only changing a highlight',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(reports: report);
      await tester.pumpWidget(host(provider, const ReportsScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Last Month'));
      await tester.pump();

      const monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      final now = DateTime.now();
      final previous = DateTime(now.year, now.month - 1);
      expect(
        find.text('${monthNames[previous.month - 1]} ${previous.year}'),
        findsOneWidget,
      );
    });

    testWidgets('Print and Export PDF stay disabled', (tester) async {
      // Neither has been captured from the live app, so there is nothing to
      // clone them against. Disabled beats a dead button.
      final provider = AppProvider(autoLoad: false)..seedForTest(reports: report);
      await tester.pumpWidget(host(provider, const ReportsScreen()));
      await tester.pump();

      expect(
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Print')).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Export PDF'))
            .onPressed,
        isNull,
      );
    });
  });

  group('ReportsModel', () {
    test('parses the endpoint payload', () {
      final model = ReportsModel.fromJson({
        'from': '2026-07-01',
        'to': '2026-07-31',
        'revenue': 1000,
        'revenue_change': 25.0,
        'collected': 800,
        'collected_percent': 80.0,
        'outstanding': 200,
        'expenses': 300,
        'net_profit': 500,
        'margin': 62.5,
        'order_count': 4,
        'average_order_value': 250,
        'monthly_series': [
          {'label': 'Jul', 'revenue': 1000, 'expenses': 300},
        ],
        'by_status': [
          {'key': 'READY', 'label': 'Ready', 'count': 2},
        ],
        'payment_mix': [
          {'method': 'UPI', 'amount': 800, 'percent': 100.0},
        ],
      });

      expect(model.from, DateTime(2026, 7, 1));
      expect(model.revenue, 1000);
      expect(model.margin, 62.5);
      expect(model.monthlySeries.single.label, 'Jul');
      expect(model.byStatus.single.label, 'Ready');
      expect(model.paymentMix.single.methodLabel, 'UPI');
      // Absent from the payload entirely, so still null rather than 0.
      expect(model.expensesChange, isNull);
    });

    test('a null metric stays null rather than becoming zero', () {
      final model = ReportsModel.fromJson({'margin': null, 'collected_percent': null});
      expect(model.margin, isNull);
      expect(model.collectedPercent, isNull);
    });

    test('an empty payload does not throw', () {
      final model = ReportsModel.fromJson({});
      expect(model.revenue, 0);
      expect(model.monthlySeries, isEmpty);
      expect(model.paymentMix, isEmpty);
    });

    test('changeLabel picks a direction and drops a pointless decimal', () {
      expect(ReportsModel.changeLabel(12), '▲ 12% vs last period');
      expect(ReportsModel.changeLabel(-8.5), '▼ 8.5% vs last period');
      expect(ReportsModel.changeLabel(null), isNull);
    });

    test('methodLabel humanises the stored value', () {
      expect(const PaymentMixModel(method: 'BANK_TRANSFER').methodLabel, 'Bank Transfer');
      expect(const PaymentMixModel(method: 'CASH').methodLabel, 'Cash');
    });

    test('methodLabel leaves acronyms alone', () {
      // Plain title-casing turned UPI into "Upi", which is how nobody writes it.
      expect(const PaymentMixModel(method: 'UPI').methodLabel, 'UPI');
      expect(const PaymentMixModel(method: 'CARD_POS').methodLabel, 'Card POS');
    });
  });
}
