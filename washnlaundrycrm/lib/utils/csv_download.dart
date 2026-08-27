/// Picks the right `bool downloadCsv(String filename, String csvContent)` at
/// compile time — the web implementation depends on `dart:js_interop`
/// (`package:web`), which only exists when compiling for web and fails even
/// to *compile* on the plain-VM target `flutter test` uses. Same
/// conditional-import shape as `google_signin_button.dart` (see its doc
/// comment) — this app doesn't ship off web yet (see CLAUDE.md's "Android"
/// section), so the stub only exists to keep tests and any future non-web
/// build compiling, not to offer a real fallback.
library;

export 'csv_download_stub.dart'
    if (dart.library.js_interop) 'csv_download_web.dart';
