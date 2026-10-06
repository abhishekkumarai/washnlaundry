/// Minimal RFC 4180 CSV builder. Pure Dart — no platform dependency — so it
/// compiles and is testable anywhere, unlike the download trigger itself
/// (see `csv_download.dart`).
String buildCsv(List<List<Object?>> rows) {
  String escape(Object? value) {
    final s = value?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  return rows.map((row) => row.map(escape).join(',')).join('\r\n');
}
