import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/utils/google_signin_button_stub.dart';

/// The non-web fallback button — selected by `google_signin_button.dart`'s
/// conditional export on every platform `flutter test` runs against (the web
/// implementation can't even compile off web, per CLAUDE.md) — was never
/// pumped on its own: `LoginScreen` only renders it behind
/// `AuthProvider.isConfigured`, which is always false in this suite (no
/// `--dart-define=GOOGLE_CLIENT_ID`), so the real button never mounted in
/// any existing test.
void main() {
  testWidgets('renders the Google label and wires the tap through', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: googleSignInButton(onPressed: () => tapped = true),
      ),
    ));

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byIcon(Icons.login), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton));
    expect(tapped, isTrue);
  });
}
