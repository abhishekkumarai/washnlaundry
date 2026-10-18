/// Picks the right `Future<(double, double)?> currentPosition()` at compile time:
/// the web implementation asks the browser (`navigator.geolocation`) through
/// `package:web`, which only exists when compiling for web. Same conditional
/// import shape as `fresh_login.dart`. Null when the user refuses or the
/// browser cannot tell.
library;

export 'geolocation_stub.dart' if (dart.library.js_interop) 'geolocation_web.dart';
