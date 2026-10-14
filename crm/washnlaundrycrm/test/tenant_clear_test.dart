import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'active_tenant_id': 'old-shop'}));

  test('clearTenant forgets the shop so the next sign-in never sends it', () async {
    final app = AppProvider(autoLoad: false);
    app.setActiveTenant('demo-abc');
    await Future<void>.delayed(Duration.zero); // let the fire-and-forget pref write land
    app.setAvailableShops([
      {'slug': 'demo-abc', 'name': 'Demo'}
    ]);
    expect(app.activeTenantId, 'demo-abc');

    await app.clearTenant();

    expect(app.activeTenantId, isNull);
    expect(app.availableShops, isEmpty);
    expect((await SharedPreferences.getInstance()).getString('active_tenant_id'), isNull);
  });
}
