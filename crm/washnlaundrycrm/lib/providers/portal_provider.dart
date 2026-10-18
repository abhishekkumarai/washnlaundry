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

  Future<void> _restore() async {
    // A Demo Mode session left over from the CRM in this browser is a throwaway
    // sandbox owner: never carry it into the portal.
    void dropDemo() {
      if (_auth.isDemo) _auth.signOut();
    }

    if (_auth.initializing) {
      void once() {
        if (_auth.initializing) return;
        _auth.removeListener(once);
        dropDemo();
      }

      _auth.addListener(once);
    } else {
      dropDemo();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) await selectShop(saved, refreshRole: false);
    } catch (_) {
      // Prefs unavailable: start with no shop.
    } finally {
      _restoring = false;
      notifyListeners();
    }
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

  @visibleForTesting
  void setShopForTest(Map<String, dynamic>? shop) {
    _restoring = false;
    _shop = shop;
    _slug = shop?['slug'] as String?;
    notifyListeners();
  }
}
