/// Picks the right `bool consumeFreshLoginRequest()` at compile time — the web
/// implementation reads the page URL through `package:web`, which only exists
/// when compiling for web. Same conditional-import shape as `csv_download.dart`.
///
/// The marketing site's "Log in" links open `https://customer.washnlaundry.com/?fresh=1`.
/// That flag means "show the login screen": the app ends any stored session
/// (Demo Mode, a password token, Google's silent re-sign-in) instead of
/// restoring it. See `AuthProvider._init`.
library;

export 'fresh_login_stub.dart'
    if (dart.library.js_interop) 'fresh_login_web.dart';
