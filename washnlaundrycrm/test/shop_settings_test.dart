import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/expenses_screen.dart';
import 'package:washnlaundrycrm/screens/staff_screen.dart';
import 'package:washnlaundrycrm/utils/money.dart';
import 'package:washnlaundrycrm/widgets/panel_card.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

const _meta = MetaModel(
  paymentMethods: [
    ChoiceModel(value: 'CASH', label: 'Cash'),
    ChoiceModel(value: 'UPI', label: 'UPI'),
    ChoiceModel(value: 'CARD', label: 'Card'),
    ChoiceModel(value: 'BANK_TRANSFER', label: 'Bank Transfer'),
  ],
  expenseCategories: [
    ChoiceModel(value: 'Supplies', label: 'Supplies'),
    ChoiceModel(value: 'Rent', label: 'Rent'),
  ],
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
    // Money's statics outlive a provider, so one test's shop would otherwise
    // leak into the next.
    Money.reset();
  });

  group('Operating rules come from the shop', () {
    test('fall back to the constants they replaced', () {
      final provider = AppProvider(autoLoad: false);
      expect(provider.expressMultiplier, 1.5);
      expect(provider.defaultMonthlyWage, 18000.0);
      expect(provider.defaultStaffRole, 'Washer');
    });

    test('the shop overrides them', () {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(shop: {
          'id': 1,
          'express_multiplier': 2.0,
          'default_monthly_wage': 21000.0,
          'default_staff_role': 'Presser',
        });
      expect(provider.expressMultiplier, 2.0);
      expect(provider.defaultMonthlyWage, 21000.0);
      expect(provider.defaultStaffRole, 'Presser');
    });

    testWidgets('Add Staff opens on the shop defaults, not 18000/Washer',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(shop: {
          'id': 1,
          'default_monthly_wage': 21000.0,
          'default_staff_role': 'Presser',
        });
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.text('Add Staff').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Presser'), findsOneWidget);
      // The wage field carries 21000 as both its value and its hint.
      expect(find.widgetWithText(TextField, '21000'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Washer'), findsNothing);
      expect(find.widgetWithText(TextField, '18000'), findsNothing);
    });
  });

  group('Payment methods come from /meta/', () {
    test('provider falls back to the four the model declares', () {
      final provider = AppProvider(autoLoad: false);
      expect(
        provider.paymentMethods.map((c) => c.value).toList(),
        ['CASH', 'UPI', 'CARD', 'BANK_TRANSFER'],
      );
    });

    test('served vocabulary wins over the fallback', () {
      final provider = AppProvider(autoLoad: false)..seedForTest(
          meta: const MetaModel(paymentMethods: [
        ChoiceModel(value: 'CASH', label: 'Cash'),
      ]));
      expect(provider.paymentMethods, hasLength(1));
    });

    testWidgets('Add Expense offers the served categories and methods',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(meta: _meta, shop: {'id': 1});
      await tester.pumpWidget(host(provider, const ExpensesScreen()));
      await tester.pump();

      await tester.tap(find.text('Add Expense').first);
      await tester.pumpAndSettle();

      // Bank Transfer is in the dropdown because the backend offers it — this
      // screen used to carry its own list.
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();
      expect(find.text('Bank Transfer'), findsWidgets);
    });
  });

  group('Currency comes from the shop', () {
    test('defaults to the rupee', () {
      expect(Money.symbol, '₹');
      expect(Money.format(1250), '₹1250');
      expect(Money.grouped(48500), '₹48,500');
    });

    test('the shop record reconfigures it', () {
      AppProvider(autoLoad: false)
        ..seedForTest(shop: {'id': 1, 'currency_symbol': r'$', 'locale': 'en_US'});

      expect(Money.symbol, r'$');
      expect(Money.format(1250), r'$1250');
      expect(Money.grouped(48500), r'$48,500');
    });

    test('a blank currency keeps the default rather than blanking every price', () {
      AppProvider(autoLoad: false)
        ..seedForTest(shop: {'id': 1, 'currency_symbol': '  ', 'locale': ''});
      expect(Money.symbol, '₹');
      expect(Money.locale, 'en_IN');
    });

    test('an unknown locale still renders an amount', () {
      Money.configure(locale: 'not-a-locale');
      expect(Money.grouped(500), contains('500'));
    });

    test('formatRupees follows the shop', () {
      AppProvider(autoLoad: false)
        ..seedForTest(shop: {'id': 1, 'currency_symbol': '€'});
      expect(formatRupees(90), '€90');
    });
  });

  group('Catalogue images', () {
    test('parse off the item record', () {
      final item = GarmentItemModel.fromJson(const {
        'id': 1,
        'name': 'Shirt',
        'price': 15,
        'image_url': 'https://example.com/shirt.png',
      });
      expect(item.imageUrl, 'https://example.com/shirt.png');
    });

    test('default to empty so the icon fallback still applies', () {
      final item = GarmentItemModel.fromJson(const {
        'id': 1,
        'name': 'Shirt',
        'price': 15,
      });
      expect(item.imageUrl, '');
    });
  });
}
