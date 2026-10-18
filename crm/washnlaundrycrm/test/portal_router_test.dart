import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washnlaundrycrm/providers/auth_provider.dart';
import 'package:washnlaundrycrm/providers/portal_provider.dart';
import 'package:washnlaundrycrm/router.dart';
import 'package:washnlaundrycrm/screens/portal/portal_entry_screens.dart';

/// `portalRedirectFor`: the customer host's gate (KAN-221).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(AuthProvider, PortalProvider)> session(
      {required bool signedIn, String? role, Map<String, dynamic>? shop}) async {
    final auth = AuthProvider();
    final portal = PortalProvider(auth);
    await Future<void>.delayed(Duration.zero);
    auth.setSessionForTest(
        signedIn: signedIn, role: role, me: role == null ? null : {'role': role});
    portal.setShopForTest(shop);
    return (auth, portal);
  }

  const sunny = {'slug': 'sunny', 'name': 'Sunny Laundry'};

  test('signed out: only the public pages open', () async {
    final (auth, portal) = await session(signedIn: false, shop: sunny);
    for (final p in ['/find', '/s/sunny', '/verify', '/reset', '/login']) {
      expect(portalRedirectFor(auth, portal, p), isNull, reason: p);
    }
    for (final p in ['/book', '/orders', '/orders/WL-1', '/profile', '/join', '/dashboard']) {
      expect(portalRedirectFor(auth, portal, p), '/login', reason: p);
    }
  });

  test('signed in with no shop chosen goes to Find your laundry', () async {
    final (auth, portal) = await session(signedIn: true, role: 'unlinked');
    expect(portalRedirectFor(auth, portal, '/book'), '/find');
    expect(portalRedirectFor(auth, portal, '/login'), '/find');
  });

  test('not yet a customer of the shop: kept on /join, never /setup-shop', () async {
    for (final role in ['unlinked', 'owner', 'staff']) {
      final (auth, portal) = await session(signedIn: true, role: role, shop: sunny);
      expect(portalRedirectFor(auth, portal, '/join'), isNull, reason: role);
      for (final p in ['/book', '/orders', '/profile', '/setup-shop']) {
        expect(portalRedirectFor(auth, portal, p), '/join', reason: '$role $p');
      }
    }
  });

  test('a customer of the shop books, sees orders and profile', () async {
    final (auth, portal) = await session(signedIn: true, role: 'customer', shop: sunny);
    for (final p in ['/book', '/orders', '/orders/WL-1', '/profile', '/s/sunny', '/find']) {
      expect(portalRedirectFor(auth, portal, p), isNull, reason: p);
    }
    expect(portalRedirectFor(auth, portal, '/join'), '/book');
    expect(portalRedirectFor(auth, portal, '/login'), '/book');
  });

  test('the portal router has no CRM routes', () async {
    final paths = [for (final r in portalRoutes()) (r as dynamic).path as String];
    for (final crm in ['/dashboard', '/customers', '/staff', '/settings', '/setup-shop', '/new-order']) {
      expect(paths, isNot(contains(crm)), reason: crm);
    }
  });

  testWidgets('join screen tells owners to use the shop app', (tester) async {
    final (auth, portal) =
        (await tester.runAsync(() => session(signedIn: true, role: 'owner', shop: sunny)))!;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: portal),
      ],
      child: const MaterialApp(home: JoinShopScreen()),
    ));
    expect(find.text('You work at Sunny Laundry'), findsOneWidget);
    expect(find.text('Open app.washnlaundry.com'), findsOneWidget);
  });

  testWidgets('join screen asks a new account for name and mobile', (tester) async {
    final (auth, portal) =
        (await tester.runAsync(() => session(signedIn: true, role: 'unlinked', shop: sunny)))!;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: portal),
      ],
      child: const MaterialApp(home: JoinShopScreen()),
    ));
    expect(find.text('Join Sunny Laundry'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mobile number'), findsOneWidget);
  });
}
