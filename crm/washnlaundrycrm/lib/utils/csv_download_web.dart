import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [csvContent] as [filename] via an
/// off-DOM `<a download>` click — the standard client-side "save this
/// string as a file" trick, since there's no server endpoint generating
/// these exports. Selected by `csv_download.dart`'s conditional export only
/// when `dart:js_interop` is the compilation target, i.e. only on web.
bool downloadCsv(String filename, String csvContent) =>
    downloadString(filename, csvContent, mimeType: 'text/csv;charset=utf-8;');

bool downloadString(String filename, String content, {String mimeType = 'text/plain;charset=utf-8;'}) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}

bool downloadBytes(String filename, List<int> bytes, {String mimeType = 'application/octet-stream'}) {
  final uint8List = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = web.Blob(
    [uint8List.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
