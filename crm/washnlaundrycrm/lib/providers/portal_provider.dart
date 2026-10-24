import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'auth_provider.dart';

/// State of the customer portal (customer.washnlaundry.com, KAN-214): which shop
/// the customer is booking with. That shop is sent as `X-Tenant-ID` on the
/// customer host (see `main.dart`), so `/api/me/` reports the role *for it*.
///
/// It is kept apart from `AppProvider.activeTenantId` on purpose: the CRM drops
/// its tenant whenever nobody is signed in, but a `/s/<slug>` link has to
/// remember its shop through the sign-in that follows it.
class PortalProvider extends ChangeNotifier {
  PortalProvider(this._auth) {
    _restore();
  }

  final AuthProvider _auth;
  static const _prefsKey = 'portal_shop';

  bool _restoring = true;
  bool get restoring => _restoring;

  String? _slug;
  String? get shopSlug => _slug;

  Map<String, dynamic>? _shop;
  Map<String, dynamic>? get shop => _shop;
  String get shopName => _shop?['name'] as String? ?? 'washnlaundry';

  /// Where to look for laundries, chosen on `/location` and remembered on this
  /// device (it outlives sign-out, like a delivery app's saved location):
  /// either the browser's position ([near]) or a typed PIN code / area ([query]).
  (double, double)? _near;
  (double, double)? get near => _near;
  String? _query;
  String? get locationQuery => _query;
  bool get hasLocation => _near != null || (_query ?? '').isNotEmpty;

  /// "Your current location" or the typed PIN code / area.
  String get locationLabel => _near != null ? 'Your current location' : (_query ?? '');

  static const _latKey = 'portal_loc_lat', _lngKey = 'portal_loc_lng', _queryKey = 'portal_loc_q';

  /// Whether the last auth notification found someone signed in, to spot a sign-out.
  bool _wasSignedIn = false;

  /// Like a delivery app, the shop is chosen *after* sign-in, from a list: a saved
  /// shop is only kept for a session that is still signed in, and signing out
  /// forgets it. The exception is a shop's own `/s/<slug>` link, chosen while
  /// signed out, which carries through the sign-in that follows it.
  Future<void> _restore() async {
    if (_auth.initializing) {
      final ready = Completer<void>();
      void once() {
        if (_auth.initializing) return;
        _auth.removeListener(once);
        ready.complete();
      }

      _auth.addListener(once);
      await ready.future;
    }
    // A Demo Mode session left over from the CRM in this browser is a throwaway
    // sandbox owner: never carry it into the portal.
    if (_auth.isDemo) await _auth.signOut();
    _wasSignedIn = _auth.isSignedIn;
    _auth.addListener(_onAuthChanged);
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latKey), lng = prefs.getDouble(_lngKey);
      _near = lat != null && lng != null ? (lat, lng) : null;
      _query = prefs.getString(_queryKey);
      final saved = prefs.getString(_prefsKey);
      if (saved != null && _auth.isSignedIn) {
        await selectShop(saved, refreshRole: false);
      } else if (saved != null) {
        await prefs.remove(_prefsKey);
      }
    } catch (_) {
      // Prefs unavailable: start with no shop.
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  void _onAuthChanged() {
    final signedIn = _auth.isSignedIn;
    if (_wasSignedIn && !signedIn && _slug != null) _forget();
    _wasSignedIn = signedIn;
  }

  Future<void> _forget() async {
    _slug = null;
    _shop = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Makes [slug] the shop being booked with. Returns an error message, or null.
  /// A shop that stopped taking online bookings is forgotten.
  Future<String?> selectShop(String slug, {bool refreshRole = true}) async {
    try {
      final shop = await ApiService.fetchPortalShop(slug);
      _shop = shop;
      _slug = shop['slug'] as String? ?? slug;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _slug!);
      notifyListeners();
      if (refreshRole && _auth.isSignedIn) await _auth.refreshRole();
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 404 && slug == _slug) await clearShop();
      return e.message;
    }
  }

  Future<void> clearShop() async {
    _slug = null;
    _shop = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
    if (_auth.isSignedIn) await _auth.refreshRole();
  }

  /// Remembers where to look for laundries: [near] (the browser's position) or
  /// [query] (a PIN code or area). One replaces the other.
  Future<void> setLocation({(double, double)? near, String? query}) async {
    _near = near;
    _query = near == null ? query?.trim() : null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_near != null) {
        await prefs.setDouble(_latKey, _near!.$1);
        await prefs.setDouble(_lngKey, _near!.$2);
        await prefs.remove(_queryKey);
      } else {
        await prefs.remove(_latKey);
        await prefs.remove(_lngKey);
        await prefs.setString(_queryKey, _query ?? '');
      }
    } catch (_) {
      // Prefs unavailable: remembered for this visit only.
    }
  }

  @visibleForTesting
  void setLocationForTest({(double, double)? near, String? query}) {
    _near = near;
    _query = query;
  }

  @visibleForTesting
  void setShopForTest(Map<String, dynamic>? shop) {
    _restoring = false;
    _shop = shop;
    _slug = shop?['slug'] as String?;
    notifyListeners();
  }
}
