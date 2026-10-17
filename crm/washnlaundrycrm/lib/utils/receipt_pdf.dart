import 'dart:async';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/order_model.dart';
import 'money.dart';

/// The order receipt as an 80mm thermal-roll PDF.
///
/// One layout serves both the PDF and the thermal printer: [printReceipt]
/// opens the browser's print dialog, where the shop picks its thermal printer
/// (through the printer's OS driver) or "Save as PDF". The page is 80mm wide
/// and as tall as the receipt, black on white only — thermal heads have no grey.
class ReceiptPdf {
  ReceiptPdf._();

  /// 80mm paper; a 72mm print area is what 80mm printers actually print.
  static final PdfPageFormat format =
      PdfPageFormat.roll80.copyWith(marginLeft: 4 * PdfPageFormat.mm,
          marginRight: 4 * PdfPageFormat.mm,
          marginTop: 4 * PdfPageFormat.mm,
          marginBottom: 8 * PdfPageFormat.mm);

  static String trackingUrl(OrderModel order) =>
      'https://app.washnlaundry.com/track/${order.orderNumber}';

  /// Opens the print dialog with the receipt. Returns false if the browser
  /// refused (e.g. a popup blocker), so the caller can say so.
  static Future<bool> printReceipt(
      OrderModel order, Map<String, dynamic>? shop) {
    return Printing.layoutPdf(
      name: 'Receipt-${order.orderNumber}',
      format: format,
      onLayout: (_) => build(order, shop),
    );
  }

  /// Built-in PDF fonts have no ₹ glyph, so a Unicode font is fetched (and
  /// cached by `printing`). Offline, fall back to the built-in font and "Rs."
  static Future<(pw.ThemeData, String)> _theme() async {
    try {
      final regular = await PdfGoogleFonts.notoSansRegular()
          .timeout(const Duration(seconds: 6));
      final bold = await PdfGoogleFonts.notoSansBold()
          .timeout(const Duration(seconds: 6));
      return (pw.ThemeData.withFont(base: regular, bold: bold), Money.symbol);
    } catch (_) {
      final symbol = Money.symbol == '₹' ? 'Rs.' : Money.symbol;
      return (pw.ThemeData.withFont(
          base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()), symbol);
    }
  }

  static String _s(Map<String, dynamic>? shop, String key) =>
      (shop?[key] as String?)?.trim() ?? '';

  static Future<Uint8List> build(
      OrderModel order, Map<String, dynamic>? shop,
      {pw.ThemeData? theme, String? symbol}) async {
    if (theme == null || symbol == null) {
      final loaded = await _theme();
      theme ??= loaded.$1;
      symbol ??= loaded.$2;
    }
    final cur = symbol;
    String money(num v) => '$cur${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

    final shopName = _s(shop, 'name').isEmpty ? 'WashNLaundry' : _s(shop, 'name');
    final address = _s(shop, 'address');
    final city = _s(shop, 'city');
    final pin = _s(shop, 'pin_code');
    final cityLine = [
      if (city.isNotEmpty && !address.toLowerCase().contains(city.toLowerCase()))
        city,
      if (pin.isNotEmpty && !address.contains(pin)) pin,
    ].join(' - ');
    final phone = _s(shop, 'phone');
    final gstin = _s(shop, 'gstin');

    const small = pw.TextStyle(fontSize: 7.5);
    const body = pw.TextStyle(fontSize: 8.5);
    final bold = pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold);

