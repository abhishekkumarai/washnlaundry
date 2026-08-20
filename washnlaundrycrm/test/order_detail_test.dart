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
    testWidgets('Collect Payment is offered only while money is owed',
        (tester) async {
      await pump(tester, order(due: 150));
      expect(find.text('Collect Payment'), findsOneWidget);
    });

    testWidgets('a settled order offers nothing to collect', (tester) async {
      await pump(tester, order(paid: 150, due: 0));

      expect(find.text('Collect Payment'), findsNothing);
      expect(find.text('Balance Due'), findsOneWidget);
    });
  });
}
