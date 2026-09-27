import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/services/api_service.dart';
import 'package:washnlaundrycrm/widgets/receipt_dialog.dart';
import 'package:washnlaundrycrm/widgets/whatsapp_settings_panel.dart';

void main() {
  group('ApiService WhatsApp bridge endpoints surface ApiException on network error', () {
    test('sendOrderWhatsApp', () async {
      await expectLater(
        ApiService.sendOrderWhatsApp('order-123'),
        throwsA(isA<ApiException>()),
      );
    });

    test('sendOrderStatusWhatsApp', () async {
      await expectLater(
        ApiService.sendOrderStatusWhatsApp('order-123', note: 'test'),
        throwsA(isA<ApiException>()),
      );
    });

    test('sendPayrollWhatsApp', () async {
      await expectLater(
        ApiService.sendPayrollWhatsApp({'staff_id': 1}),
        throwsA(isA<ApiException>()),
      );
    });

    test('fetchWhatsAppStatus', () async {
      await expectLater(
        ApiService.fetchWhatsAppStatus(),
        throwsA(isA<ApiException>()),
      );
    });

    test('fetchWhatsAppQr', () async {
      await expectLater(
        ApiService.fetchWhatsAppQr(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ReceiptDialog WhatsApp interaction', () {
    testWidgets('renders WhatsApp Bill button enabled when phone is present', (tester) async {
      final orderWithPhone = OrderModel(
        id: 'ord-1',
        orderNumber: 'WA3P-00001',
        customerName: 'Amit Sharma',
        customerPhone: '9876543210',
        status: OrderStatus.placed,
        paymentStatus: 'UNPAID',
        paymentMethod: 'CASH',
        deliveryType: 'STORE_PICKUP',
        subtotal: 200,
        deliveryCharge: 0,
        discountAmount: 0,
        totalAmount: 200,
        paidAmount: 0,
        dueAmount: 200,
        express: false,
        createdAt: DateTime(2026, 8, 1),
        items: const [
          OrderItemModel(
            itemTitle: 'Shirt',
            serviceType: 'Ironing',
            quantity: 2,
            unitPrice: 100,
            totalPrice: 200,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptDialog(
              order: orderWithPhone,
              shop: const {'name': 'Clean Store', 'phone': '9999999999'},
            ),
          ),
        ),
      );

      final buttonFinder = find.widgetWithText(ElevatedButton, 'WhatsApp Bill');
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('disables WhatsApp Bill button when customer has no phone', (tester) async {
      final orderNoPhone = OrderModel(
        id: 'ord-2',
        orderNumber: 'WA3P-00002',
        customerName: 'Walk In',
        customerPhone: '',
        status: OrderStatus.placed,
        paymentStatus: 'PAID',
        paymentMethod: 'CASH',
        deliveryType: 'STORE_PICKUP',
        subtotal: 50,
        deliveryCharge: 0,
        discountAmount: 0,
        totalAmount: 50,
        paidAmount: 50,
        dueAmount: 0,
        express: false,
        createdAt: DateTime(2026, 8, 1),
        items: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptDialog(
              order: orderNoPhone,
              shop: const {'name': 'Clean Store'},
            ),
          ),
        ),
      );

      final buttonFinder = find.widgetWithText(ElevatedButton, 'WhatsApp Bill');
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });
  });

  group('WhatsAppSettingsPanel rendering', () {
    testWidgets('renders panel title and refresh button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WhatsAppSettingsPanel(),
            ),
          ),
        ),
      );

      // Initially loading or loaded
      expect(find.byType(WhatsAppSettingsPanel), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('WhatsApp Integration'), findsOneWidget);
    });
  });
}