    pw.Widget rule() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Divider(
              height: 1, thickness: 0.6, borderStyle: pw.BorderStyle.dashed),
        );

    pw.Widget kv(String k, String v, {bool strong = false, double size = 8.5}) {
      final style = pw.TextStyle(
          fontSize: size,
          fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal);
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(k, style: style),
            pw.SizedBox(width: 6),
            pw.Flexible(
                child: pw.Text(v, style: style, textAlign: pw.TextAlign.right)),
          ],
        ),
      );
    }

    final created = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt.toLocal());
    final due = order.scheduledDate == null
        ? null
        : DateFormat('dd MMM yyyy').format(order.scheduledDate!.toLocal());
    final pieces = order.items.fold<int>(0, (n, it) => n + it.quantity);

    final doc = pw.Document(
        theme: theme, title: 'Receipt #${order.orderNumber}', author: shopName);
    doc.addPage(pw.Page(
      pageFormat: format,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Shop header
          pw.Text(shopName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          if (address.isNotEmpty)
            pw.Text(address, textAlign: pw.TextAlign.center, style: small),
          if (cityLine.isNotEmpty)
            pw.Text(cityLine, textAlign: pw.TextAlign.center, style: small),
          if (phone.isNotEmpty)
            pw.Text('Ph: $phone', textAlign: pw.TextAlign.center, style: small),
          if (gstin.isNotEmpty)
            pw.Text('GSTIN: $gstin',
                textAlign: pw.TextAlign.center, style: small),
          rule(),

          // Order + customer
          pw.Text('ORDER #${order.orderNumber}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          kv('Date', created),
          kv('Customer', order.customerName),
          if (order.customerPhone.isNotEmpty) kv('Phone', order.customerPhone),
          kv('Type', order.deliveryTypeLabel + (order.express ? ' (Express)' : '')),
          if (due != null) kv('Due', due),
          rule(),

          // Items: name (+ service) | qty x rate | amount
          pw.Row(children: [
            pw.Expanded(child: pw.Text('ITEM', style: bold)),
            pw.SizedBox(
                width: 46,
                child: pw.Text('QTY', style: bold, textAlign: pw.TextAlign.center)),
            pw.SizedBox(
                width: 46,
                child: pw.Text('AMT', style: bold, textAlign: pw.TextAlign.right)),
          ]),
          pw.SizedBox(height: 2),
          for (final it in order.items)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(it.itemTitle, style: body),
                        if (it.serviceType.isNotEmpty)
                          pw.Text(it.serviceType, style: small),
                      ],
                    ),
                  ),
                  pw.SizedBox(
                    width: 46,
                    child: pw.Column(children: [
                      pw.Text('${it.quantity} ${it.unitShortLabel}'.trim(),
                          style: body, textAlign: pw.TextAlign.center),
                      pw.Text('@ ${money(it.unitPrice)}',
                          style: small, textAlign: pw.TextAlign.center),
                    ]),
                  ),
                  pw.SizedBox(
                      width: 46,
                      child: pw.Text(money(it.totalPrice),
                          style: body, textAlign: pw.TextAlign.right)),
                ],
              ),
            ),
          rule(),

          // Totals
          kv('Items / pieces', '${order.items.length} / $pieces', size: 8),
          kv('Subtotal', money(order.subtotal)),
          if (order.deliveryCharge > 0)
            kv('Delivery', money(order.deliveryCharge)),
          if (order.discountAmount > 0)
            kv('Discount', '- ${money(order.discountAmount)}'),
          pw.SizedBox(height: 2),
          kv('TOTAL', money(order.totalAmount), strong: true, size: 11),
          kv('Paid${order.paymentMethod.isEmpty ? '' : ' (${PaymentMethod.label(order.paymentMethod)})'}',
              money(order.paidAmount)),
          if (order.dueAmount > 0)
            kv('Balance due', money(order.dueAmount), strong: true),
          kv('Payment', order.paymentStatusLabel, size: 8),
          if ((order.notes ?? '').trim().isNotEmpty) ...[
            rule(),
            pw.Text('Note: ${order.notes!.trim()}', style: small),
          ],
          rule(),

          // Tracking QR
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: trackingUrl(order),
              width: 90,
              height: 90,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text('Scan to track your order',
              textAlign: pw.TextAlign.center, style: small),
          pw.SizedBox(height: 6),
          pw.Text('Thank you! Please bring this receipt at pickup.',
              textAlign: pw.TextAlign.center, style: bold),
        ],
      ),
    ));
    return doc.save();
  }
}
