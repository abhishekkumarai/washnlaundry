import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/order_model.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/attendance_screen.dart';
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
        builder: (_, s) =>
            VerifyEmailScreen(token: s.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/reset',
        builder: (_, s) =>
            ResetPasswordScreen(token: s.uri.queryParameters['token']),
      ),
      // Sign-up for a Google account with no staff or customer record yet.
      GoRoute(path: '/my/start', builder: (_, __) => const CustomerStartScreen()),
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
        builder: (c, s) =>
            _buildOrderDetail(c, s.pathParameters['id']!, backTo: '/orders'),
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
        builder: (c, s) => _section(
            c,
            13,
            SettingsScreen(
                initialTab: s.uri.queryParameters['tab'])),
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
        builder: (c, s) => _section(c, 16, const ChatScreen()),
      ),
      GoRoute(
        path: '/social',
        builder: (c, s) => _section(c, 17, const SocialSuiteScreen()),
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

bool _staffMayOpen(String loc) =>
    staffRoutes.any((r) => loc == r || loc.startsWith('$r/'));

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

/// The real router, wrapping [appRoutes] with the auth gate.
///
/// `redirect`/`refreshListenable` gate on [AuthProvider.isSignedIn] and
/// [AuthProvider.role]. Google Sign-In and `AuthProvider.signInAsDemo()` are
/// both valid ways to sign in (Demo Mode is always `staff`); the gate applies
/// the same whether or not `GOOGLE_CLIENT_ID` is configured, so Demo Mode
/// works, and Sign Out, in every local run.
GoRouter buildRouter(AuthProvider auth) => GoRouter(
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
