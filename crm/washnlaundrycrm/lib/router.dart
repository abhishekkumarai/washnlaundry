import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/order_model.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/portal_provider.dart';
import 'screens/attendance_screen.dart';
import 'screens/portal/portal_addresses_screen.dart';
import 'screens/portal/portal_book_screen.dart';
import 'screens/portal/portal_entry_screens.dart';
import 'screens/portal/portal_help_screens.dart';
import 'screens/portal/portal_location_screen.dart';
import 'screens/portal/portal_orders_screens.dart';
import 'screens/portal/portal_profile_screen.dart';
import 'screens/auth_link_screens.dart';
import 'screens/chat_screen.dart';
import 'screens/credits_screen.dart';
import 'screens/customer_screens.dart';
import 'screens/customers_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_order_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/payroll_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/services_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_setup_screen.dart';
import 'screens/social_suite_screen.dart';
import 'screens/staff_screen.dart';
import 'utils/role_views.dart';
import 'widgets/app_shell.dart';
import 'widgets/load_state.dart';

/// Updates `AppProvider.currentNavIndex` to match the matched route.
///
/// Deferred to a post-frame callback rather than called straight from
/// `builder:`: a `GoRoute.builder` runs *during* the widget build phase, and
/// `setNavIndex` calls `notifyListeners()` synchronously — calling that
/// mid-build throws ("setState() or markNeedsBuild() called during build").
/// `addPostFrameCallback` runs it right after the frame that's building now
/// finishes, which is what every other "notify a ChangeNotifier from a
/// widget's build" situation in Flutter does.
void _deferSetNavIndex(BuildContext context, int navIndex) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) context.read<AppProvider>().setNavIndex(navIndex);
  });
}

/// [_deferSetNavIndex] plus returning [screen] — every route whose builder
/// is a plain, always-the-same-screen section uses this shorthand.
/// `/orders/:id` needs [_deferSetNavIndex] on its own since which widget it
/// returns depends on load state, not just the route.
Widget _section(BuildContext context, int navIndex, Widget screen) {
  _deferSetNavIndex(context, navIndex);
  return screen;
}

/// A bare Scaffold with the sidebar and Orders highlighted, for the two
/// non-detail states `/orders/:id` can be in — matches the chrome every
/// other screen has instead of a bare spinner or bare error text.
Widget _ordersFrame(Widget body) => Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(body: body),
    );

Widget _buildOrderDetail(BuildContext c, String id, {required String backTo}) {
  // `watch`, not `read`: `loadDataFromBackend()` is async, so a fresh
  // deep link can arrive before `AppProvider.orders` is populated.
  // Watching means the notifyListeners() it fires on arrival re-runs
  // this builder, turning the spinner into the real order without
  // any extra navigation call.
  final provider = c.watch<AppProvider>();
  _deferSetNavIndex(c, 2);
  OrderModel? match;
  for (final o in provider.orders) {
    if (o.id == id || o.orderNumber == id) {
      match = o;
      break;
    }
  }
  if (match != null) {
    return OrderDetailScreen(
      order: match,
      onBack: () => c.go(backTo),
    );
  }
  if (provider.isLoading) {
    return _ordersFrame(
      const Center(child: CircularProgressIndicator()),
    );
  }
  // Only reachable once loading has genuinely finished without this
  // order showing up — a legitimate direct link to a real order
  // (confirmed live against the real app's own `/orders/:id`) never
  // hits this, since it always resolves once orders finish loading.
  return _ordersFrame(
    ErrorState(
      statusCode: 404,
      title: 'Order not found',
      message: 'The requested order ($id) was not found or may have been deleted.',
      onRetry: () => c.read<AppProvider>().refresh(),
      onHome: () => c.go(backTo),
    ),
  );
}

