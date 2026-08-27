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

/// The dialog's submit button. Scoped to the dialog because the in-page
/// "Add Expense" button behind it (in `_titleRow`) carries the same label —
/// `TopHeader` deliberately has no button of its own here, since that in-page
/// one already existed (see `top_header_test.dart`'s "omits the action
/// button" test).
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
    testWidgets(
        'the header has no Add Expense button of its own — the in-page one '
        'is the only control', (tester) async {
      // TopHeader used to render a second "Add Expense" button that did the
      // exact same thing as the pre-existing in-page one — a redundant
      // duplicate, the same pattern already caught and removed on Services
      // and Staff (see wip.md). Only one should exist now.
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      expect(find.widgetWithText(FilledButton, 'Add Expense'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Add Expense'), findsNothing);
    });

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

    testWidgets('payment method labels come from the served vocabulary, not a naive title-case',
        (tester) async {
      // A raw title-case (upper first letter, lower the rest) turns 'UPI'
      // into 'Upi'. The served/fallback label is 'UPI' verbatim.
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      expect(find.textContaining('UPI ·'), findsOneWidget);
      expect(find.textContaining('Upi ·'), findsNothing);
      expect(find.textContaining('Bank Transfer ·'), findsOneWidget);
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

      await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
      await tester.pumpAndSettle();

      await tester.tap(_dialogSubmit());
      await tester.pump();

      expect(find.text('Give the expense a title.'), findsOneWidget);
    });

    testWidgets('the add dialog rejects a zero amount', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
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

      await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
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

    testWidgets('each row offers Edit and Delete, not just an append-only log',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Edit opens pre-filled with the expense\'s own details',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      // ledger[0] is the first row: Commercial Detergent, ₹3500, UPI.
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Commercial Detergent (50L)'), findsOneWidget);
      expect(find.widgetWithText(TextField, '3500'), findsOneWidget);
    });

    testWidgets('Edit rejects clearing the title', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Commercial Detergent (50L)'), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pump();

      expect(find.text('Give the expense a title.'), findsOneWidget);
    });

    testWidgets('Delete asks for confirmation naming the expense, and Cancel leaves the ledger alone',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Expense'), findsOneWidget);
      expect(find.textContaining('Commercial Detergent (50L)'), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Expense'), findsNothing);
      expect(find.text('Commercial Detergent (50L)'), findsOneWidget);
    });

    testWidgets('search filters by title, category, or payment method',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'detergent');
      await tester.pump();

      expect(find.text('Commercial Detergent (50L)'), findsOneWidget);
      expect(find.text('Monthly Shop Rent'), findsNothing);
      expect(find.text('Diesel for Delivery Van'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'transport');
      await tester.pump();

      expect(find.text('Diesel for Delivery Van'), findsOneWidget);
      expect(find.text('Commercial Detergent (50L)'), findsNothing);
    });

    testWidgets('a search matching nothing says so, scoped to the query',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump();

      expect(find.text('No expenses match "zzzz".'), findsOneWidget);
    });

    testWidgets(
        'was a dead/placeholder Export — now downloads the filtered rows as CSV',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Export'));
      await tester.pump();

      // `flutter test` runs on the VM, not web, so `downloadCsv` resolves to
      // the non-web stub.
      expect(find.text('Export is not available yet.'), findsNothing);
      expect(find.text('Export is only available in the web app.'), findsOneWidget);
    });

    testWidgets('Export with an empty filtered list says so instead of '
        'downloading an empty file', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Export'));
      await tester.pump();

      expect(find.text('No expenses to export.'), findsOneWidget);
    });

    group('responsive layout', () {
      Future<void> pumpAt(WidgetTester tester, double width) async {
        tester.view
          ..physicalSize = Size(width, 1400)
          ..devicePixelRatio = 1.0;
        final provider = AppProvider(autoLoad: false)..seedForTest(expenses: ledger);
        await tester.pumpWidget(host(provider, const ExpensesScreen()));
        await tester.pump();
      }

      testWidgets('shows a labeled Add Expense and Export at wide width',
          (tester) async {
        await pumpAt(tester, 1600);

        expect(find.widgetWithText(FilledButton, 'Add Expense'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Export'), findsOneWidget);
      });

      testWidgets(
          'collapses Add Expense to an icon and keeps search/Export full-width '
          'at phone width', (tester) async {
        await pumpAt(tester, 390);

        expect(find.widgetWithText(FilledButton, 'Add Expense'), findsNothing);
        expect(find.byIcon(Icons.add_rounded), findsWidgets);
        expect(find.widgetWithText(OutlinedButton, 'Export'), findsOneWidget);
        expect(find.text('Commercial Detergent (50L)'), findsOneWidget);
      });
    });
  });
}
