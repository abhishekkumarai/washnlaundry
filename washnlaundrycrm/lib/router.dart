import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/order_model.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/attendance_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_order_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/payroll_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/services_screen.dart';
import 'screens/staff_screen.dart';
import 'screens/tag_generation_screen.dart';
import 'widgets/app_shell.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(body: body),
    );

/// The section routes, keyed the same way [AppProvider.routePaths] already
/// is. go_router owns the URL; `_section` keeps `currentNavIndex` in sync so
/// every existing read of "which section is active" (chiefly the sidebar's
/// highlighting) still works unchanged.
List<RouteBase> appRoutes() => [
      GoRoute(path: '/', redirect: (_, __) => '/dashboard'),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
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
        builder: (c, s) {
          // `watch`, not `read`: `loadDataFromBackend()` is async, so a fresh
          // deep link can arrive before `AppProvider.orders` is populated.
          // Watching means the notifyListeners() it fires on arrival re-runs
          // this builder, turning the spinner into the real order without
          // any extra navigation call.
          final provider = c.watch<AppProvider>();
          _deferSetNavIndex(c, 2);
          final id = s.pathParameters['id']!;
          OrderModel? match;
          for (final o in provider.orders) {
            if (o.id == id) {
              match = o;
              break;
            }
          }
          if (match != null) {
            return OrderDetailScreen(
              order: match,
              onBack: () => c.go('/orders'),
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
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Order not found',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => c.go('/orders'),
                    child: const Text('Back to Orders'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/orders/:id/tags',
        builder: (c, s) {
          // Same watch-and-resolve shape as `/orders/:id` above — a deep
          // link (or a fresh "Order Placed" navigation) can land before
          // `AppProvider.orders` has the just-created order in it yet.
          final provider = c.watch<AppProvider>();
          _deferSetNavIndex(c, 2);
          final id = s.pathParameters['id']!;
          OrderModel? match;
          for (final o in provider.orders) {
            if (o.id == id) {
              match = o;
              break;
            }
          }
          if (match != null) {
            final resolved = match;
            return TagGenerationScreen(
              order: resolved,
              onBack: () => c.go('/orders/${resolved.id}'),
            );
          }
          if (provider.isLoading) {
            return _ordersFrame(
              const Center(child: CircularProgressIndicator()),
            );
          }
          return _ordersFrame(
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Order not found',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => c.go('/orders'),
                    child: const Text('Back to Orders'),
                  ),
                ],
              ),
            ),
          );
        },
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
        path: '/reports',
        builder: (c, s) => _section(c, 9, const ReportsScreen()),
      ),
      GoRoute(
        path: '/scan',
        builder: (c, s) => _section(c, 11, const ScanScreen()),
      ),
    ];

/// The real router, wrapping [appRoutes] with the auth gate.
///
/// `redirect`/`refreshListenable` gate purely on [AuthProvider.isSignedIn]: a
/// signed-out visit is sent to `/login`; `/login` itself redirects away once
/// signed in. Google Sign-In and `AuthProvider.signInAsDemo()` are both valid
/// ways to satisfy that — the gate applies the same whether or not
/// `GOOGLE_CLIENT_ID` is configured, so Demo Mode works, and Sign Out, in
/// every local run.
GoRouter buildRouter(AuthProvider auth) => GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: auth,
      redirect: (context, state) {
        if (auth.initializing) return null;
        final loggingIn = state.matchedLocation == '/login';
        if (!auth.isSignedIn) return loggingIn ? null : '/login';
        if (loggingIn) return '/dashboard';
        return null;
      },
      routes: appRoutes(),
    );
