import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/orders_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

OrderModel order({
  required String id,
  String number = 'WASH-00001',
  String name = 'Customer',
  String deliveryType = DeliveryType.storePickup,
  String source = 'WEB',
  String status = OrderStatus.placed,
  String paymentStatus = PaymentStatus.paid,
  bool overdue = false,
  String itemServiceType = 'Ironing',
}) {
  return OrderModel(
    id: id,
    orderNumber: number,
    customerName: name,
    customerPhone: '9000000000',
    status: status,
    paymentStatus: paymentStatus,
    paymentMethod: 'CASH',
    deliveryType: deliveryType,
    source: source,
    totalAmount: 100,
    paidAmount: paymentStatus == PaymentStatus.paid ? 100 : 0,
    dueAmount: paymentStatus == PaymentStatus.paid ? 0 : 100,
    express: false,
    isOverdue: overdue,
    createdAt: DateTime.now(),
    items: [
      OrderItemModel(
        itemTitle: 'Shirt',
        serviceType: itemServiceType,
        quantity: 1,
        unit: 'PIECE',
        unitPrice: 100,
        totalPrice: 100,
      ),
    ],
  );
}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(1600, 1200);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  // o1: everyday counter order. o2: the one every "extra" dimension should
  // be able to isolate on its own — carried, from the public page, overdue,
  // unpaid, delivered, Wash & Fold.
  final orders = [
    order(
      id: 'o1',
      number: 'WASH-00001',
      deliveryType: DeliveryType.storePickup,
      source: 'WEB',
      status: OrderStatus.placed,
      itemServiceType: 'Ironing',
    ),
    order(
      id: 'o2',
      number: 'WASH-00002',
      deliveryType: DeliveryType.homeDelivery,
      source: 'PUBLIC_PAGE',
      status: OrderStatus.delivered,
      paymentStatus: PaymentStatus.unpaid,
      overdue: true,
      itemServiceType: 'Wash & Fold',
    ),
  ];

  Future<AppProvider> pumpOrders(WidgetTester tester) async {
    final provider = AppProvider(autoLoad: false)
      ..seedForTest(
        orders: orders,
        categories: const [
          GarmentCategoryModel(id: 'c1', name: 'Ironing'),
          GarmentCategoryModel(id: 'c2', name: 'Wash & Fold'),
        ],
      );
    await tester.pumpWidget(host(provider, const OrdersScreen()));
    await tester.pump();
    return provider;
  }

  group('OrdersScreen Filters', () {
    testWidgets('was a dead button — now opens the real app\'s own filter dialog',
        (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Filter Orders'), findsOneWidget);
      expect(find.text('ATTENTION NEEDED'), findsOneWidget);
      expect(find.text('ORDER SOURCE'), findsOneWidget);
      expect(find.text('ORDER TYPE'), findsOneWidget);
      expect(find.text('SERVICE TYPE'), findsOneWidget);
      // "STATUS" also labels the table's own column header.
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('STATUS')),
        findsOneWidget,
      );
    });

    testWidgets('Order Type narrows the table and Apply Filters commits it',
        (tester) async {
      await pumpOrders(tester);

      expect(find.text('#WASH-00001'), findsOneWidget);
      expect(find.text('#WASH-00002'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Filters'));
      await tester.pumpAndSettle();

      // "Home Delivery" also appears in the table's TYPE column (o2), so
      // scope the tap to the option card inside the dialog.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Home Delivery'),
      ));
      await tester.tap(find.widgetWithText(FilledButton, 'Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('#WASH-00001'), findsNothing);
      expect(find.text('#WASH-00002'), findsOneWidget);
      expect(find.text('Filters (1)'), findsOneWidget);
    });

    testWidgets('Overdue Orders isolates the overdue one', (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Filters'));
      await tester.pumpAndSettle();
      // "Overdue Orders" also labels the main chip row's own tab.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Overdue Orders'),
      ));
      await tester.tap(find.widgetWithText(FilledButton, 'Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('#WASH-00001'), findsNothing);
      expect(find.text('#WASH-00002'), findsOneWidget);
    });

    testWidgets('Order Source: Online isolates the public-page order',
        (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online'));
      await tester.tap(find.widgetWithText(FilledButton, 'Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('#WASH-00001'), findsNothing);
      expect(find.text('#WASH-00002'), findsOneWidget);
    });

    testWidgets('Status radio narrows the table the same way the main chips do',
        (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Filters'));
      await tester.pumpAndSettle();
      final deliveredRadio = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delivered'),
      );
      await tester.ensureVisible(deliveredRadio);
      await tester.pumpAndSettle();
      await tester.tap(deliveredRadio);
      await tester.tap(find.widgetWithText(FilledButton, 'Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('#WASH-00001'), findsNothing);
      expect(find.text('#WASH-00002'), findsOneWidget);
      // Status writes back into the same chip row, not a second filter —
      // the Delivered chip itself should now read as selected.
      final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Delivered'));
      expect(chip.selected, isTrue);
    });

    testWidgets('closing with the × discards the in-dialog change', (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Filters'));
      await tester.pumpAndSettle();
      // "Overdue Orders" also labels the main chip row's own tab.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Overdue Orders'),
      ));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('#WASH-00001'), findsOneWidget);
      expect(find.text('#WASH-00002'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.textContaining('Filters ('), findsNothing);
    });

    testWidgets('Reset clears the scratch state but still needs Apply',
        (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Filters'));
      await tester.pumpAndSettle();
      // "Overdue Orders" also labels the main chip row's own tab.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Overdue Orders'),
      ));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await tester.pump();

      // Reset alone doesn't close the dialog or apply anything.
      expect(find.text('Filter Orders'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('#WASH-00001'), findsOneWidget);
      expect(find.text('#WASH-00002'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
    });
  });

  group('OrdersScreen responsive layout', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view
        ..physicalSize = Size(width, 1200)
        ..devicePixelRatio = 1.0;
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(
          orders: orders,
          categories: const [
            GarmentCategoryModel(id: 'c1', name: 'Ironing'),
            GarmentCategoryModel(id: 'c2', name: 'Wash & Fold'),
          ],
        );
      await tester.pumpWidget(host(provider, const OrdersScreen()));
      await tester.pump();
    }

    testWidgets('shows the table header at wide width', (tester) async {
      await pumpAt(tester, 1400);

      expect(find.text('ORDER'), findsOneWidget);
      // The narrow card's "Updated {time}" label doesn't exist in the table
      // row, which shows the bare relative time instead.
      expect(find.textContaining('Updated '), findsNothing);
    });

    testWidgets('shows cards instead of the table at phone width',
        (tester) async {
      await pumpAt(tester, 390);

      expect(find.text('ORDER'), findsNothing);
      expect(find.textContaining('Updated '), findsWidgets);
    });

    testWidgets('New Order collapses to an icon-only button at phone width',
        (tester) async {
      await pumpAt(tester, 390);

      expect(find.text('New Order'), findsNothing);
      expect(find.byIcon(Icons.add), findsWidgets);
    });
  });

  group('OrdersScreen Export', () {
    testWidgets('was a dead button — now exports the filtered rows as CSV',
        (tester) async {
      // `flutter test` runs on the VM, not web, so `downloadCsv` resolves to
      // the non-web stub and reports it couldn't trigger a real download —
      // this pins that the button is wired up (builds the CSV, calls the
      // download hook) rather than still being `onPressed: () {}`.
      await pumpOrders(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Export'));
      await tester.pump();

      expect(find.text('Export is only available in the web app.'), findsOneWidget);
    });

    testWidgets('an empty filtered list says so instead of exporting nothing',
        (tester) async {
      final provider = await pumpOrders(tester);

      // Narrow to a status nothing matches.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cancelled'));
      await tester.pump();
      expect(provider.orders.length, 2); // sanity: shop still has orders

      await tester.tap(find.widgetWithText(OutlinedButton, 'Export'));
      await tester.pump();

      expect(find.text('No orders to export.'), findsOneWidget);
    });
  });

  group('OrdersScreen date filter', () {
    testWidgets('defaults to All time and opens a menu of presets plus Custom range',
        (tester) async {
      await pumpOrders(tester);

      expect(find.text('All time'), findsOneWidget);

      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Last Month'), findsOneWidget);
      expect(find.text('Custom range...'), findsOneWidget);
    });

    testWidgets('picking a preset updates the button label', (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This Week').last);
      await tester.pumpAndSettle();

      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('All time'), findsNothing);
    });

    testWidgets('Custom range... opens a calendar and applies the picked range',
        (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom range...'));
      await tester.pumpAndSettle();

      // The picker defaults both ends to today; confirming without changing
      // the selection should label the button with today's single date.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final today = DateFormat('MMM d').format(DateTime.now());
      expect(find.text(today), findsOneWidget);
      expect(find.text('All time'), findsNothing);
    });
  });

  group('OrdersScreen calendar heatmap', () {
    testWidgets('opens a month calendar and picking a day applies it as the filter',
        (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.byIcon(Icons.calendar_view_month_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Orders calendar'), findsOneWidget);

      final today = DateTime.now();
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();

      expect(find.text('Orders calendar'), findsNothing);
      final label = DateFormat('MMM d').format(today);
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('closing with the × leaves the date filter untouched',
        (tester) async {
      await pumpOrders(tester);

      await tester.tap(find.byIcon(Icons.calendar_view_month_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Orders calendar'), findsNothing);
      expect(find.text('All time'), findsOneWidget);
    });
  });
}
