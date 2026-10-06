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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final authProvider = AuthProvider();
  final router = buildRouter(authProvider);
  runApp(
    rp.ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A4FD6),
          primary: const Color(0xFF1A4FD6),
          surface: const Color(0xFFF8FAFC),
        ),
        textTheme: GoogleFonts.ibmPlexSansTextTheme(
          Theme.of(context).textTheme,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
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
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