/// A section that is switched on per shop (Social Suite, Chat: backend
/// `Shop.*_enabled`, off by default). Decided here rather than in a route
/// `redirect`, because a fresh page load reaches this before the shop has
/// loaded: `watch` re-runs it once the shop arrives, like [_buildOrderDetail].
Widget _buildShopFeature(
    BuildContext c, bool Function(AppProvider) enabled, int navIndex, Widget screen) {
  final provider = c.watch<AppProvider>();
  if (enabled(provider)) {
    return _section(c, navIndex, screen);
  }
  if (provider.shop == null && provider.isLoading) {
    return _ordersFrame(const Center(child: CircularProgressIndicator()));
  }
  // The shop has loaded and does not have it.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (c.mounted) c.go('/dashboard');
  });
  return _ordersFrame(const SizedBox.shrink());
}

/// The section routes, keyed the same way [AppProvider.routePaths] already
/// is. go_router owns the URL; `_section` keeps `currentNavIndex` in sync so
/// every existing read of "which section is active" (chiefly the sidebar's
/// highlighting) still works unchanged.
List<RouteBase> appRoutes() => [
      GoRoute(path: '/', redirect: (_, __) => '/dashboard'),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      // Links from the confirmation / password-reset emails (public).
      GoRoute(
        path: '/verify',
        builder: (_, s) => VerifyEmailScreen(token: s.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/reset',
        builder: (_, s) => ResetPasswordScreen(token: s.uri.queryParameters['token']),
      ),
      // Sign-up for a Google account with no staff or customer record yet.
      GoRoute(path: '/my/start', builder: (_, __) => const CustomerStartScreen()),
      // First sign-in with no shop yet: name your shop (self-service).
      GoRoute(path: shopSetupPath, builder: (_, __) => const ShopSetupScreen()),
      GoRoute(
        path: '/profile',
        builder: (c, _) => _section(c, 99, const ProfileScreen()),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (c, s) => _section(c, 0, const DashboardScreen()),
      ),
      GoRoute(
        path: '/new-order',
        builder: (c, s) => _section(c, 1, const NewOrderScreen()),
      ),
      GoRoute(
        path: '/orders',
        builder: (c, s) => _section(c, 2, const OrdersScreen()),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (c, s) => _buildOrderDetail(c, s.pathParameters['id']!, backTo: '/orders'),
      ),
      GoRoute(
        path: '/customers',
        builder: (c, s) => _section(c, 3, const CustomersScreen()),
      ),
      GoRoute(
        path: '/services',
        builder: (c, s) => _section(c, 4, const ServicesScreen()),
      ),
      GoRoute(
        path: '/staff',
        builder: (c, s) => _section(c, 5, const StaffScreen()),
      ),
      GoRoute(
        path: '/attendance',
        builder: (c, s) => _section(c, 6, const AttendanceScreen()),
      ),
      GoRoute(
        path: '/payroll',
        builder: (c, s) => _section(c, 7, const PayrollScreen()),
      ),
      GoRoute(
        path: '/expenses',
        builder: (c, s) => _section(c, 8, const ExpensesScreen()),
      ),
      GoRoute(
        path: '/settings',
        builder: (c, s) =>
            _section(c, 13, SettingsScreen(initialTab: s.uri.queryParameters['tab'])),
      ),
      GoRoute(
        path: '/credits',
        builder: (c, s) => _section(c, 15, const CreditsScreen()),
      ),
      GoRoute(
        path: '/reports',
        builder: (c, s) => _section(c, 9, const ReportsScreen()),
      ),
      GoRoute(
        path: '/chat',
        // Only for a shop with Chat switched on (off by default).
        builder: (c, s) => _buildShopFeature(c, (p) => p.chatEnabled, 16, const ChatScreen()),
      ),
      GoRoute(
        path: '/social',
        // Only for a shop with Social Suite switched on (off by default).
        builder: (c, s) =>
            _buildShopFeature(c, (p) => p.socialSuiteEnabled, 17, const SocialSuiteScreen()),
      ),
      GoRoute(
        path: '/scan',
        // `?order=<id>` preselects that order straight into the Generate
        // Tags tab — how New Order's "Print Tags" reaches this screen.
        builder: (c, s) => _section(
          c,
          11,
          ScanScreen(initialOrderId: s.uri.queryParameters['order']),
        ),
      ),
    ];

/// The "set up your shop" landing page for an account with no shop yet.
const shopSetupPath = '/setup-shop';

/// Where each role lands after sign-in.
String homeFor(String? role) => switch (role) {
      'customer' => '/orders',
      'unlinked' => '/my/start',
      'staff' => '/orders',
      _ => '/dashboard',
    };

/// The routes a `staff` (non-owner) user may open; everything else is
/// owner-only. Mirrors the API's IsOwner permissions in api/auth.py.
const staffRoutes = ['/new-order', '/orders', '/customers', '/scan', '/profile'];

bool _staffMayOpen(String loc) => staffRoutes.any((r) => loc == r || loc.startsWith('$r/'));

/// The auth + role gate. Signed-out visits go to `/login`; once the backend
/// has said who the user is (`AuthProvider.role`), owners get the CRM, staff
/// get its day-to-day screens ([staffRoutes]) and customers are kept on `/my/*` (an unlinked Google account on `/my/start`).
/// While the role is still loading nothing redirects: `main.dart` overlays a
/// spinner (or a retry screen if `/api/me/` failed) in the meantime.
String? authRedirect(AuthProvider auth, GoRouterState state) =>
    authRedirectFor(auth, state.matchedLocation);

/// [authRedirect] on a plain location, so it can be tested without a router.
@visibleForTesting
String? authRedirectFor(AuthProvider auth, String loc) {
  if (auth.initializing) return null;
  // The email links work whether or not anyone is signed in.
  if (loc == '/verify' || loc == '/reset') return null;
  final loggingIn = loc == '/login';
  if (!auth.isSignedIn) return loggingIn ? null : '/login';
  final role = auth.role;
  if (role == null) return null;
  // An account with no shop of its own yet sets one up first (backend
  // SELF_SERVICE_SHOPS); once it has one the page is not reachable.
  if (auth.needsShopOnboarding) return loc == shopSetupPath ? null : shopSetupPath;
  if (loc == shopSetupPath) return homeFor(role);
  final home = homeFor(role);
  if (loggingIn || loc == '/') return home;
  final inMy = loc.startsWith('/my/');
  // Customers get the owner's CRM screens minus the views listed for them in
  // assets/config/role_views.json (see RoleViews).
  if (role == 'customer' && RoleViews.isPathHidden(role, loc)) return home;
  if (role == 'owner' || role == 'customer') return inMy ? home : null;
  if (role == 'staff') return inMy || !_staffMayOpen(loc) ? home : null;
  // unlinked: only the sign-up step.
  if (loc != '/my/start') return home;
  return null;
}

// ── Customer portal (customer.washnlaundry.com, KAN-221) ─────────────────────
// That host gets its own routes and gate, decided by host and not only by role,
// so no CRM screen is reachable there whoever signs in.

List<RouteBase> portalRoutes() => [
      GoRoute(path: '/', redirect: (_, __) => '/book'),
      GoRoute(path: '/login', builder: (_, __) => const PortalLoginScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, s) => VerifyEmailScreen(token: s.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/reset',
        builder: (_, s) => ResetPasswordScreen(token: s.uri.queryParameters['token']),
      ),
      GoRoute(path: '/location', builder: (_, __) => const PortalLocationScreen()),
      GoRoute(path: '/find', builder: (_, __) => const FindShopScreen()),
      GoRoute(
        path: '/s/:slug',
        builder: (_, s) => ShopLinkScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(path: '/join', builder: (_, __) => const JoinShopScreen()),
      // The old account overview folded into Profile.
      GoRoute(path: '/account', redirect: (_, __) => '/profile'),
      GoRoute(path: '/book', builder: (_, __) => const PortalBookScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const PortalOrdersScreen()),
      GoRoute(
        path: '/orders/:no',
        builder: (_, s) => PortalOrderDetailScreen(
          orderNumber: s.pathParameters['no']!,
          justBooked: s.uri.queryParameters['placed'] == '1' || s.uri.queryParameters['new'] == '1',
        ),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const PortalProfileScreen()),
      GoRoute(path: '/addresses', builder: (_, __) => const PortalAddressesScreen()),
      GoRoute(path: '/help', builder: (_, __) => const PortalHelpScreen()),
      GoRoute(
        path: '/help/report',
        builder: (_, s) => PortalReportIssueScreen(orderNumber: s.uri.queryParameters['order']),
      ),
    ];

/// The portal's gate, in the order of the flow (crm/docs/customer-portal-flow.md):
/// sign in → your location → nearby laundries → laundry page / join → booking.
/// Signed out, only sign-in, the email links and a shop's own `/s/<slug>` link
/// (which remembers the shop and goes on to sign-in) open. Signed in with no
/// laundry chosen: `/location` until a location is remembered, then `/find`.
/// Everything else needs that laundry and to be its customer (else `/join`);
/// once all that is done, home is `/book`. The setup-shop page never shows here.
@visibleForTesting
String? portalRedirectFor(AuthProvider auth, PortalProvider portal, String loc) {
  if (auth.initializing || portal.restoring) return null;
  if (loc == '/verify' || loc == '/reset' || loc.startsWith('/s/')) return null;
  if (!auth.isSignedIn) return loc == '/login' ? null : '/login';
  if (auth.role == null) return null; // /api/me/ still loading (main.dart shows a spinner)
  if (loc == '/location') return null;
  if (loc == '/find') return portal.hasLocation ? null : '/location';
  if (portal.shopSlug == null) return portal.hasLocation ? '/find' : '/location';
  if (auth.serverRole != 'customer') return loc == '/join' ? null : '/join';
  if (loc == '/join' || loc == '/login') return '/book';
  return null;
}

/// The real router, wrapping [appRoutes] with the auth gate.
///
/// `redirect`/`refreshListenable` gate on [AuthProvider.isSignedIn] and
/// [AuthProvider.role]. Google Sign-In and `AuthProvider.signInAsDemo()` are
/// both valid ways to sign in (Demo Mode is always `staff`); the gate applies
/// the same whether or not `GOOGLE_CLIENT_ID` is configured, so Demo Mode
/// works, and Sign Out, in every local run.
///
/// With a [portal] (the customer host, see `main.dart`) it serves
/// [portalRoutes] behind [portalRedirectFor] instead.
GoRouter buildRouter(AuthProvider auth, {PortalProvider? portal}) => portal != null
    ? GoRouter(
        initialLocation: '/book',
        refreshListenable: Listenable.merge([auth, portal]),
        redirect: (context, state) => portalRedirectFor(auth, portal, state.matchedLocation),
        errorBuilder: (context, state) => Scaffold(
          backgroundColor: const Color(0xFFF8F7F5),
          body: Center(
            child: ErrorState(
              statusCode: 404,
              title: 'Page Not Found',
              message: 'The page "${state.uri.path}" could not be found.',
              onRetry: () => context.go('/book'),
              onHome: () => context.go('/book'),
            ),
          ),
        ),
        routes: portalRoutes(),
      )
    : GoRouter(
        initialLocation: '/dashboard',
        refreshListenable: auth,
        redirect: (context, state) => authRedirect(auth, state),
        errorBuilder: (context, state) => Scaffold(
          backgroundColor: const Color(0xFFF8F7F5),
          body: Center(
            child: ErrorState(
              statusCode: 404,
              title: 'Page Not Found',
              message: 'The page "${state.uri.path}" could not be found.',
              onRetry: () => context.go(homeFor(auth.role)),
              onHome: () => context.go(homeFor(auth.role)),
            ),
          ),
        ),
        routes: appRoutes(),
      );
