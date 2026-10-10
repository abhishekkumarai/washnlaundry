import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/widgets/tag_generator_panel.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
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

final _otherOrder = OrderModel(
  id: 'o2',
  orderNumber: 'WA3P-00012',
  customerName: 'Geeta',
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

  Widget pumpPanel({OrderModel? order, VoidCallback? onChangeOrder}) => host(
        AppProvider(autoLoad: false)..seedForTest(shop: const {'name': 'Washing'}),
        TagGeneratorPanel(
          order: order ?? _order,
          onChangeOrder: onChangeOrder ?? () {},
        ),
      );

  group('TagGeneratorPanel configure step', () {
    testWidgets('shows which order it is generating tags for', (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      expect(find.textContaining('#WA3P-00011'), findsOneWidget);
      expect(find.textContaining('Me'), findsWidgets);
    });

    testWidgets('lists services grouped by type, not one row per item',
        (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      expect(find.text('Iron Only'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('Dry Clean'), findsOneWidget);
      expect(find.text('×1'), findsOneWidget);
    });

    testWidgets('Service Tags defaults to one tag per distinct service',
        (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      expect(find.textContaining('2 tags · one per service'), findsOneWidget);
    });

    testWidgets('Item Tags counts every physical garment', (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      expect(find.textContaining('3 tags (one per garment)'), findsOneWidget);
    });

    testWidgets('Change order calls onChangeOrder', (tester) async {
      var changed = false;
      await tester.pumpWidget(pumpPanel(onChangeOrder: () => changed = true));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Change order'));
      await tester.pump();

      expect(changed, isTrue);
    });
  });

  group('TagGeneratorPanel preview step', () {
    testWidgets('Generate Preview advances to a real step, not a dialog',
        (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Service Tags mode renders one tag per distinct service',
        (tester) async {
      await tester.pumpWidget(pumpPanel());
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
      await tester.pumpWidget(pumpPanel());
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

    testWidgets('Barcode draws a real Code 128 barcode per tag, with no fallback note',
        (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      await tester.tap(find.text('Barcode'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      expect(
          find.textContaining('Barcode format is not available'), findsNothing);
      expect(find.byType(BarcodeWidget), findsWidgets);
      expect(find.byType(QrImageView), findsNothing);
      // The code carries <order number>-<garment no.>
      expect(find.byKey(const ValueKey('tag-barcode-WA3P-00011-01')),
          findsOneWidget);
    });

    testWidgets('QR (the default) encodes the same tag code, not a URL',
        (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      expect(find.byKey(const ValueKey('tag-qr-WA3P-00011-01')), findsOneWidget);
      expect(find.byType(BarcodeWidget), findsNothing);
    });

    testWidgets('Back returns to the configure step', (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pump();

      expect(find.text('Generate Preview'), findsOneWidget);
    });

    testWidgets('Download PDF is a labelled demo stub', (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Download PDF'));
      await tester.pump();
      expect(find.text('PDF export is not available in this demo.'),
          findsOneWidget);
    });

    testWidgets('Print is a labelled demo stub', (tester) async {
      await tester.pumpWidget(pumpPanel());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Print'));
      await tester.pump();
      expect(find.text('Sent to the printer.'), findsOneWidget);
    });

    testWidgets('Complete advances to Step 3 with summary and actions',
        (tester) async {
      var changed = false;
      await tester.pumpWidget(pumpPanel(onChangeOrder: () => changed = true));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
      await tester.pump();

      expect(find.text('Tags Ready & Generated'), findsOneWidget);
      expect(find.textContaining('labels for order #WA3P-00011'), findsOneWidget);
      expect(find.text('Back to Preview'), findsOneWidget);
      expect(find.text('Print Again'), findsOneWidget);
      expect(find.text('Back to Orders'), findsOneWidget);

      // Back to Preview returns to step 2
      await tester.tap(find.widgetWithText(OutlinedButton, 'Back to Preview'));
      await tester.pump();
      expect(find.text('Back'), findsOneWidget);

      // Advance again and test Back to Orders
      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Back to Orders'));
      await tester.pump();
      expect(changed, isTrue);
    });
  });

  testWidgets(
      'a widget update to a different order (same State) resets back to '
      'configure', (tester) async {
    // Defensive: ScanScreen actually forces a fresh State per order via
    // `ValueKey(order.id)`, so this path doesn't fire there today — but
    // `didUpdateWidget` still guards any caller that updates `order` in
    // place, so it must not go on showing the old order's generated tags.
    final provider = AppProvider(autoLoad: false)
      ..seedForTest(shop: const {'name': 'Washing'});
    await tester.pumpWidget(host(
      provider,
      TagGeneratorPanel(order: _order, onChangeOrder: () {}),
    ));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Generate Preview'));
    await tester.pump();
    expect(find.text('Back'), findsOneWidget);

    await tester.pumpWidget(host(
      provider,
      TagGeneratorPanel(order: _otherOrder, onChangeOrder: () {}),
    ));
    await tester.pump();

    expect(find.text('Generate Preview'), findsOneWidget);
    expect(find.textContaining('#WA3P-00012'), findsOneWidget);
  });
}
