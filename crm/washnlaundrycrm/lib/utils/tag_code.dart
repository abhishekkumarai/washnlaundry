/// What a garment tag encodes, and how a scan is turned back into an order.
///
/// A tag carries `<order number>-<garment no.>` (e.g. `SPOT-00001-02`): letters,
/// digits and hyphens only, so it is a valid Code 128 barcode and a short QR.
/// Order numbers are unique across shops, so the code alone identifies one order.
class TagCode {
  const TagCode._();

  /// The text printed into the barcode / QR for garment [index] of an order.
  static String encode(String orderNumber, int index) =>
      '$orderNumber-${index.toString().padLeft(2, '0')}';

  /// Order numbers a scanned or typed [raw] value could mean, best guess first.
  ///
  /// Accepts a bare order number (`SPOT-00001`), a tag code (`SPOT-00001-02`)
  /// and an old-style tracking URL (`https://…/track/SPOT-00001`). Callers match
  /// each candidate exactly against known orders, so a wrong guess finds nothing
  /// rather than the wrong order.
  static List<String> candidates(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return const [];

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      value = uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => value);
    }
    value = value.trim();

    final out = <String>[value];
    // Drop one trailing "-NN" garment suffix, but keep at least "PREFIX-NNNNN".
    final m = RegExp(r'^(.+-\d+)-(\d{1,3})$').firstMatch(value);
    if (m != null) out.add(m.group(1)!);
    return out;
  }
}
