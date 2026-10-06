import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/widgets/recent_activity_card.dart';

OrderModel _order({
  required String orderNumber,
  required String customerName,
  required String status,
  required String paymentStatus,
  required String deliveryType,
  required DateTime createdAt,
}) =>
    OrderModel(
      id: orderNumber,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: '+919999999999',
      status: status,
      paymentStatus: paymentStatus,
      paymentMethod: 'CASH',
      deliveryType: deliveryType,
      totalAmount: 350,
      paidAmount: 0,
      dueAmount: 350,
      express: false,
      createdAt: createdAt,
      items: const [
        OrderItemModel(
          itemTitle: 'Shirt',
          serviceType: 'Wash & Iron',
          quantity: 2,
          unitPrice: 175,
          totalPrice: 350,
        ),
      ],
    );

void main() {
  testWidgets('RecentActivityCard renders without layout exceptions and columns line up',
      (tester) async {
    final provider = AppProvider(autoLoad: false)
      ..seedForTest(orders: [
        _order(
          orderNumber: 'WASH-00017',
          customerName: 'Priya Sundaram',
          status: OrderStatus.ready,
          paymentStatus: PaymentStatus.paid,
          deliveryType: DeliveryType.homeDelivery,
          createdAt: DateTime(2026, 8, 20, 14, 32),
        ),
        // Deliberately the longest real status label ("Out for Delivery") and
        // a long customer name, to reproduce the RenderFlex overflow that a
        // short-name fixture would hide.
        _order(
          orderNumber: 'WASH-00016',
          customerName: 'A very long customer name that should ellipsize',
          status: OrderStatus.outForDelivery,
          paymentStatus: PaymentStatus.partial,
          deliveryType: DeliveryType.storePickup,
          createdAt: DateTime(2026, 8, 20, 11, 5),
        ),
        _order(
          orderNumber: 'WASH-00015',
          customerName: 'Ravi Kumar',
          status: OrderStatus.delivered,
          paymentStatus: PaymentStatus.unpaid,
          deliveryType: DeliveryType.homePickup,
          createdAt: DateTime(2026, 8, 19, 9, 15),
        ),
      ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(width: 760, child: RecentActivityCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The original bug: Expanded(child: Text('CUSTOMER')) inside a
    // horizontally-scrolling table threw "RenderFlex children have
    // non-zero flex but incoming width constraints are unbounded" on
    // every frame, and the STATUS pill's label overflowed its 110px
    // column for longer labels. Both showed up as garbled/misaligned rows
    // rather than a crash, because Flutter's renderer swallows RenderFlex
    // errors per-frame in a running app instead of tearing down the tree.
    expect(tester.takeException(), isNull);

    // The header's left edge for each column must match every data row's
    // left edge for that same column - that *is* "left alignment".
    final headerCustomerX = tester.getTopLeft(find.text('CUSTOMER')).dx;
    final row1CustomerX = tester.getTopLeft(find.text('Priya Sundaram')).dx;
    final row3CustomerX = tester.getTopLeft(find.text('Ravi Kumar')).dx;
    expect(row1CustomerX, headerCustomerX);
    expect(row3CustomerX, headerCustomerX);

    // The long status label ("Out for Delivery") must render fully, not
    // silently truncate mid-word or overflow off the pill.
    expect(find.text('Out for Delivery'), findsOneWidget);
  });
}
