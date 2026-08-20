import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('AuthProvider', () {
    test('an unconfigured build never calls into GoogleSignIn', () {
      // No --dart-define=GOOGLE_CLIENT_ID in the test runner, which is the
      // state every CI run and every `flutter test` invocation is in — this
      // pins that main.dart's gate (`!isConfigured || isSignedIn`) is safe to
      // rely on without a live Google backend.
      final auth = AuthProvider();

      expect(AuthProvider.isConfigured, isFalse);
      expect(auth.initializing, isFalse);
      expect(auth.isSignedIn, isFalse);
    });
  });

  group('LoginScreen', () {
    testWidgets('shows the brand and a sign-in affordance', (tester) async {
      await tester.pumpWidget(host(AuthProvider(), const LoginScreen()));
      await tester.pump();

      // The wordmark is one RichText spanning both halves.
      expect(find.text('WashNLaundry', findRichText: true), findsOneWidget);
      expect(find.text('Sign in to manage your shop'), findsOneWidget);
      // flutter test never runs as web, so GoogleSignInButtonBox falls back
      // to the plain button rather than GIS's own rendered one.
      expect(find.text('Sign in with Google'), findsOneWidget);
    });
  });
}
