import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/order_detail_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

OrderModel order({
  String status = OrderStatus.placed,
  String deliveryType = DeliveryType.storePickup,
  double subtotal = 150,
  double deliveryCharge = 0,
  double discount = 0,
  double total = 150,
  double paid = 0,
  double due = 150,
  bool express = false,
  String createdBy = '',
  String source = 'WEB',
  String? assignedAgent,
  DateTime? scheduled,
  String? notes,
  Map<String, DateTime>? stages,
}) {
  final placedAt = DateTime(2026, 7, 30, 22, 51);
  return OrderModel(
    id: 'o1',
    orderNumber: 'WA3P-00002',
    customerName: 'Me',
    customerPhone: '+914277905904',
    status: status,
    paymentStatus: due <= 0 ? PaymentStatus.paid : PaymentStatus.unpaid,
    paymentMethod: 'CASH',
    deliveryType: deliveryType,
    source: source,
    subtotal: subtotal,
    deliveryCharge: deliveryCharge,
    discountAmount: discount,
    totalAmount: total,
    paidAmount: paid,
    dueAmount: due,
    express: express,
    notes: notes,
    scheduledDate: scheduled,
    assignedAgentName: assignedAgent,
    createdBy: createdBy,
    createdAt: placedAt,
    stageTimestamps: stages ?? {OrderStatus.placed: placedAt},
    auditLog: [TimelineEntry(OrderStatus.placed, placedAt)],
    items: const [
      OrderItemModel(
        itemTitle: 'Suit (2 Piece)',
        serviceType: 'Iron Only',
        status: OrderStatus.placed,
        quantity: 1,
        unit: 'PIECE',
        unitPrice: 150,
        totalPrice: 150,
      ),
    ],
  );
}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(1600, 1600);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester, OrderModel o) async {
    final provider = AppProvider(autoLoad: false)..seedForTest(orders: [o]);
    await tester.pumpWidget(
      host(provider, OrderDetailScreen(order: o, onBack: () {})),
    );
    await tester.pump();
  }

  group('step bar', () {
    testWidgets('a store-pickup order ends Ready for Pickup / Picked Up',
        (tester) async {
      // Captured from the live #WA3P-00002.
      await pump(tester, order(deliveryType: DeliveryType.storePickup));

      expect(find.text('Ready for Pickup'), findsOneWidget);
      expect(find.text('Picked Up'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
    });

    testWidgets('a home-delivery order ends Ready / Delivered', (tester) async {
      await pump(tester, order(deliveryType: DeliveryType.homeDelivery));

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('Picked Up'), findsNothing);
    });

    testWidgets('Out for Delivery is not a step — the live bar collapses it',
        (tester) async {
      await pump(tester, order(
        deliveryType: DeliveryType.homeDelivery,
        status: OrderStatus.outForDelivery,
      ));

      // The status pill still names the real status; the step bar has no such
      // step, so it counts as Ready for progress purposes.
      expect(find.text('Ready'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OrderDetailScreen),
          matching: find.text('Out for Delivery'),
        ),
        findsOneWidget, // the pill only
      );
    });

    testWidgets('the old hardcoded Washing step is gone', (tester) async {
      await pump(tester, order(status: OrderStatus.processing));

      expect(find.text('Washing'), findsNothing);
      expect(find.text('Processing'), findsWidgets);
    });

    testWidgets('a cancelled order shows no step bar', (tester) async {
      await pump(tester, order(status: OrderStatus.cancelled));

      expect(find.text('This order was cancelled.'), findsOneWidget);
      expect(find.text('Order Placed'), findsNothing);
    });
  });

  group('totals', () {
    testWidgets('no delivery row when there is no delivery charge',
        (tester) async {
      await pump(tester, order(deliveryCharge: 0));

      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Delivery'), findsNothing);
    });

    testWidgets('a delivery charge is its own line', (tester) async {
      await pump(tester, order(
        deliveryType: DeliveryType.homeDelivery,
        deliveryCharge: 50,
        total: 200,
      ));

      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('₹50'), findsOneWidget);
      // Once in the totals block, once in the payment card.
      expect(find.text('₹200'), findsNWidgets(2));
    });

    testWidgets('the invented always-zero rows are gone', (tester) async {
      await pump(tester, order());

      expect(find.text('Express Delivery Fee (1.5x)'), findsNothing);
      expect(find.text('Tax (GST Included)'), findsNothing);
    });
  });

  group('Items', () {
    testWidgets('each line carries its own status badge', (tester) async {
      // The model has always parsed OrderItem.status; nothing rendered it.
      await pump(tester, order());

      expect(find.text('Suit (2 Piece)'), findsOneWidget);
      // "Placed" renders three times with this fixture: the order-level pill,
      // the Timeline entry, and now the item's own badge — all PLACED, since
      // the fixture's item status matches the order.
      expect(find.text('Placed'), findsNWidgets(3));
    });
  });

  group('fulfilment rail', () {
    testWidgets('store pickup gets FULFILMENT and no agent row', (tester) async {
      await pump(tester, order(
        deliveryType: DeliveryType.storePickup,
        scheduled: DateTime(2026, 7, 31),
      ));

      expect(find.text('FULFILMENT'), findsOneWidget);
      expect(find.text('Expected Ready'), findsOneWidget);
      expect(find.text('Jul 31, 2026'), findsOneWidget);
      expect(find.text('Assigned Agent'), findsNothing);
    });

    testWidgets('home delivery gets DELIVERY & ROUTE and an agent row',
        (tester) async {
      await pump(tester, order(deliveryType: DeliveryType.homeDelivery));

      expect(find.text('DELIVERY & ROUTE'), findsOneWidget);
      expect(find.text('Assigned Agent'), findsOneWidget);
      expect(find.text('No agent assigned'), findsOneWidget);
    });

    testWidgets('the hardcoded Bengaluru address is gone', (tester) async {
      await pump(tester, order());

      expect(find.text('Hbr layout, Bengaluru - 560064'), findsNothing);
    });
  });

  group('provenance', () {
    testWidgets('the timeline names the person who raised the order',
        (tester) async {
      await pump(tester, order(createdBy: 'abhishek kumar'));

      expect(find.text('Created by abhishek kumar'), findsOneWidget);
    });

    testWidgets('a blank created_by falls back to the channel', (tester) async {
      await pump(tester, order(createdBy: '', source: 'MOBILE_APP'));

      expect(find.text('Created by Mobile App'), findsOneWidget);
    });
  });

  group('Update Status availability', () {
    testWidgets('is disabled once the order is Delivered', (tester) async {
      // Nothing left to move it to — that transition now only happens via
      // Collect Payment — so re-opening the dialog here would be a dead end.
      await pump(tester, order(status: OrderStatus.delivered));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update Status'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('is disabled once the order is Cancelled', (tester) async {
      await pump(tester, order(status: OrderStatus.cancelled));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update Status'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('stays enabled for every other status', (tester) async {
      await pump(tester, order(status: OrderStatus.ready));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update Status'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('Edit availability', () {
    testWidgets('is disabled once the order is Delivered', (tester) async {
      // The order's own details shouldn't change after handoff either.
      await pump(tester, order(status: OrderStatus.delivered));

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Edit'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('stays enabled for every other status', (tester) async {
      await pump(tester, order(status: OrderStatus.ready));

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Edit'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('Update Status dialog', () {
    Future<void> openDialog(WidgetTester tester, OrderModel o) async {
      await pump(tester, o);
      await tester.tap(find.widgetWithText(FilledButton, 'Update Status'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the type-aware stages with the current one badged',
        (tester) async {
      await openDialog(tester, order(deliveryType: DeliveryType.storePickup));

      expect(find.text('New Status'), findsOneWidget);
      expect(find.text('CURRENT'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Ready for Pickup'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers Cancelled as irreversible', (tester) async {
      await openDialog(tester, order());

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('This action cannot be undone'), findsOneWidget);
    });

    testWidgets('keeps the optional notes field', (tester) async {
      await openDialog(tester, order());

      expect(find.text('Notes (optional)'), findsOneWidget);
      expect(find.text('Add any notes about this status change...'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
        findsOneWidget,
      );

      // The note is optional: a change goes through with the field left empty.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Processing'),
      ));
      await tester.pump();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Update Status'),
      ));
      await tester.pump();

      expect(find.text('That is already the current status.'), findsNothing);
    });

    testWidgets('keeps Share via WhatsApp', (tester) async {
      await openDialog(tester, order());

      expect(find.text('Share via WhatsApp'), findsOneWidget);
    });

    testWidgets('refuses to re-apply the status the order already has',
        (tester) async {
      await openDialog(tester, order(status: OrderStatus.placed));

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Update Status'),
      ));
      await tester.pump();

      expect(find.text('That is already the current status.'), findsOneWidget);
    });

    testWidgets(
        'does not offer Delivered/Picked Up — that now only happens via Collect Payment',
        (tester) async {
      await openDialog(tester, order(deliveryType: DeliveryType.homeDelivery));

      expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('Delivered')),
        findsNothing,
      );
      expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('Picked Up')),
        findsNothing,
      );
      expect(
        find.textContaining('Collect Payment" on the Payment card'),
        findsOneWidget,
      );
    });
  });

  group('Edit dialog', () {
    testWidgets('opens prefilled from the order', (tester) async {
      await pump(tester, order());

      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Order'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Me'), findsOneWidget);
      expect(find.widgetWithText(TextField, '+914277905904'), findsOneWidget);
    });

    testWidgets('rejects an empty customer name', (tester) async {
      await pump(tester, order());

      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Me'), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pump();

      expect(find.text('Give the order a customer name.'), findsOneWidget);
    });
  });

  group('payment', () {
    testWidgets('Collect Payment is offered whenever there is money owed',
        (tester) async {
      // No gate on delivery status anymore — Collect Payment is now how an
      // order *reaches* Delivered, so it must be pressable long before then.
      await pump(tester, order(due: 150, status: OrderStatus.processing));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Collect Payment'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets(
        'a not-yet-delivered order with nothing owed still offers Collect Payment',
        (tester) async {
      // Even fully paid up front, the order still needs to be handed over —
      // Collect Payment is also how that final Delivered transition happens.
      await pump(tester, order(paid: 150, due: 0, status: OrderStatus.ready));

      expect(find.text('Collect Payment'), findsOneWidget);
    });

    testWidgets('a delivered, fully settled order offers nothing to collect',
        (tester) async {
      await pump(tester,
          order(paid: 150, due: 0, status: OrderStatus.delivered));

      expect(find.text('Collect Payment'), findsNothing);
      expect(find.text('Balance Due'), findsOneWidget);
    });

    Future<void> openCollectPayment(WidgetTester tester, OrderModel o) async {
      await pump(tester, o);
      await tester.tap(find.widgetWithText(FilledButton, 'Collect Payment'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'the dialog offers Full/Partial/Pay Later and Cash/UPI/Card, defaulting to Full',
        (tester) async {
      await openCollectPayment(
          tester, order(due: 150, status: OrderStatus.ready));

      for (final label in ['Full', 'Partial', 'Pay Later', 'Cash', 'UPI', 'Card']) {
        expect(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.text(label)),
          findsOneWidget,
        );
      }

      final amountField = tester.widget<TextField>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ));
      expect(amountField.enabled, isFalse);
      expect(amountField.controller!.text, '150');
    });

    testWidgets('selecting Partial enables the amount field for editing',
        (tester) async {
      await openCollectPayment(
          tester, order(due: 150, status: OrderStatus.ready));

      await tester.tap(find.text('Partial'));
      await tester.pump();

      final amountField = tester.widget<TextField>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ));
      expect(amountField.enabled, isTrue);
    });

    testWidgets('selecting Pay Later zeroes the amount and locks the method',
        (tester) async {
      await openCollectPayment(
          tester, order(due: 150, status: OrderStatus.ready));

      await tester.tap(find.text('Pay Later'));
      await tester.pump();

      final amountField = tester.widget<TextField>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ));
      expect(amountField.enabled, isFalse);
      expect(amountField.controller!.text, '0');

      final cashChip = tester.widget<ChoiceChip>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ChoiceChip, 'Cash'),
      ));
      expect(cashChip.onSelected, isNull);
    });

    testWidgets(
        'a Partial amount over the balance due is rejected before any save',
        (tester) async {
      await openCollectPayment(
          tester, order(due: 150, status: OrderStatus.ready));

      await tester.tap(find.text('Partial'));
      await tester.pump();
      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '999',
      );
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Collect Payment'),
      ));
      await tester.pump();

      expect(find.text('Amount can\'t exceed the balance due.'), findsOneWidget);
    });
  });

  group('header responsive layout', () {
    Future<void> pumpAt(WidgetTester tester, double width, OrderModel o) async {
      tester.view
        ..physicalSize = Size(width, 1200)
        ..devicePixelRatio = 1.0;
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: [o]);
      await tester.pumpWidget(
        host(provider, OrderDetailScreen(order: o, onBack: () {})),
      );
      await tester.pump();
    }

    testWidgets('shows the labeled header buttons at wide width',
        (tester) async {
      await pumpAt(tester, 1400, order());

      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Print Receipt'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });

    testWidgets('collapses secondary actions into an overflow menu at phone width',
        (tester) async {
      await pumpAt(tester, 390, order());

      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Print Receipt'), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      // Update Status stays a visible primary action, not folded into the menu.
      expect(find.byIcon(Icons.autorenew_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Print Receipt'), findsOneWidget);
    });
  });

  group('generate tags bottom section', () {
    testWidgets('renders Generate Tags card at the bottom of order details',
        (tester) async {
      await pump(tester, order());

      expect(find.byKey(const ValueKey('order-detail-tags-card')),
          findsOneWidget);
      expect(find.text('Generate Tags'), findsOneWidget);
      expect(
          find.text('Print QR code or barcode garment & basket tags for this order'),
          findsOneWidget);
      expect(find.text('QR code'), findsOneWidget);
      expect(find.text('Barcode'), findsOneWidget);
      expect(find.text('Service Tags'), findsOneWidget);
      expect(find.text('Item Tags'), findsOneWidget);
      expect(find.text('Generate Preview'), findsOneWidget);
    });

    testWidgets('allows generating preview and completing tags in order detail',
        (tester) async {
      var backCalled = false;
      final o = order();
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(orders: [o], shop: {'name': 'Washing'});
      await tester.pumpWidget(
        host(provider,
            OrderDetailScreen(order: o, onBack: () => backCalled = true)),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Generate Preview'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
      await tester.pump();

      expect(find.text('Tags Ready & Generated'), findsOneWidget);
      expect(find.text('Back to Orders'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Back to Orders'));
      await tester.pump();

      expect(backCalled, isTrue);
    });
  });
}
