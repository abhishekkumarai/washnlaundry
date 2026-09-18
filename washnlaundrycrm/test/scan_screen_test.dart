import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/scan_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

final _orders = [
  OrderModel(
    id: 'o1',
    orderNumber: 'WA3P-00011',
    customerName: 'Me',
    customerPhone: '+914277905904',
    status: OrderStatus.placed,
    paymentStatus: PaymentStatus.unpaid,
    paymentMethod: 'CASH',
    totalAmount: 33,
    paidAmount: 0,
    dueAmount: 33,
    express: false,
    createdAt: DateTime(2026, 9, 17),
    items: const [
      OrderItemModel(
        itemTitle: 'Shirt',
        serviceType: 'Iron Only',
        quantity: 1,
        unitPrice: 15,
        totalPrice: 15,
      ),
    ],
  ),
  OrderModel(
    id: 'o2',
    orderNumber: 'WA3P-00012',
    customerName: 'Geeta Devi',
    customerPhone: '+919000000000',
    status: OrderStatus.placed,
    paymentStatus: PaymentStatus.unpaid,
    paymentMethod: 'CASH',
    totalAmount: 20,
    paidAmount: 0,
    dueAmount: 20,
    express: false,
    createdAt: DateTime(2026, 9, 17),
    items: const [
      OrderItemModel(
        itemTitle: 'Pant',
        serviceType: 'Iron Only',
        quantity: 1,
        unitPrice: 20,
        totalPrice: 20,
      ),
    ],
  ),
];

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(1200, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('ScanScreen tabs', () {
    testWidgets('offers both Scan and Generate Tags, defaulting to Scan',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: _orders);
      await tester.pumpWidget(host(provider, const ScanScreen()));
      await tester.pump();

      expect(find.widgetWithText(Tab, 'Scan'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Generate Tags'), findsOneWidget);
      expect(find.text('Order ID (e.g. WA3P-00011)'), findsNothing);
      expect(find.text("Camera scanning isn't available yet. Use Manual to look up an order number."),
          findsOneWidget);
    });

    testWidgets('Generate Tags tab opens on an order picker with no order chosen',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: _orders);
      await tester.pumpWidget(host(provider, const ScanScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(Tab, 'Generate Tags'));
      await tester.pumpAndSettle();

      expect(find.text('Pick an order to generate tags for'), findsOneWidget);
    });

    testWidgets('searching the picker filters by order number or customer',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: _orders);
      await tester.pumpWidget(host(provider, const ScanScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(Tab, 'Generate Tags'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'geeta');
      await tester.pump();

      expect(find.text('#WA3P-00012'), findsOneWidget);
      expect(find.text('#WA3P-00011'), findsNothing);
    });

    testWidgets('a search matching nothing says so', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: _orders);
      await tester.pumpWidget(host(provider, const ScanScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(Tab, 'Generate Tags'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump();

      expect(find.text('No order matches "zzzz".'), findsOneWidget);
    });

    testWidgets('picking a result shows the tag generator for that order',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: _orders);
      await tester.pumpWidget(host(provider, const ScanScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(Tab, 'Generate Tags'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'WA3P-00011');
      await tester.pump();
      await tester.tap(find.text('#WA3P-00011'));
      await tester.pump();

      expect(find.text('Generate Preview'), findsOneWidget);
      expect(find.textContaining('#WA3P-00011'), findsWidgets);
    });

    testWidgets('Change order returns to the picker', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: _orders);
      await tester.pumpWidget(host(provider, const ScanScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(Tab, 'Generate Tags'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'WA3P-00011');
      await tester.pump();
      await tester.tap(find.text('#WA3P-00011'));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Change order'));
      await tester.pump();

      expect(find.text('Pick an order to generate tags for'), findsOneWidget);
    });

    testWidgets('initialOrderId preselects the Generate Tags tab and the order',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(orders: _orders);
      await tester.pumpWidget(
          host(provider, const ScanScreen(initialOrderId: 'o1')));
      await tester.pumpAndSettle();

      expect(find.text('Generate Preview'), findsOneWidget);
      expect(find.textContaining('#WA3P-00011'), findsWidgets);
    });
  });
}
