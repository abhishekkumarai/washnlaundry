import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/expenses_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

/// The dialog's submit button. Scoped to the dialog because the header's
/// "Add Expense" button carries the same label, and the sidebar's Attendance
/// item carries the same calendar icon.
Finder _dialogSubmit() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Add Expense'),
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

  final now = DateTime.now();
  // Mid-month so that subtracting a few days cannot slip into last month and
  // make the "this month" assertions flaky.
  final thisMonth = DateTime(now.year, now.month, 15);
  final lastMonth = DateTime(now.year, now.month, 15).subtract(const Duration(days: 45));

  final ledger = [
    ExpenseModel(
      id: '1',
      title: 'Commercial Detergent (50L)',
      category: 'Supplies',
      amount: 3500,
      paymentMethod: 'UPI',
      date: thisMonth,
    ),
    ExpenseModel(
      id: '2',
      title: 'Monthly Shop Rent',
      category: 'Rent',
      amount: 28000,
      paymentMethod: 'BANK_TRANSFER',
      date: thisMonth,
    ),
    ExpenseModel(
      id: '3',
      title: 'Diesel for Delivery Van',
      category: 'Transport',
      amount: 2200,
      date: lastMonth,
    ),
  ];

  group('ExpensesScreen', () {
    testWidgets('renders the ledger from the provider, not a literal',
        (tester) async {
      // The screen used to build four fake expenses inside build().
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      expect(find.text('Commercial Detergent (50L)'), findsOneWidget);
      expect(find.text('Monthly Shop Rent'), findsOneWidget);
      expect(find.text('Diesel for Delivery Van'), findsOneWidget);
      expect(find.text('Electricity Bill (Commercial)'), findsNothing);
    });

    testWidgets('totals are computed from the real ledger', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      expect(find.text('₹33700'), findsOneWidget); // total of all three
      expect(find.text('₹31500'), findsOneWidget); // this month only
      expect(find.text('3'), findsOneWidget); // entry count
    });

    testWidgets('the month total ignores older entries', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(expenses: [ledger.last]); // last month only
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      expect(find.text('₹0'), findsOneWidget); // this month
      expect(find.text('₹2200'), findsWidgets); // total + the row
    });

    testWidgets('a category chip narrows the list', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilterChip, 'Rent'));
      await tester.pump();

      expect(find.text('Monthly Shop Rent'), findsOneWidget);
      expect(find.text('Commercial Detergent (50L)'), findsNothing);
      expect(find.text('Diesel for Delivery Van'), findsNothing);
    });

    testWidgets('chips are derived from the data, not a fixed list',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(expenses: [
          const ExpenseModel(
              id: '9', title: 'Licence renewal', category: 'Compliance', amount: 1200),
        ]);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      // 'Compliance' is not one of the presets but still gets a chip.
      expect(find.widgetWithText(FilterChip, 'Compliance'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Rent'), findsNothing);
    });

    testWidgets('an empty ledger says so', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: []);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      expect(find.text('No expenses logged yet.'), findsOneWidget);
    });

    testWidgets('a filter matching nothing names the category', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilterChip, 'Rent'));
      await tester.pump();
      // Rent has one entry, so swap the ledger for one without any.
      provider.seedForTest(expenses: [ledger.first]);
      await tester.pump();

      expect(find.text('No Rent expenses logged.'), findsOneWidget);
    });

    testWidgets('the add dialog rejects an empty title', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();

      await tester.tap(_dialogSubmit());
      await tester.pump();

      expect(find.text('Give the expense a title.'), findsOneWidget);
    });

    testWidgets('the add dialog rejects a zero amount', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Broom');
      await tester.enterText(find.byType(TextField).at(1), '0');
      await tester.tap(_dialogSubmit());
      await tester.pump();

      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    });

    testWidgets('the add dialog offers a date, so an expense can be backdated',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Date'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byIcon(Icons.calendar_today_rounded),
        ),
        findsOneWidget,
      );
    });
  });
}
