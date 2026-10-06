/// Picks the right `googleSignInButton({required VoidCallback onPressed})`
/// at compile time — the web implementation depends on `dart:js_interop`
/// types (`google_sign_in_web`) that only exist when compiling for web, and
/// fail even to *compile* on the plain-VM target `flutter test` and every
/// non-web build use. This is the same conditional-import shape CLAUDE.md
/// already calls for around `dart:io`, mirrored for the opposite direction:
/// a web-only library instead of a non-web-only one.
library;

export 'google_signin_button_stub.dart'
    if (dart.library.js_interop) 'google_signin_button_web.dart';
