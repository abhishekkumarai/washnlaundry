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

    testWidgets('an inactive item is hidden from the grid', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: const [
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
            name: 'Retired Item',
            price: 20,
            isActive: false,
          ),
        ]);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      expect(find.text('Shirt'), findsOneWidget);
      expect(find.text('Retired Item'), findsNothing);
    });

    testWidgets('an item whose whole category is inactive is also hidden',
        (tester) async {
      // The item itself can still be individually `is_active: true` — the
      // category's own flag is what New Order used to never check at all.
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(
          garments: const [
            GarmentItemModel(
              id: '1',
              categoryId: 'c1',
              categoryName: 'Ironing',
              name: 'Shirt',
              price: 15,
            ),
            GarmentItemModel(
              id: '2',
              categoryId: 'c2',
              categoryName: 'Retired Category',
              name: 'Old Service Item',
              price: 40,
            ),
          ],
          categories: const [
            GarmentCategoryModel(id: 'c1', name: 'Ironing'),
            GarmentCategoryModel(id: 'c2', name: 'Retired Category', isActive: false),
          ],
        );
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      expect(find.text('Shirt'), findsOneWidget);
      expect(find.text('Old Service Item'), findsNothing);
    });

    testWidgets('items are not hidden when categories were never seeded',
        (tester) async {
      // A category name absent from provider.categories entirely (not
      // loaded yet, or a test that only seeds garments) must not read as
      // "inactive" — that regressed the whole grid to empty once already.
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      expect(find.text('Shirt'), findsOneWidget);
      expect(find.text('Curtain'), findsOneWidget);
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

      await tester.tap(find.text('+ Add to Cart').first);
      await tester.pumpAndSettle();

      expect(find.text('Checkout • ₹15'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Checkout • ₹15'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('decrementing to zero drops the line', (tester) async {
      await pumpWithCatalogue(tester);

      await tester.tap(find.text('+ Add to Cart').first);
      await tester.pumpAndSettle();
      expect(find.text('No items yet'), findsNothing);

      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pumpAndSettle();
      expect(find.text('No items yet'), findsOneWidget);
    });

    testWidgets(
        'an item already in the cart shows In Cart, not another Add button',
        (tester) async {
      // The item list's own +/- stepper was removed — increment/decrement
      // now lives only in the cart panel (_cartLineRow), so the item list
      // just reflects membership once added.
      await pumpWithCatalogue(tester);

      await tester.tap(find.text('+ Add to Cart').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('In Cart'), findsOneWidget);
      // Two items in the catalogue: the one just added shows "In Cart", the
      // other one still offers "+ Add to Cart".
      expect(find.text('+ Add to Cart'), findsWidgets);
    });

    testWidgets('the cart panel + button increments quantity and the total',
        (tester) async {
      await pumpWithCatalogue(tester);
      await tester.tap(find.text('+ Add to Cart').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      // Both the cart line's own qty and the "Current order" header badge
      // read 2 — they're driven by the same _cartQuantities map.
      expect(find.text('2'), findsNWidgets(2));
      expect(find.text('Checkout • ₹30'), findsOneWidget);
    });

    testWidgets('the cart panel delete button removes the line outright',
        (tester) async {
      await pumpWithCatalogue(tester);
      await tester.tap(find.text('+ Add to Cart').first);
      await tester.pumpAndSettle();
      expect(find.text('No items yet'), findsNothing);

      await tester.tap(find.byTooltip('Remove from order'));
      await tester.pumpAndSettle();

      expect(find.text('No items yet'), findsOneWidget);
    });
  });

  group('NewOrderScreen checkout review', () {
    Future<AppProvider> pumpWithItemInCart(WidgetTester tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();
      await tester.tap(find.text('+ Add to Cart').first);
      await tester.pumpAndSettle();
      return provider;
    }

    testWidgets('Checkout opens the review step, Back to items returns',
        (tester) async {
      // The real app doesn't submit straight from the cart — Checkout opens
      // a second review step (Fulfilment / Ready by / Notes) before there's
      // an actual Place order button.
      await pumpWithItemInCart(tester);

      expect(find.text('FULFILMENT'), findsNothing);
      await tester.tap(find.text('Checkout • ₹15'));
      await tester.pumpAndSettle();

      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('FULFILMENT'), findsOneWidget);
      expect(find.text('ORDER NOTES'), findsOneWidget);
      expect(find.text('Place order'), findsOneWidget);
      // The cart-stage Checkout button is gone now — only the grid's search
      // bar is, and that's hidden behind the review too.
      expect(find.text('Search items or scan a tag...'), findsNothing);

      await tester.tap(find.text('Back to items'));
      await tester.pumpAndSettle();

      expect(find.text('FULFILMENT'), findsNothing);
      expect(find.text('Checkout • ₹15'), findsOneWidget);
    });

    testWidgets(
        'picking a delivery type other than pickup adds an editable flat fee',
        (tester) async {
      // Checkout used to hardcode STORE_PICKUP, so there was no way to bill
      // an order that needed carrying — and no way to charge for it either.
      // The fee itself used to be a fixed ₹50 with no way to change it.
      await pumpWithItemInCart(tester);
      await tester.tap(find.text('Checkout • ₹15'));
      await tester.pumpAndSettle();

      // Just Order Notes and Discount exist before a carried type is picked.
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('₹65'), findsNothing);

      await tester.tap(find.text('Home Delivery'));
      await tester.pumpAndSettle();

      // A third field appears: the editable delivery charge, defaulting to
      // the seed data's ₹50 rule but not locked to it.
      expect(find.byType(TextField), findsNWidgets(3));
      final deliveryField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(deliveryField.controller!.text, '50');
      expect(find.text('₹65'), findsOneWidget); // 15 subtotal + 50 fee

      // Editing it updates the total, not just displaying a fixed fee.
      await tester.enterText(find.byType(TextField).at(1), '30');
      await tester.pumpAndSettle();
      expect(find.text('₹45'), findsOneWidget); // 15 subtotal + 30 fee
      expect(find.text('₹65'), findsNothing);

      // Switching back to a pickup type drops the fee and hides the field.
      await tester.tap(find.text('Walk-In'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('₹45'), findsNothing);
    });

    testWidgets('there is no Collect payment now control anymore',
        (tester) async {
      await pumpWithItemInCart(tester);
      await tester.tap(find.text('Checkout • ₹15'));
      await tester.pumpAndSettle();

      expect(find.text('PAYMENT'), findsNothing);
      expect(find.text('Collect payment now'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('Walk-In shows a Ready at label, no slot chips',
        (tester) async {
      // Walk-In is the default fulfilment type, so this is what Checkout
      // review shows without tapping anything.
      await pumpWithItemInCart(tester);
      await tester.tap(find.text('Checkout • ₹15'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ready at'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets(
        'a carried fulfilment type offers 13 hourly slot chips, 9 AM to 10 PM',
        (tester) async {
      await pumpWithItemInCart(tester);
      await tester.tap(find.text('Checkout • ₹15'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home Delivery'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ready at'), findsNothing);
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.length, 13);

      // Mirrors _readyByDefaultFor: the first slot whose hour hasn't already
      // passed today is selected by default (or 9 AM, if it's before 9 AM).
      final now = DateTime.now();
      final selectedIndex = chips.indexWhere((c) => c.selected);
      expect(selectedIndex, isNot(-1));
      if (now.hour >= 9 && now.hour <= 21) {
        expect(selectedIndex, now.hour - 9);
      } else {
        // Either before opening hours (defaults to 9 AM) or after the last
        // slot (rolls to 9 AM tomorrow, where nothing is disabled).
        expect(selectedIndex, 0);
      }
      // Every chip for an hour already past today is disabled; the rest
      // aren't.
      for (var i = 0; i < chips.length; i++) {
        final slotHour = 9 + i;
        final shouldBeDisabled =
            now.hour >= 9 && now.hour <= 21 && slotHour < now.hour;
        expect(chips[i].onSelected == null, shouldBeDisabled,
            reason: 'slot $slotHour AM/PM disabled state');
      }
    });

    testWidgets('tapping a later enabled slot chip selects it instead',
        (tester) async {
      await pumpWithItemInCart(tester);
      await tester.tap(find.text('Checkout • ₹15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home Delivery'));
      await tester.pumpAndSettle();

      final before =
          tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      final enabledIndices = [
        for (var i = 0; i < before.length; i++)
          if (before[i].onSelected != null) i
      ];
      final target = enabledIndices.last;
      final previouslySelected = before.indexWhere((c) => c.selected);

      await tester.tap(find.byType(ChoiceChip).at(target));
      await tester.pumpAndSettle();

      final after =
          tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(after[target].selected, isTrue);
      if (previouslySelected != target) {
        expect(after[previouslySelected].selected, isFalse);
      }
    });

    testWidgets('switching back to Walk-In drops the slot chips again',
        (tester) async {
      await pumpWithItemInCart(tester);
      await tester.tap(find.text('Checkout • ₹15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home Delivery'));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(13));

      await tester.tap(find.text('Walk-In'));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.textContaining('Ready at'), findsOneWidget);
    });

    testWidgets('a discount reduces the total', (tester) async {
      await pumpWithItemInCart(tester);
      await tester.tap(find.text('Checkout • ₹15'));
      await tester.pumpAndSettle();

      // ₹10 (15 subtotal - 5 discount) is unique to the discounted total —
      // the item line and Subtotal both stay at ₹15 regardless.
      expect(find.text('₹10'), findsNothing);

      await tester.enterText(find.byType(TextField).last, '5');
      await tester.pumpAndSettle();

      expect(find.text('₹10'), findsOneWidget);
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

    testWidgets('the picker offers a New customer tab, not just search',
        (tester) async {
      // The real app's own "Bill to" dialog has Existing customer / New
      // customer tabs — ours used to only search existing records, with no
      // way to add someone new without leaving New Order.
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

      expect(find.text('Existing customer'), findsOneWidget);
      expect(find.text('New customer'), findsOneWidget);
      expect(find.text('Priya Sundaram'), findsOneWidget);

      await tester.tap(find.text('New customer'));
      await tester.pumpAndSettle();

      // The existing-customer list and its walk-in escape hatch are gone;
      // the add-customer form is up instead.
      expect(find.text('Priya Sundaram'), findsNothing);
      expect(find.text('Bill to walk-in customer'), findsNothing);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add Customer'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Add Customer'));
      await tester.pump();

      expect(find.text('Name and phone are both required.'), findsOneWidget);

      await tester.tap(find.text('Existing customer'));
      await tester.pumpAndSettle();

      expect(find.text('Priya Sundaram'), findsOneWidget);
      expect(find.text('Full Name'), findsNothing);
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
        MaterialApp(home: ReceiptDialog(order: order, shop: null)),
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
            shop: null,
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

  group('Responsive layout (cart panel + item grid/table)', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view
        ..physicalSize = Size(width, 1400)
        ..devicePixelRatio = 1.0;
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();
    }

    testWidgets('wide width renders the items table, not the card grid',
        (tester) async {
      // Wide screens mirror the Services screen's Items tab: a table
      // (Photo/Item/Unit/Price/Add to Cart) instead of the card grid,
      // which stays for narrow/phone widths only.
      await pumpAt(tester, 1400);

      expect(find.byKey(const Key('itemsTable')), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('cart sits beside the table at wide width', (tester) async {
      await pumpAt(tester, 1400);

      final tableBottom =
          tester.getBottomLeft(find.byKey(const Key('itemsTable'))).dy;
      final cartTop = tester.getTopLeft(find.text('Current order')).dy;

      // Side-by-side: the cart header starts near the top, well before the
      // table (which fills the full column height) ends.
      expect(cartTop, lessThan(tableBottom));
    });

    testWidgets('narrow width renders the card grid, not the table',
        (tester) async {
      await pumpAt(tester, 390);

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byKey(const Key('itemsTable')), findsNothing);
    });

    testWidgets('cart stacks below the grid at phone width', (tester) async {
      await pumpAt(tester, 390);

      final gridBottom = tester.getBottomLeft(find.byType(GridView)).dy;
      final cartTop = tester.getTopLeft(find.text('Current order')).dy;

      // Stacked: the cart section starts at or after where the grid ends.
      expect(cartTop, greaterThanOrEqualTo(gridBottom));
    });

    int columnsAt(WidgetTester tester) {
      final delegate = tester.widget<GridView>(find.byType(GridView)).gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      return delegate.crossAxisCount;
    }

    testWidgets(
        'the card grid uses fewer columns at phone width than at tablet width',
        (tester) async {
      // Both widths stay below SidebarNavigation.contentWideBreakpoint (760)
      // so the card grid — not the table — renders at either; only the
      // grid's own internal breakpoint (_gridColumnsFor) varies here.
      await pumpAt(tester, 700);
      final tabletColumns = columnsAt(tester);

      await pumpAt(tester, 390);
      final phoneColumns = columnsAt(tester);

      expect(phoneColumns, lessThan(tabletColumns));
    });
  });

  group('NewOrderScreen header', () {
    testWidgets(
        'the header has just the title — no back arrow, no dead help icon',
        (tester) async {
      // The header used to carry a back-arrow IconButton next to the title
      // (redundant with the always-visible sidebar's own Dashboard link) —
      // removed at the user's request.
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(garments: _catalogue);
      await tester.pumpWidget(host(provider, const NewOrderScreen()));
      await tester.pump();

      final headerRow =
          tester.widget<Row>(find.byKey(const Key('newOrderHeader')));

      expect(headerRow.children.length, 1);
      expect(
        find.descendant(
          of: find.byWidget(headerRow),
          matching: find.byIcon(Icons.arrow_back_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byWidget(headerRow),
          matching: find.byIcon(Icons.help_outline_rounded),
        ),
        findsNothing,
      );
    });
  });
}
