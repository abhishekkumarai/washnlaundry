import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washnlaundrycrm/providers/auth_provider.dart';
import 'package:washnlaundrycrm/screens/login_screen.dart';

Widget host(AuthProvider auth, Widget child) => ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(home: child),
    );

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(1200, 1400);
    view.devicePixelRatio = 1.0;
    // AuthProvider always reads SharedPreferences now (to restore a
    // persisted Demo Mode session even when Google isn't configured) — an
    // in-memory fake so that read doesn't hit a real platform channel.
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('AuthProvider', () {
    test('an unconfigured build never calls into GoogleSignIn', () async {
      // No --dart-define=GOOGLE_CLIENT_ID in the test runner, which is the
      // state every CI run and every `flutter test` invocation is in — this
      // pins that router.dart's gate is safe to rely on without a live
      // Google backend.
      final auth = AuthProvider();
      await Future<void>.delayed(Duration.zero);

      expect(AuthProvider.isConfigured, isFalse);
      expect(auth.initializing, isFalse);
      expect(auth.isSignedIn, isFalse);
    });
  });

  group('LoginScreen', () {
    testWidgets('shows the brand and a sign-in affordance', (tester) async {
      await tester.pumpWidget(host(AuthProvider(), const LoginScreen()));
      await tester.pumpAndSettle();

      // The wordmark is one RichText spanning both halves.
      expect(find.text('WashNLaundry', findRichText: true), findsOneWidget);
      expect(find.text('Sign in to manage your shop'), findsOneWidget);
      // No --dart-define=GOOGLE_CLIENT_ID in the test runner, so
      // AuthProvider.isConfigured is false — the Google button is omitted
      // rather than shown stuck (the web GIS button never finishes
      // "Getting ready" without a real client ID), leaving Demo Mode's
      // Email/Password form as the only sign-in affordance.
      expect(find.text('Sign in with Google'), findsNothing);
      expect(find.text('Email'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('matches the real page minus Apple, wired to Demo Mode', (tester) async {
      await tester.pumpWidget(host(AuthProvider(), const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets); // tab label + primary button
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Try Demo Mode'), findsOneWidget);
    });
  });
}
