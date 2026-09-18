import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/widgets/order_calendar_heatmap.dart';

void main() {
  Future<DateTime?> pump(WidgetTester tester, Map<DateTime, int> counts,
      {DateTime? initialFocusedDay}) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await OrderCalendarHeatmap.pickDay(
                  context: context,
                  countsByDay: counts,
                  initialFocusedDay: initialFocusedDay,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows the order count as a badge on days that have orders',
      (tester) async {
    final focused = DateTime(2026, 3, 15);
    final busyDay = DateTime(2026, 3, 12);
    final quietDay = DateTime(2026, 3, 25);
    final noOrdersDay = DateTime(2026, 3, 18);
    await pump(
      tester,
      {busyDay: 7, quietDay: 1},
      initialFocusedDay: focused,
    );

    expect(find.text('Orders calendar'), findsOneWidget);

    Finder badgeText(DateTime day) => find.descendant(
          of: find.byKey(ValueKey('order-count-badge-$day')),
          matching: find.byType(Text),
        );

    expect(tester.widget<Text>(badgeText(busyDay)).data, '7');
    expect(tester.widget<Text>(badgeText(quietDay)).data, '1');
    // A day with no orders gets no badge at all.
    expect(find.byKey(ValueKey('order-count-badge-$noOrdersDay')), findsNothing);
  });

  testWidgets('tapping a day resolves pickDay to that day and closes the dialog',
      (tester) async {
    late BuildContext ctx;
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return ElevatedButton(
                onPressed: () async {
                  result = await OrderCalendarHeatmap.pickDay(
                    context: ctx,
                    countsByDay: {DateTime(2026, 3, 15): 4},
                    initialFocusedDay: DateTime(2026, 3, 15),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();

    expect(find.text('Orders calendar'), findsNothing);
    expect(result, DateTime(2026, 3, 20));
  });

  testWidgets('closing with × resolves to null without applying anything',
      (tester) async {
    DateTime? result = DateTime(2020);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await OrderCalendarHeatmap.pickDay(
                  context: context,
                  countsByDay: {DateTime(2026, 3, 15): 4},
                  initialFocusedDay: DateTime(2026, 3, 15),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
