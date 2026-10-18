import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The browser's current position as (latitude, longitude), or null if the user
/// refuses, the page is not on HTTPS/localhost, or no fix arrives in 15 s.
/// Selected by `geolocation.dart` only when compiling for web.
Future<(double, double)?> currentPosition() {
  final done = Completer<(double, double)?>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition p) {
        if (!done.isCompleted) {
          done.complete((p.coords.latitude.toDouble(), p.coords.longitude.toDouble()));
        }
      }).toJS,
      ((web.GeolocationPositionError _) {
        if (!done.isCompleted) done.complete(null);
      }).toJS,
      web.PositionOptions(enableHighAccuracy: true, timeout: 15000),
    );
  } catch (_) {
    if (!done.isCompleted) done.complete(null);
  }
  return done.future.timeout(const Duration(seconds: 20), onTimeout: () => null);
}
