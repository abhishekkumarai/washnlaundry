import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washnlaundrycrm/providers/auth_provider.dart';
import 'package:washnlaundrycrm/providers/portal_provider.dart';
import 'package:washnlaundrycrm/router.dart';
import 'package:washnlaundrycrm/screens/portal/portal_entry_screens.dart';
import 'package:washnlaundrycrm/screens/portal/portal_help_screens.dart';
import 'package:washnlaundrycrm/screens/portal/portal_ticket.dart';

/// `portalRedirectFor`: the customer host's gate (KAN-221), and the flow in
/// crm/docs/customer-portal-flow.md.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(AuthProvider, PortalProvider)> session(
      {required bool signedIn,
      String? role,
      Map<String, dynamic>? shop,
      String? location = '560034'}) async {
    final auth = AuthProvider();
    final portal = PortalProvider(auth);
    await Future<void>.delayed(Duration.zero);
    auth.setSessionForTest(
        signedIn: signedIn, role: role, me: role == null ? null : {'role': role});
    portal.setLocationForTest(query: location);
    portal.setShopForTest(shop);
    return (auth, portal);
  }

  const sunny = {'slug': 'sunny', 'name': 'Sunny Laundry'};

  test('signed out: only the public pages open', () async {
    final (auth, portal) = await session(signedIn: false, shop: sunny);
    for (final p in ['/s/sunny', '/verify', '/reset', '/login']) {
      expect(portalRedirectFor(auth, portal, p), isNull, reason: p);
    }
    // Location and the laundry list come after sign-in, never before.
    for (final p in [
      '/location',
      '/find',
      '/book',
      '/orders',
      '/orders/WL-1',
      '/help',
      '/help/report',
      '/profile',
      '/account',
      '/addresses',
      '/join',
      '/dashboard'
    ]) {
      expect(portalRedirectFor(auth, portal, p), '/login', reason: p);
    }
  });

  test('first sign-in asks for a location before the laundry list', () async {
    final (auth, portal) = await session(signedIn: true, role: 'unlinked', location: null);
    expect(portalRedirectFor(auth, portal, '/location'), isNull);
    for (final p in ['/book', '/login', '/find', '/help']) {
      expect(portalRedirectFor(auth, portal, p), '/location', reason: p);
    }
  });

  test('signed in with a location but no laundry goes to Nearby laundries', () async {
    final (auth, portal) = await session(signedIn: true, role: 'unlinked');
    expect(portalRedirectFor(auth, portal, '/book'), '/find');
    expect(portalRedirectFor(auth, portal, '/login'), '/find');
    expect(portalRedirectFor(auth, portal, '/find'), isNull);
    expect(portalRedirectFor(auth, portal, '/location'), isNull);
  });

  test('a returning customer with a laundry is not asked for a location', () async {
    final (auth, portal) =
        await session(signedIn: true, role: 'customer', shop: sunny, location: null);
    expect(portalRedirectFor(auth, portal, '/book'), isNull);
    // Only the laundry list needs one (it comes nearest first).
    expect(portalRedirectFor(auth, portal, '/find'), '/location');
  });

  test('not yet a customer of the shop: kept on /join, never /setup-shop', () async {
    for (final role in ['unlinked', 'owner', 'staff']) {
      final (auth, portal) = await session(signedIn: true, role: role, shop: sunny);
      expect(portalRedirectFor(auth, portal, '/join'), isNull, reason: role);
      for (final p in [
        '/book',
        '/orders',
        '/help',
        '/profile',
        '/account',
        '/addresses',
        '/setup-shop'
      ]) {
        expect(portalRedirectFor(auth, portal, p), '/join', reason: '$role $p');
      }
    }
  });

  test('a customer of the shop gets the four tabs and their pages', () async {
    final (auth, portal) = await session(signedIn: true, role: 'customer', shop: sunny);
    for (final p in [
      '/book',
      '/orders',
      '/orders/WL-1',
      '/help',
      '/help/report',
      '/profile',
      '/addresses',
      '/s/sunny',
      '/find',
      '/location'
    ]) {
      expect(portalRedirectFor(auth, portal, p), isNull, reason: p);
    }
    // Home after sign-in (and after joining) is booking.
    expect(portalRedirectFor(auth, portal, '/join'), '/book');
    expect(portalRedirectFor(auth, portal, '/login'), '/book');
  });

  test('the root and the old account overview lead somewhere real', () {
    final routes = {for (final r in portalRoutes().whereType<GoRoute>()) r.path: r};
    expect(routes['/']!.redirect, isNotNull);
    expect(routes['/account']!.redirect, isNotNull);
    expect(routes['/account']!.builder, isNull);
  });

  test('the portal router has no CRM routes', () async {
    final paths = [for (final r in portalRoutes()) (r as dynamic).path as String];
    for (final crm in [
      '/dashboard',
      '/customers',
      '/staff',
      '/settings',
      '/setup-shop',
      '/new-order'
    ]) {
      expect(paths, isNot(contains(crm)), reason: crm);
    }
  });

  test('the status line folds the shop statuses into five steps', () {
    expect(portalStepIndex('PLACED'), 0);
    expect(portalStepIndex('PROCESSING'), 1);
    expect(portalStepIndex('IRONING'), 1);
    expect(portalStepIndex('READY'), 2);
    expect(portalStepIndex('OUT_FOR_DELIVERY'), 3);
    expect(portalStepIndex('DELIVERED'), 4);
    expect(portalStepIndex('CANCELLED'), -1);
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
    // It first tries joining with details from another laundry; with none
    // (the server says 400) it asks for them.
    expect(find.text('Joining Sunny Laundry…'), findsOneWidget);
    for (var i = 0; i < 20 && find.text('Join Sunny Laundry').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Join Sunny Laundry'), findsOneWidget);
    expect(find.text('MOBILE NUMBER'), findsOneWidget);
    expect(find.widgetWithText(TextField, '10-digit mobile'), findsOneWidget);
  });

  Widget withProviders(AuthProvider auth, PortalProvider portal, Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: portal),
        ],
        child: MaterialApp(home: home),
      );

  testWidgets('help shows the laundry contacts, report and the FAQ', (tester) async {
    final (auth, portal) = (await tester.runAsync(() => session(
        signedIn: true,
        role: 'customer',
        shop: {...sunny, 'phone': '+91 98350 12345', 'email': 'hi@sunny.in'})))!;
    await tester.pumpWidget(withProviders(auth, portal, const PortalHelpScreen()));
    expect(find.text('Contact Sunny Laundry'), findsOneWidget);
    for (final label in ['Call', 'WhatsApp', 'Email', 'Report an issue']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('How are prices decided?'), findsOneWidget);
    // Phones get the four tabs at the bottom.
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final tab in ['Book', 'Orders', 'Help', 'Profile']) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }
  });

  testWidgets('help without contact details says so', (tester) async {
    final (auth, portal) = (await tester.runAsync(
        () => session(signedIn: true, role: 'customer', shop: {...sunny, 'phone': ''})))!;
    await tester.pumpWidget(withProviders(auth, portal, const PortalHelpScreen()));
    expect(find.text('This laundry has not added contact details yet.'), findsOneWidget);
    expect(find.text('Call'), findsNothing);
  });

  testWidgets('a claim ticket shows the order number, status and five steps', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PortalTicket(
          orderNumber: 'FF-00042',
          status: 'PROCESSING',
          body: PortalStatusLine(status: 'PROCESSING'),
        ),
      ),
    ));
    expect(find.text('FF-00042'), findsOneWidget);
    expect(find.text('Cleaning'), findsNWidgets(2)); // the pill and the step
    for (final step in portalSteps) {
      expect(find.text(step), findsWidgets, reason: step);
    }
  });
}
