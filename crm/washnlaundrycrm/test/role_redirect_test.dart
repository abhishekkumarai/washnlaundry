import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washnlaundrycrm/providers/auth_provider.dart';
import 'package:washnlaundrycrm/router.dart';

/// `authRedirectFor`: who may open which route, mirroring the backend's
/// IsOwner / IsStaff / customer-only permissions (backend/api/auth.py).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AuthProvider> session({required bool signedIn, String? role}) async {
    final auth = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    auth.setSessionForTest(signedIn: signedIn, role: role);
    return auth;
  }

  test('signed out is sent to /login from anywhere', () async {
    final auth = await session(signedIn: false);
    expect(authRedirectFor(auth, '/orders'), '/login');
    expect(authRedirectFor(auth, '/my/orders'), '/login');
    expect(authRedirectFor(auth, '/login'), isNull);
  });

  test('signed in but role not yet known: no redirect', () async {
    final auth = await session(signedIn: true);
    expect(authRedirectFor(auth, '/payroll'), isNull);
  });

  test('owner may open everything staff-side but not /my', () async {
    final auth = await session(signedIn: true, role: 'owner');
    for (final p in ['/dashboard', '/payroll', '/reports', '/orders/abc']) {
      expect(authRedirectFor(auth, p), isNull, reason: p);
    }
    expect(authRedirectFor(auth, '/login'), '/dashboard');
    expect(authRedirectFor(auth, '/my/orders'), '/dashboard');
  });

  test('staff is limited to orders, new order, customers, scan', () async {
    final auth = await session(signedIn: true, role: 'staff');
    for (final p in ['/orders', '/orders/abc', '/new-order', '/customers', '/scan']) {
      expect(authRedirectFor(auth, p), isNull, reason: p);
    }
    for (final p in ['/dashboard', '/payroll', '/reports', '/expenses', '/staff',
        '/attendance', '/settings', '/credits', '/my/orders']) {
      expect(authRedirectFor(auth, p), '/orders', reason: p);
    }
    expect(authRedirectFor(auth, '/login'), '/orders');
  });

  test('customer is kept inside /my/*', () async {
    final auth = await session(signedIn: true, role: 'customer');
    for (final p in ['/my/orders', '/my/orders/WL-1', '/my/rate-card', '/my/book']) {
      expect(authRedirectFor(auth, p), isNull, reason: p);
    }
    for (final p in ['/dashboard', '/orders', '/customers', '/my/start', '/login']) {
      expect(authRedirectFor(auth, p), '/my/orders', reason: p);
    }
  });

  test('unlinked Google account only sees /my/start', () async {
    final auth = await session(signedIn: true, role: 'unlinked');
    expect(authRedirectFor(auth, '/my/start'), isNull);
    expect(authRedirectFor(auth, '/my/orders'), '/my/start');
    expect(authRedirectFor(auth, '/dashboard'), '/my/start');
  });
}
