import 'dart:convert';

import 'package:flutter/services.dart';

/// Which sidebar views each role must not see, read from
/// `assets/config/role_views.json` (`{ "<role>": { "hiddenViews": [labels] } }`).
/// Labels match the sidebar's, case-insensitively. This only shapes the UI and
/// the router; the API's own permission classes are the real access control.
class RoleViews {
  RoleViews._();

  static const _asset = 'assets/config/role_views.json';

  /// The sidebar label of each hideable view and the route it opens.
  static const _paths = {
    'dashboard': '/dashboard',
    'new order': '/new-order',
    'orders': '/orders',
    'customers': '/customers',
    'services': '/services',
    'staff': '/staff',
    'attendance': '/attendance',
    'payroll': '/payroll',
    'expenses': '/expenses',
    'credits': '/credits',
    'reports': '/reports',
    'scan': '/scan',
    'settings': '/settings',
  };

  /// `--dart-define=FORCE_CUSTOMER_HOST=true` makes a local run behave like
  /// customer.washnlaundry.com, so that host's rule can be tried on localhost.
  static const _forceCustomerHost = bool.fromEnvironment('FORCE_CUSTOMER_HOST');

  /// True on customer.washnlaundry.com (any `customer.*` host).
  static bool isCustomerHost([String? host]) =>
      _forceCustomerHost ||
      (host ?? Uri.base.host).toLowerCase().startsWith('customer.');

  /// The role the UI should use: anyone who signs in on the customer host
  /// (owner or staff included) gets the customer view. A host can only narrow
  /// access, never widen it, and `unlinked` stays unlinked so a new account
  /// still reaches the sign-up step.
  static String? effectiveRole(String? role, {String? host}) =>
      (role == 'owner' || role == 'staff') && isCustomerHost(host)
          ? 'customer'
          : role;

  static Map<String, Set<String>> _hidden = {};

  static Future<void> load() async {
    try {
      final data = jsonDecode(await rootBundle.loadString(_asset)) as Map;
      setHidden({
        for (final e in data.entries)
          e.key as String: [
            for (final v in ((e.value as Map)['hiddenViews'] as List? ?? const []))
              '$v'
          ],
      });
    } catch (_) {
      _hidden = {};
    }
  }

  /// Replaces the config (also how tests set it).
  static void setHidden(Map<String, List<String>> byRole) {
    _hidden = {
      for (final e in byRole.entries)
        e.key: {for (final l in e.value) l.trim().toLowerCase()},
    };
  }

  static bool isLabelHidden(String? role, String label) =>
      _hidden[role]?.contains(label.trim().toLowerCase()) ?? false;

  static bool isPathHidden(String? role, String loc) {
    final hidden = _hidden[role];
    if (hidden == null || hidden.isEmpty) return false;
    return hidden.any((label) {
      final p = _paths[label];
      return p != null && (loc == p || loc.startsWith('$p/'));
    });
  }
}
