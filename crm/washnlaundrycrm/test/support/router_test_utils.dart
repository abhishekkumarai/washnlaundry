import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';

/// A minimal real router for widget tests that tap a nav control wired to
/// `context.goSection`/`context.go` — those throw with no `GoRouter`
/// ancestor. Every route keeps rendering [child] rather than swapping to a
/// full screen (as `lib/router.dart`'s real routes do): these tests pump a
/// widget like `SidebarNavigation()` in isolation and assert on
/// `provider.currentNavIndex` afterward, not on what's on screen, so
/// swapping in e.g. `DashboardScreen()` would just duplicate text ("Dashboard"
/// appears both as the nav label and as a screen title) without testing
/// anything this file cares about.
///
/// Route paths mirror [AppProvider.routePaths] — the same map the real
/// router is built from — so each one's `setNavIndex` side effect matches
/// production exactly; only the "replace the whole screen" part is skipped.
///
/// `setNavIndex` is deferred to a post-frame callback for the same reason
/// `lib/router.dart` defers it: a `GoRoute.builder` runs during the widget
/// build phase, and calling straight into a `notifyListeners()` mid-build
/// throws ("setState() or markNeedsBuild() called during build").
Widget hostWithRouter(AppProvider provider, Widget child,
    {String initialLocation = '/dashboard'}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: AppProvider.routePaths.entries
        .map((entry) => GoRoute(
              path: entry.value,
              builder: (context, state) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.read<AppProvider>().setNavIndex(entry.key);
                  }
                });
                return Scaffold(body: child);
              },
            ))
        .toList(),
  );
  return ChangeNotifierProvider<AppProvider>.value(
    value: provider,
    child: MaterialApp.router(routerConfig: router),
  );
}
