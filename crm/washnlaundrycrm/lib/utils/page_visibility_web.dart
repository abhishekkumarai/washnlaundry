import 'package:web/web.dart' as web;

/// True while the browser tab is in the background. Selected by
/// `page_visibility.dart` only when compiling for web.
bool pageHidden() => web.document.hidden;
