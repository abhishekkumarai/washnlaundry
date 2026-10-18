/// Picks the right `bool pageHidden()` at compile time: on web it reads
/// `document.hidden` through `package:web`, elsewhere it is always false. Same
/// conditional import shape as `fresh_login.dart`. Used to pause background
/// polling while the browser tab is not visible.
library;

export 'page_visibility_stub.dart' if (dart.library.js_interop) 'page_visibility_web.dart';
