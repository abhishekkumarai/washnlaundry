import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/utils/receipt_pdf.dart';

void main() {
  final order = OrderModel(
    id: 'o1',
    orderNumber: 'WA3P-00042',
    customerName: 'Priya Raman',
    customerPhone: '+91 98450 12345',
    status: 'PLACED',
    paymentStatus: 'PARTIAL',
    paymentMethod: 'UPI',
    deliveryType: DeliveryType.homeDelivery,
    subtotal: 640,
    deliveryCharge: 50,
    discountAmount: 40,
    totalAmount: 650,
    paidAmount: 300,
    dueAmount: 350,
    express: false,
    notes: 'Starch on shirts',
    scheduledDate: DateTime(2026, 10, 20),
    createdAt: DateTime(2026, 10, 17, 18, 5),
    items: const [
      OrderItemModel(
          itemTitle: 'Shirt',
          serviceType: 'Wash & Iron',
          quantity: 4,
          unitPrice: 40,
          totalPrice: 160),
      OrderItemModel(
          itemTitle: 'Silk Saree (heavy embroidery)',
          serviceType: 'Dry Clean',
          quantity: 1,
          unitPrice: 350,
          totalPrice: 350),
      OrderItemModel(
          itemTitle: 'Regular Cloths',
          serviceType: 'Wash & Fold',
          quantity: 2,
          unit: 'KG',
          unitPrice: 65,
          totalPrice: 130),
    ],
  );
  const shop = {
    'name': 'WashNLaundry Express',
    'address': '12, 4th Cross, Indiranagar',
    'city': 'Bengaluru',
    'pin_code': '560038',
    'phone': '+91 98765 43210',
    'gstin': '29AAAAA0000A1Z5',
  };

  test('builds an 80mm receipt PDF without network fonts', () async {
    final bytes = await ReceiptPdf.build(order, shop,
        theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
        symbol: 'Rs.');
    final out = Platform.environment['RECEIPT_PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Roll format: 80mm (226.77pt) wide.
    expect(String.fromCharCodes(bytes), matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+226\.77')));
  });

  test('tracking URL uses the order number', () {
    expect(ReceiptPdf.trackingUrl(order),
        'https://app.washnlaundry.com/track/WA3P-00042');
  });
}
