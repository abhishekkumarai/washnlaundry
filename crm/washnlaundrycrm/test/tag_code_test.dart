import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/utils/tag_code.dart';

void main() {
  group('TagCode.encode', () {
    test('appends a zero-padded garment number', () {
      expect(TagCode.encode('SPOT-00001', 2), 'SPOT-00001-02');
      expect(TagCode.encode('SPOT2-100000', 12), 'SPOT2-100000-12');
      expect(TagCode.encode('WA3P-00011', 105), 'WA3P-00011-105');
    });

    test('every realistic tag code is a valid Code 128 barcode', () {
      for (final code in [
        TagCode.encode('SPOT-00001', 1),
        TagCode.encode('SPOT2-100000', 99),
        TagCode.encode('A1B2C3D4-123456', 120),
      ]) {
        expect(Barcode.code128().isValid(code), isTrue, reason: code);
        expect(code.length, lessThanOrEqualTo(22));
      }
    });
  });

  group('TagCode.candidates', () {
    test('a tag code also offers its order number', () {
      expect(TagCode.candidates('SPOT-00001-02'),
          ['SPOT-00001-02', 'SPOT-00001']);
    });

    test('a bare order number is not shortened', () {
      expect(TagCode.candidates('SPOT-00001'), ['SPOT-00001']);
      expect(TagCode.candidates(' wa3p-00011 '), ['wa3p-00011']);
    });

    test('an old tracking URL yields the order number', () {
      expect(
          TagCode.candidates('https://app.washnlaundry.com/track/WA3P-00011'),
          ['WA3P-00011']);
    });

    test('empty input yields nothing', () {
      expect(TagCode.candidates('   '), isEmpty);
    });
  });
}
