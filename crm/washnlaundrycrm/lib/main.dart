import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as rp;
import 'package:flutter_calendar_collection/l10n/app_localizations.dart' as fcc;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'router.dart';
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
  // The shop data is for owner/staff only and the API rejects it without a
  // matching token, so load it once the backend has confirmed the role rather
  // than at startup.
  var loadedFor = false;
  authProvider.addListener(() {
    final role = authProvider.role;
    final validRole = role == 'owner' || role == 'staff' || role == 'customer';
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
      theme: ThemeData(
        useMaterial3: true,
        // Same tokens as the marketing site (src/app/globals.css): warm paper
        // background, near-black ink, navy primary, hairline warm borders.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF182C4F),
          primary: const Color(0xFF182C4F),
          onPrimary: const Color(0xFFFAF9F6),
          secondary: const Color(0xFF2563EB),
          surface: const Color(0xFFF8F7F5),
          onSurface: const Color(0xFF141A24),
          outline: const Color(0xFFE4E0D8),
          outlineVariant: const Color(0xFFECE9E2),
        ),
        textTheme: GoogleFonts.ibmPlexSansTextTheme(
          Theme.of(context).textTheme,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7F5),
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
