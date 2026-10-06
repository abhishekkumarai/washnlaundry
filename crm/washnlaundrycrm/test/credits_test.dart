import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/credits_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: child,
      ),
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

  final thisMonth = DateTime(DateTime.now().year, DateTime.now().month, 15);
  final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1, 15);

  // Shop-managed categories (Settings → Credit categories). 'Other' is
  // turned off, so it must not be offered for a new credit.
  const categories = [
    CreditCategoryModel(id: '1', name: 'Laundry Income', creditCount: 2),
    CreditCategoryModel(id: '2', name: 'Customer Advance'),
    CreditCategoryModel(id: '3', name: 'Other', isActive: false),
  ];

  final ledger = [
    CreditModel(
      id: '1',
      title: 'Bulk Corporate Deposit',
      category: 'Customer Deposit',
      amount: 15000,
      paymentMethod: 'BANK_TRANSFER',
      date: thisMonth,
      notes: 'Hotel Grand Palace advance for August laundry',
    ),
    CreditModel(
      id: '2',
      title: 'Scrap Hanger Sale',
      category: 'Scrap Sale',
      amount: 1200,
      paymentMethod: 'CASH',
      date: thisMonth,
      notes: 'Sold broken wire hangers to scrap dealer',
    ),
    CreditModel(
      id: '3',
      title: 'Prior Month Investment',
      category: 'Investment',
      amount: 50000,
      paymentMethod: 'BANK_TRANSFER',
      date: lastMonth,
      notes: 'Owner capital addition for new dry cleaning machine',
    ),
  ];

  group('CreditsScreen list & month filtering', () {
    testWidgets('shows credits for the current month and excludes other months',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(credits: ledger, creditCategories: categories);
      await tester.pumpWidget(host(provider, const CreditsScreen()));
      await tester.pump();

      expect(find.text('Bulk Corporate Deposit'), findsOneWidget);
      expect(find.text('Scrap Hanger Sale'), findsOneWidget);
      expect(find.text('Prior Month Investment'), findsNothing);
    });

    testWidgets('stepping month back reveals previous month credits',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(credits: ledger, creditCategories: categories);
      await tester.pumpWidget(host(provider, const CreditsScreen()));
      await tester.pump();

      // Step back one month
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('Prior Month Investment'), findsOneWidget);
      expect(find.text('Bulk Corporate Deposit'), findsNothing);
    });

    testWidgets('displays notes when present in list item', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(credits: ledger, creditCategories: categories);
      await tester.pumpWidget(host(provider, const CreditsScreen()));
      await tester.pump();

      expect(find.text('Hotel Grand Palace advance for August laundry'),
          findsOneWidget);
    });

    testWidgets('search filters by title, category, or payment method',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(credits: ledger, creditCategories: categories);
      await tester.pumpWidget(host(provider, const CreditsScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Hanger');
      await tester.pump();

      expect(find.text('Scrap Hanger Sale'), findsOneWidget);
      expect(find.text('Bulk Corporate Deposit'), findsNothing);
    });
  });

  group('CreditsScreen Add / Edit / Delete dialogs', () {
    testWidgets('Add Credit dialog includes Notes section and validations',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(credits: ledger, creditCategories: categories);
      await tester.pumpWidget(host(provider, const CreditsScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Credit'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, 'Add Credit')),
          findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('Notes (optional)')),
          findsOneWidget);

      // Attempt submit without title
      await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, 'Add Credit')));
      await tester.pump();

      expect(find.text('Give the credit entry a title.'), findsOneWidget);
    });

    testWidgets('Credit options menu offers Edit and Delete', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(credits: ledger, creditCategories: categories);
      await tester.pumpWidget(host(provider, const CreditsScreen()));
      await tester.pump();

      await tester.tap(find.byTooltip('Credit options').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('CreditModel model tests', () {
    test('fromJson and toJson serializes all fields including notes', () {
      final json = {
        'id': 101,
        'title': 'Packaging Material Rebate',
        'category': 'Refund',
        'amount': 850.5,
        'payment_method': 'UPI',
        'date': '2026-09-15T10:00:00Z',
        'notes': 'Supplier refund for returned damaged boxes',
      };

      final model = CreditModel.fromJson(json);
      expect(model.id, '101');
      expect(model.title, 'Packaging Material Rebate');
      expect(model.category, 'Refund');
      expect(model.amount, 850.5);
      expect(model.paymentMethod, 'UPI');
      expect(model.notes, 'Supplier refund for returned damaged boxes');

      final output = model.toJson();
      expect(output['title'], 'Packaging Material Rebate');
      expect(output['category'], 'Refund');
      expect(output['amount'], 850.5);
      expect(output['payment_method'], 'UPI');
      expect(output['notes'], 'Supplier refund for returned damaged boxes');
    });
  });

  group('CreditsScreen categories come from Settings', () {
    testWidgets('the dropdown offers only active categories', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(credits: ledger, creditCategories: categories);
      await tester.pumpWidget(host(provider, const CreditsScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Credit'));
      await tester.pumpAndSettle();

      // Open the category menu and read its items directly — the ledger
      // fixture itself still contains an old 'Scrap Sale' credit, shown in
      // the list behind the dialog. Only this menu is open, so the payment
      // method dropdown contributes just its selected item.
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      final offered = tester
          .widgetList<DropdownMenuItem<String>>(
              find.byType(DropdownMenuItem<String>))
          .map((i) => i.value)
          .toSet();
      expect(offered, containsAll(['Laundry Income', 'Customer Advance']));
      expect(offered, isNot(contains('Other')));
      // The old fixed choices are gone.
      expect(offered, isNot(contains('Scrap Sale')));
      // And there is a way to the place they are managed.
      expect(find.widgetWithText(TextButton, 'Manage'), findsOneWidget);
    });

    testWidgets('with every category off, Add Credit points to Settings',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(credits: ledger, creditCategories: const [
          CreditCategoryModel(id: '3', name: 'Other', isActive: false),
        ]);
      await tester.pumpWidget(host(provider, const CreditsScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Credit'));
      await tester.pumpAndSettle();

      expect(find.text('No credit categories'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Open Settings'), findsOneWidget);
      expect(find.text('Notes (optional)'), findsNothing);
      expect(CreditsScreen.settingsLink, '/settings?tab=credit-categories');
    });
  });
}
