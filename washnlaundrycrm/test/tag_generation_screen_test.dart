import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/tag_generation_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

/// Two garments under the same service (mirrors the live capture: a Shirt
/// and a T-Shirt, both "Iron Only") plus a third under a different service,
/// so Service Tags vs Item Tags counts are actually distinguishable.
final _order = OrderModel(
  id: 'o1',
  orderNumber: 'WA3P-00011',
  customerName: 'Me',
  customerPhone: '+914277905904',
  status: OrderStatus.placed,
  paymentStatus: PaymentStatus.unpaid,
  paymentMethod: 'CASH',
  totalAmount: 65,
  paidAmount: 0,
  dueAmount: 65,
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
    OrderItemModel(
      itemTitle: 'T-Shirt',
      serviceType: 'Iron Only',
      quantity: 1,
      unitPrice: 18,
      totalPrice: 18,
    ),
    OrderItemModel(
      itemTitle: 'Saree (Silk)',
      serviceType: 'Dry Clean',
      quantity: 1,
      unitPrice: 32,
      totalPrice: 32,
    ),
  ],
);

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

  Widget pumpScreen({VoidCallback? onBack}) => host(
        AppProvider(autoLoad: false)
          ..seedForTest(shop: const {'name': 'Washing'}),
        TagGenerationScreen(order: _order, onBack: onBack ?? () {}),
      );

  group('TagGenerationScreen configure step', () {
    testWidgets('lists services grouped by type, not one row per item',
        (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      expect(find.text('Iron Only'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('Dry Clean'), findsOneWidget);
      expect(find.text('×1'), findsOneWidget);
    });

    testWidgets('Service Tags defaults to one tag per distinct service',
        (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      expect(find.textContaining('2 tags · one per service'), findsOneWidget);
    });

    testWidgets('Item Tags counts every physical garment', (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      expect(find.textContaining('3 tags (one per garment)'), findsOneWidget);
    });

    testWidgets('shows the order, customer and item count', (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      expect(find.text('#WA3P-00011'), findsOneWidget);
      expect(find.text('Me'), findsWidgets);
    });

    testWidgets('Cancel calls onBack instead of pushing a dialog',
        (tester) async {
      var backCalled = false;
      await tester.pumpWidget(pumpScreen(onBack: () => backCalled = true));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pump();

      expect(backCalled, isTrue);
    });
  });

  group('TagGenerationScreen preview step', () {
    testWidgets('Generate Preview advances to a real step, not a dialog',
        (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Service Tags mode renders one tag per distinct service',
        (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      expect(find.text('Iron Only'), findsOneWidget);
      expect(find.text('Dry Clean'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.textContaining('2 tags · 50mm'), findsOneWidget);
    });

    testWidgets('Item Tags mode renders one tag per garment', (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      await tester.tap(find.text('Item Tags'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      expect(find.text('Iron Only'), findsNWidgets(2));
      expect(find.text('Dry Clean'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      expect(find.textContaining('3 tags · 50mm'), findsOneWidget);
    });

    testWidgets('Barcode falls back to QR with an explanatory note',
        (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      await tester.tap(find.text('Barcode'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      expect(
          find.textContaining('Barcode format is not available in this demo'),
          findsOneWidget);
    });

    testWidgets('Back returns to the configure step, not out of the screen',
        (tester) async {
      var backCalled = false;
      await tester.pumpWidget(pumpScreen(onBack: () => backCalled = true));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pump();

      expect(backCalled, isFalse);
      expect(find.text('Generate Preview'), findsOneWidget);
    });

    testWidgets('Download PDF is a labelled demo stub', (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Download PDF'));
      await tester.pump();
      expect(find.text('PDF export is not available in this demo.'),
          findsOneWidget);
    });

    testWidgets('Print is a labelled demo stub', (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Print'));
      await tester.pump();
      expect(find.text('Sent to the printer.'), findsOneWidget);
    });
  });
}
