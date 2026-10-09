import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as rp;
import 'package:flutter_calendar_collection/l10n/app_localizations.dart' as fcc;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'router.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'utils/role_views.dart';

/// Flutter web excludes the mouse from [dragDevices], so any list that needs
/// dragging — the nav rail on a short window, the horizontal activity table —
/// is unusable with a mouse. Adding mouse and trackpad fixes that everywhere.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RoleViews.load();
  usePathUrlStrategy();
  final authProvider = AuthProvider();
  final appProvider = AppProvider(autoLoad: false);
  ApiService.tenantIdProvider = () => appProvider.activeTenantId;

  // The shop data is for owner/staff only and the API rejects it without a
  // matching token, so load it once the backend has confirmed the role rather
  // than at startup.
  var loadedFor = false;
  authProvider.addListener(() async {
    final role = authProvider.role;
    final validRole = role == 'owner' || role == 'staff' || role == 'customer';
    if (authProvider.me != null) {
      final me = authProvider.me!;
      final rawShops = me['shops'] as List?;
      if (rawShops != null) {
        appProvider.setAvailableShops(
          rawShops.map((s) => Map<String, dynamic>.from(s as Map)).toList(),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final savedTenant = prefs.getString('active_tenant_id');
      final availableSlugs = appProvider.availableShops
          .map((s) => s['slug'] as String? ?? s['id']?.toString())
          .toSet();

      if (savedTenant != null && (availableSlugs.isEmpty || availableSlugs.contains(savedTenant))) {
        appProvider.setActiveTenant(savedTenant);
      } else {
        final shopData = me['shop'] as Map<String, dynamic>?;
        if (shopData != null && appProvider.activeTenantId == null) {
          appProvider.setActiveTenant(shopData['slug'] as String? ?? shopData['id']?.toString());
        }
      }
    } else if (authProvider.isDemo) {
      if (appProvider.availableShops.isEmpty) {
        try {
          final allShops = await ApiService.fetchShops();
          if (allShops.isNotEmpty) {
            final activeShops = allShops
                .where((s) => s['status'] == null || s['status'] == 'ACTIVE')
                .take(6)
                .toList();
            appProvider.setAvailableShops(activeShops);
          }
        } catch (_) {}
      }
      final prefs = await SharedPreferences.getInstance();
      final savedTenant = prefs.getString('active_tenant_id');
      final availableSlugs = appProvider.availableShops
          .map((s) => s['slug'] as String? ?? s['id']?.toString())
          .toSet();
      if (savedTenant != null && (availableSlugs.isEmpty || availableSlugs.contains(savedTenant))) {
        appProvider.setActiveTenant(savedTenant);
      } else if (appProvider.activeTenantId == null && appProvider.availableShops.isNotEmpty) {
        final firstSlug = appProvider.availableShops.first['slug'] as String? ??
            appProvider.availableShops.first['id']?.toString();
        if (firstSlug != null) appProvider.setActiveTenant(firstSlug);
      }
    }
    // Customers get the owner's CRM data and layout (minus their hidden
    // views, see RoleViews).
    if (validRole) appProvider.role = role == 'customer' ? 'owner' : role!;
    if (validRole && !loadedFor) appProvider.loadDataFromBackend();
    loadedFor = validRole;
  });
  final router = buildRouter(authProvider);
  runApp(
    rp.ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appProvider),
          ChangeNotifierProvider.value(value: authProvider),
        ],
        child: WashNLaundryCrmApp(router: router),
      ),
    ),
  );
}

class WashNLaundryCrmApp extends StatelessWidget {
  const WashNLaundryCrmApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WashNLaundry CRM - Professional Laundry & Dry Cleaning',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        fcc.AppLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('zh', 'CN'),
      ],
      theme: buildAppTheme(
        GoogleFonts.ibmPlexSansTextTheme(Theme.of(context).textTheme),
      ),
      routerConfig: router,
      // Overlays a spinner in place of whatever route matched underneath
      // while AuthProvider is still restoring a session — reproduces the old
      // pre-router "spinner Scaffold instead of home:" behaviour, since
      // go_router's own `redirect` can only choose *not* to redirect during
      // this state, not suppress rendering the matched route itself. This
      // restore is real even when Google isn't configured: a Demo Mode
      // sign-in is persisted and needs the same SharedPreferences read on
      // every reload.
      builder: (context, child) {
        final auth = context.watch<AuthProvider>();
        if (auth.initializing) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F7F5),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Signed in but the backend hasn't said who this is yet.
        if (auth.isSignedIn && auth.role == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F7F5),
            body: Center(
              child: auth.roleLoading || auth.roleError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(auth.roleError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: auth.refreshRole,
                            child: const Text('Try again')),
                        TextButton(
                            onPressed: auth.signOut,
                            child: const Text('Sign out')),
                      ],
                    ),
            ),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
