import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washnlaundrycrm/providers/auth_provider.dart';
import 'package:washnlaundrycrm/screens/auth_link_screens.dart';

Widget host(String? token) {
  final router = GoRouter(
    initialLocation: '/verify',
    routes: [
      GoRoute(path: '/verify', builder: (_, __) => VerifyEmailScreen(token: token)),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login page'))),
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
    ],
  );
  return ChangeNotifierProvider(
    create: (_) => AuthProvider(),
    child: MaterialApp.router(routerConfig: router),
  );
}

http.Client serverAnswering(int status, Map<String, dynamic> body) =>
    MockClient((request) async => http.Response(jsonEncode(body), status));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a link with no token says it is incomplete and offers only sign in', (tester) async {
    await tester.pumpWidget(host(null));
    await tester.pump();
    expect(find.text('This confirmation link is incomplete.'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
    expect(find.text('Resend confirmation email'), findsNothing);
  });

  testWidgets('an expired link offers a fresh email and shows the result', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(host('old-token'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      // The verify call is answered 400 by the mock; wait for the screen to settle.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Resend confirmation email'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
    }, () {
      var call = 0;
      return MockClient((request) async {
        call++;
        if (request.url.path.endsWith('/auth/verify-email/')) {
          return http.Response(jsonEncode({'detail': 'This confirmation link is invalid or has expired.'}), 400);
        }
        return http.Response(jsonEncode({'ok': true, 'call': call}), 200);
      });
    });
  });

  testWidgets('a used link says so and does not offer a resend', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(host('used-token'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('already been used'), findsOneWidget);
      expect(find.text('Resend confirmation email'), findsNothing);
    }, () => serverAnswering(409, {'detail': 'This confirmation link has already been used. Sign in with your email and password.'}));
  });
}
