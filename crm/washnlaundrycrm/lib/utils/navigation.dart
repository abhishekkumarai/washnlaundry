import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';

/// Bridges the old `setNavIndex(n)` vocabulary every sidebar/nav-card call
/// site already used to real navigation, via [AppProvider.routePaths] — the
/// same map the route table in `router.dart` is built from.
/// The customer portal (KAN-221). Customers book there, not in the CRM; a local
/// run can point it at its own portal with `--dart-define=PORTAL_URL=...`.
const portalUrl =
    String.fromEnvironment('PORTAL_URL', defaultValue: 'https://customer.washnlaundry.com');

/// "Book a pickup" for a customer who signed in on the CRM host.
void openPortalBooking() => launchUrl(Uri.parse('$portalUrl/book'), webOnlyWindowName: '_self');

extension AppNavigation on BuildContext {
  void goSection(int navIndex) {
    final path = AppProvider.routePaths[navIndex];
    if (path != null) go(path);
  }
}
