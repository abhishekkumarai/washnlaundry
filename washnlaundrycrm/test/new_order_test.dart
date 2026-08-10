import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/new_order_screen.dart';
import 'package:washnlaundrycrm/widgets/receipt_dialog.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

/// A slice of the real catalogue: two categories, one of which is empty on the
/// grid until you filter to it.
const _catalogue = <GarmentItemModel>[
  GarmentItemModel(
    id: '1',
    categoryId: 'c1',
    categoryName: 'Ironing',
    name: 'Shirt',
    price: 15,
  ),
  GarmentItemModel(
    id: '2',
    categoryId: 'c1',
    categoryName: 'Ironing',
    name: 'Pant',
    price: 18,
  ),
  GarmentItemModel(
    id: '3',
    categoryId: 'c2',
    categoryName: 'Household',
    name: 'Curtain',
    price: 60,
    unit: PricingUnit.kg,
  ),
];

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

  group('NewOrderScreen catalogue', () {
    testWidgets('renders items from the provider, not a hardcoded list',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      // The screen used to ship its own 8-item literal, so a catalogue item
      // like Curtain could never appear and Shirt appeared even with no data.
      expect(find.text('Curtain'), findsOneWidget);
      expect(find.text('Shirt'), findsOneWidget);
      expect(find.text('Pant'), findsOneWidget);
    });

    testWidgets('shows nothing at all when the catalogue is empty',
        (tester) async {
      final provider = AppProvider(autoLoad: false);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      expect(find.text('Shirt'), findsNothing);
      expect(find.text('No items here'), findsOneWidget);
    });

    testWidgets('category chips come from the catalogue', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Ironing'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Household'), findsOneWidget);
      // A category with no items is not offered as a chip at all.
      expect(find.widgetWithText(ChoiceChip, 'Shoe Cleaning'), findsNothing);
    });

    testWidgets('filtering to a category narrows the grid', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Household'));
      await tester.pumpAndSettle();

      expect(find.text('Curtain'), findsOneWidget);
      expect(find.text('Shirt'), findsNothing);
    });

    testWidgets('an empty result explains itself instead of going blank',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pumpAndSettle();

      // Previously a non-matching filter rendered a silent blank panel.
      expect(find.text('No items here'), findsOneWidget);
    });

    testWidgets('price tags use the item unit', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      // Assert on the unit, not its wording — PricingUnit.label owns that.
      expect(find.text(PricingUnit.label(PricingUnit.kg)), findsOneWidget);
      expect(find.text(PricingUnit.label(PricingUnit.piece)), findsNWidgets(2));
    });
  });

  group('NewOrderScreen cart', () {
    Future<AppProvider> pumpWithCatalogue(WidgetTester tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();
      return provider;
    }

    testWidgets('starts empty with checkout disabled', (tester) async {
      await pumpWithCatalogue(tester);

      expect(find.text('No items yet'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Checkout • ₹0'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('adding an item totals the cart and enables checkout',
        (tester) async {
      await pumpWithCatalogue(tester);

      await tester.tap(find.text('+ Add to List').first);
      await tester.pumpAndSettle();

      expect(find.text('Checkout • ₹15'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Checkout • ₹15'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('the express switch applies the 1.5x surcharge',
        (tester) async {
      await pumpWithCatalogue(tester);

      await tester.tap(find.text('+ Add to List').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // 15 -> 22.5, floored to 22 by the display.
      expect(find.text('Checkout • ₹22'), findsOneWidget);
    });

    testWidgets('decrementing to zero drops the line', (tester) async {
      await pumpWithCatalogue(tester);

      await tester.tap(find.text('+ Add to List').first);
      await tester.pumpAndSettle();
      expect(find.text('No items yet'), findsNothing);

      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pumpAndSettle();
      expect(find.text('No items yet'), findsOneWidget);
    });
  });

  group('NewOrderScreen customer', () {
    testWidgets('defaults to a walk-in and offers to add one', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      expect(find.text('Walk-in customer'), findsOneWidget);
      expect(find.text('Tap to add a customer'), findsOneWidget);
    });

    testWidgets('the Add button opens a real picker, not a dead end',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(
          garments: _catalogue,
          customers: const [
            CustomerModel(id: 'c1', name: 'Priya Sundaram', phone: '9000000002'),
            CustomerModel(id: 'c2', name: 'Rohan Verma', phone: '9000000003'),
          ],
        );
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      // This button was `onPressed: () {}` — you could never bill a customer.
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Bill to'), findsOneWidget);
      expect(find.text('Priya Sundaram'), findsOneWidget);
      expect(find.text('Rohan Verma'), findsOneWidget);
    });

    testWidgets('picking a customer bills the order to them', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(
          garments: _catalogue,
          customers: const [
            CustomerModel(id: 'c1', name: 'Priya Sundaram', phone: '9000000002'),
          ],
        );
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Priya Sundaram'));
      await tester.pumpAndSettle();

      expect(find.text('Priya Sundaram'), findsOneWidget);
      expect(find.text('9000000002'), findsOneWidget);
      expect(find.text('Tap to add a customer'), findsNothing);
    });
  });

  group('ReceiptDialog', () {
    final order = OrderModel(
      id: 'o1',
      orderNumber: 'WASH-00016',
      customerName: 'Priya Sundaram',
      customerPhone: '9000000002',
      status: OrderStatus.placed,
      paymentStatus: PaymentStatus.paid,
      paymentMethod: 'CASH',
      totalAmount: 45,
      paidAmount: 45,
      dueAmount: 0,
      express: false,
      createdAt: DateTime(2026, 7, 31),
      items: const [
        OrderItemModel(
          itemTitle: 'Shirt',
          serviceType: 'Ironing',
          quantity: 2,
          unitPrice: 15,
          totalPrice: 30,
        ),
        OrderItemModel(
          itemTitle: 'T-Shirt',
          serviceType: 'Wash & Iron',
          quantity: 1,
          unitPrice: 15,
          totalPrice: 15,
        ),
      ],
    );

    testWidgets('shows the saved order number and total', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ReceiptDialog(order: order)),
      );
      await tester.pump();

      // The total used to render as ₹0: the cart was cleared before the
      // dialog builder read the subtotal back off it.
      expect(find.text('#WASH-00016'), findsOneWidget);
      expect(find.text('₹45'), findsOneWidget);
    });

    testWidgets('uses the loaded shop, not a hardcoded branch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptDialog(
            order: order,
            shop: const {
              'name': 'washing',
              'address': 'Hbr layout',
              'city': 'Bengaluru',
              'phone': '+91 98765 43210',
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('washing'), findsOneWidget);
      expect(find.textContaining('Bengaluru'), findsOneWidget);
      expect(find.textContaining('Noida'), findsNothing);
    });

    testWidgets('does not repeat the city already in the address',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptDialog(
            order: order,
            shop: const {
              'name': 'washing',
              'address': 'Hbr layout, Bengaluru',
              'city': 'Bengaluru',
              'phone': '+91 98765 43210',
            },
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Hbr layout, Bengaluru • +91 98765 43210'),
        findsOneWidget,
      );
    });

    testWidgets('cannot WhatsApp a walk-in with no number', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptDialog(
            order: OrderModel(
              id: 'o2',
              orderNumber: 'WASH-00017',
              customerName: 'Walk-in customer',
              customerPhone: '',
              status: OrderStatus.placed,
              paymentStatus: PaymentStatus.paid,
              paymentMethod: 'CASH',
              totalAmount: 15,
              paidAmount: 15,
              dueAmount: 0,
              express: false,
              createdAt: DateTime(2026, 7, 31),
              items: const [
                OrderItemModel(
                  itemTitle: 'Shirt',
                  serviceType: 'Ironing',
                  quantity: 1,
                  unitPrice: 15,
                  totalPrice: 15,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // It used to fall back to a hardcoded number and message a stranger.
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'WhatsApp Bill'),
      );
      expect(button.onPressed, isNull);
    });
  });
}
