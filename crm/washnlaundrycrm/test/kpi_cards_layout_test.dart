import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/widgets/kpi_cards_row.dart';

/// KAN-181: the Dashboard's five KPI cards sit on ONE row at every width,
/// stay small, and never overflow.
const _titles = [
  'Orders today',
  'Revenue today',
  'Ready for pickup',
  'Overdue',
  'Customers',
];

Future<void> _pump(
  WidgetTester tester,
  double width, {
  Map<String, dynamic>? stats,
  double textScale = 1.0,
}) async {
  final provider = AppProvider(autoLoad: false)
    ..seedForTest(stats: stats ?? {'orders_today': 12, 'revenue_today': 4500});
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ChangeNotifierProvider.value(
                value: provider,
                child: const KpiCardsRow(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final width in [320.0, 360.0, 600.0, 900.0, 1400.0]) {
    testWidgets('five cards on a single row at ${width.toInt()} px, no overflow',
        (tester) async {
      await _pump(tester, width);
      expect(tester.takeException(), isNull);

      final tops = [
        for (final t in _titles) tester.getTopLeft(find.text(t)).dy,
      ];
      for (final y in tops) {
        expect((y - tops.first).abs(), lessThan(1.0),
            reason: 'cards wrapped onto another row at $width px: $tops');
      }
      // Left-to-right in order, never stacked.
      final lefts = [for (final t in _titles) tester.getTopLeft(find.text(t)).dx];
      expect(lefts, orderedEquals([...lefts]..sort()));
    });
  }

  testWidgets('wide screens share the row; narrow ones scroll sideways',
      (tester) async {
    await _pump(tester, 1400);
    expect(find.byKey(const ValueKey('kpi-scroll')), findsNothing);

    await _pump(tester, 360);
    expect(find.byKey(const ValueKey('kpi-scroll')), findsOneWidget);
    // It really scrolls: the last card is off-screen until you scroll.
    final scroll = tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const ValueKey('kpi-scroll')),
        matching: find.byType(Scrollable)));
    expect(scroll.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('cards are small: a compact height on desktop', (tester) async {
    await _pump(tester, 1400);
    final card = tester.getRect(find
        .ancestor(of: find.text('Orders today'), matching: find.byType(Container))
        .first);
    expect(card.height, lessThan(100));
  });

  for (final width in [360.0, 1400.0]) {
    testWidgets('huge figures and long labels do not overflow at ${width.toInt()} px',
        (tester) async {
      await _pump(tester, width, stats: {
        'orders_today': 123456789,
        'revenue_today': 98765432101.0,
        'ready_for_pickup': 99999999,
        'overdue': 88888888,
        'customers_total': 7654321,
        'customers_new_today': 1234567,
        'orders_today_change': 123456.0,
        'revenue_today_change': -98765.0,
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large accessibility text does not overflow either',
      (tester) async {
    await _pump(tester, 360, textScale: 1.6);
    expect(tester.takeException(), isNull);
    await _pump(tester, 1400, textScale: 1.6);
    expect(tester.takeException(), isNull);
  });
}
