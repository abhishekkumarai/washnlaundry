import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/widgets/staff_credentials_dialog.dart';

void main() {
  Future<void> open(WidgetTester tester, {bool hasLogin = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showDialog<bool>(
              context: ctx,
              builder: (_) => StaffCredentialsDialog(
                staffId: '1',
                staffName: 'Asha',
                initialEmail: 'asha@example.com',
                hasAppLogin: hasLogin,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('enable form validates the password before calling the API',
      (tester) async {
    await open(tester);
    expect(find.text('Enable staff sign-in'), findsOneWidget);
    expect(find.text('Revoke access'), findsNothing);

    await tester.tap(find.text('Enable sign-in'));
    await tester.pump();
    expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
  });

  testWidgets('an existing login offers revoke and password reset',
      (tester) async {
    await open(tester, hasLogin: true);
    expect(find.text('Staff sign-in'), findsOneWidget);
    expect(find.text('Revoke access'), findsOneWidget);
    expect(find.text('Save password'), findsOneWidget);
  });

  test('generated passwords are 12 chars and different each time', () {
    final a = StaffCredentialsDialog.generatePassword();
    final b = StaffCredentialsDialog.generatePassword();
    expect(a.length, 12);
    expect(a, isNot(b));
  });
}
