import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';

/// `AppProvider`'s mutating/loading methods (`addCustomer`, `updateStaff`,
/// `loadPayrollFor`, ...) had zero direct unit coverage before this file —
/// every existing `app_provider_test.dart` case exercises the pure,
/// network-free getters (`ordersForFilter`, `filteredOrders`, counters).
///
/// There is no mock HTTP seam in this suite (the same gap `wip.md` notes for
/// order/customer/expense creation), so none of these calls can be driven to
/// their success branch here. What every one of them CAN be driven to,
/// deterministically and fast, is their failure branch: `ApiService.baseUrl`
/// resolves to the relative `/api` in a `flutter test` VM run (`kIsWeb` is
/// false, so the `kDebugMode` dev-convenience never applies), and `package:http`
/// rejects a schemeless URI immediately with "No host specified" — caught by
/// `ApiService._send`'s catch-all and rethrown as `ApiException`, which every
/// one of these methods already handles by setting `error`/`*Error` and
/// returning `false`/an empty result rather than throwing. Exercising that
/// path is what proves each method's error handling actually holds, and it's
/// the only path reachable without a real backend.
void main() {
  late AppProvider provider;

  setUp(() {
    provider = AppProvider(autoLoad: false);
  });

  group('navIndexForPath', () {
    test('maps every section, including synonyms', () {
      expect(AppProvider.navIndexForPath('/new-order'), 1);
      expect(AppProvider.navIndexForPath('/new_order'), 1);
      expect(AppProvider.navIndexForPath('/neworder'), 1);
      expect(AppProvider.navIndexForPath('/create-order'), 1);
      expect(AppProvider.navIndexForPath('/orders'), 2);
      expect(AppProvider.navIndexForPath('/order'), 2);
      expect(AppProvider.navIndexForPath('/customers'), 3);
      expect(AppProvider.navIndexForPath('/customer'), 3);
      expect(AppProvider.navIndexForPath('/services'), 4);
      expect(AppProvider.navIndexForPath('/service'), 4);
      expect(AppProvider.navIndexForPath('/items'), 4);
      expect(AppProvider.navIndexForPath('/staff'), 5);
      expect(AppProvider.navIndexForPath('/team'), 5);
      expect(AppProvider.navIndexForPath('/employees'), 5);
      expect(AppProvider.navIndexForPath('/attendance'), 6);
      expect(AppProvider.navIndexForPath('/payroll'), 7);
      expect(AppProvider.navIndexForPath('/expenses'), 8);
      expect(AppProvider.navIndexForPath('/expense'), 8);
      expect(AppProvider.navIndexForPath('/credits'), 15);
      expect(AppProvider.navIndexForPath('/settings'), 13);
      expect(AppProvider.navIndexForPath('/credit'), 15);
      expect(AppProvider.navIndexForPath('/reports'), 9);
      expect(AppProvider.navIndexForPath('/report'), 9);
      expect(AppProvider.navIndexForPath('/scan'), 11);
      expect(AppProvider.navIndexForPath('/qr'), 11);
      expect(AppProvider.navIndexForPath('/dashboard'), 0);
      expect(AppProvider.navIndexForPath(''), 0);
      expect(AppProvider.navIndexForPath('/something-unknown'), 0);
    });

    test('strips leading slashes, query strings, and is case-insensitive', () {
      expect(AppProvider.navIndexForPath('///orders'), 2);
      expect(AppProvider.navIndexForPath('/ORDERS'), 2);
      expect(AppProvider.navIndexForPath('/orders?status=paid'), 2);
      expect(AppProvider.navIndexForPath('  /staff  '), 5);
    });
  });

  group('shop-driven settings fall back to the constants they replaced', () {
    test('with no shop loaded yet', () {
      expect(provider.expressMultiplier, 1.5);
      expect(provider.defaultMonthlyWage, 18000.0);
      expect(provider.defaultStaffRole, 'Washer');
      expect(provider.currencySymbol, '₹');
      expect(provider.locale, 'en_IN');
    });

    test('once a shop record loads, its own values win', () {
      provider.seedForTest(shop: {
        'id': 1,
        'express_multiplier': 2.0,
        'default_monthly_wage': 21000.0,
        'default_staff_role': 'Presser',
        'currency_symbol': r'\$',
        'locale': 'en_US',
      });
      expect(provider.expressMultiplier, 2.0);
      expect(provider.defaultMonthlyWage, 21000.0);
      expect(provider.defaultStaffRole, 'Presser');
      expect(provider.currencySymbol, r'\$');
      expect(provider.locale, 'en_US');
    });

    test('a blank staff role/currency/locale also falls back, not just a missing key', () {
      provider.seedForTest(shop: {'id': 1, 'default_staff_role': '', 'currency_symbol': '', 'locale': ''});
      expect(provider.defaultStaffRole, 'Washer');
      expect(provider.currencySymbol, '₹');
      expect(provider.locale, 'en_IN');
    });
  });

  group('meta-served vocabularies', () {
    test('paymentMethods falls back to the four the model declares', () {
      expect(provider.paymentMethods.map((c) => c.value),
          ['CASH', 'UPI', 'CARD', 'BANK_TRANSFER']);
    });

    test('paymentMethods prefers the served list once /meta/ lands', () {
      provider.seedForTest(meta: const MetaModel(
        paymentMethods: [ChoiceModel(value: 'WALLET', label: 'Wallet')],
      ));
      expect(provider.paymentMethods.map((c) => c.value), ['WALLET']);
    });

    test('expenseCategories is empty until /meta/ lands', () {
      expect(provider.expenseCategories, isEmpty);
      provider.seedForTest(meta: const MetaModel(
        expenseCategories: [ChoiceModel(value: 'RENT', label: 'Rent')],
      ));
      expect(provider.expenseCategories.map((c) => c.value), ['RENT']);
    });
  });

  group('toggleSidebar', () {
    test('flips and notifies', () {
      var notified = 0;
      provider.addListener(() => notified++);
      expect(provider.sidebarCollapsed, isFalse);
      provider.toggleSidebar();
      expect(provider.sidebarCollapsed, isTrue);
      provider.toggleSidebar();
      expect(provider.sidebarCollapsed, isFalse);
      expect(notified, 2);
    });
  });

  group('attendanceFor', () {
    test('keys the register by day, leaving an unmarked staffer absent from the map', () {
      provider.seedForTest(attendance: [
        AttendanceModel(id: '1', staffId: '9', staffName: 'A', date: DateTime(2026, 8, 10), status: 'PRESENT'),
        AttendanceModel(id: '2', staffId: '10', staffName: 'B', date: DateTime(2026, 8, 11), status: 'ABSENT'),
      ]);
      final day = provider.attendanceFor(DateTime(2026, 8, 10));
      expect(day, {'9': 'PRESENT'});
    });

    test('a day with nothing marked yet is an empty map, not a crash', () {
      expect(provider.attendanceFor(DateTime(2026, 1, 1)), isEmpty);
    });
  });

  group('date/month key formatting', () {
    test('dateKey pads single-digit month and day', () {
      expect(AppProvider.dateKey(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('monthKey pads a single-digit month', () {
      expect(AppProvider.monthKey(DateTime(2026, 3)), '2026-03');
    });
  });

  group('mutators fail gracefully with no server reachable', () {
    test('addCustomer', () async {
      final ok = await provider.addCustomer({'name': 'X', 'phone': '1'});
      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });

    test('updateCustomer', () async {
      final ok = await provider.updateCustomer('1', {'name': 'X'});
      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });

    test('deleteCustomer', () async {
      final ok = await provider.deleteCustomer('1');
      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });

    test('addStaff', () async {
      final ok = await provider.addStaff({'name': 'X'});
      expect(ok, isFalse);
    });

    test('updateStaff', () async {
      final ok = await provider.updateStaff('1', {'name': 'X'});
      expect(ok, isFalse);
    });

    test('addGarmentItem', () async {
      final ok = await provider.addGarmentItem({'name': 'X'});
      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });

    test('updateGarmentItem', () async {
      final ok = await provider.updateGarmentItem('1', {'name': 'X'});
      expect(ok, isFalse);
    });

    test('deleteGarmentItem', () async {
      final ok = await provider.deleteGarmentItem('1');
      expect(ok, isFalse);
    });

    test('addCategory returns null, not an id', () async {
      final id = await provider.addCategory({'name': 'X'});
      expect(id, isNull);
      expect(provider.error, isNotNull);
    });

    test('updateCategory', () async {
      final ok = await provider.updateCategory('1', {'name': 'X'});
      expect(ok, isFalse);
    });

    test('deleteCategory', () async {
      final ok = await provider.deleteCategory('1');
      expect(ok, isFalse);
    });

    test('addServiceArea', () async {
      final ok = await provider.addServiceArea({'name': 'X'});
      expect(ok, isFalse);
    });

    test('deleteServiceArea', () async {
      final ok = await provider.deleteServiceArea('1');
      expect(ok, isFalse);
    });

    test('addTimeSlot', () async {
      final ok = await provider.addTimeSlot({'kind': 'PICKUP'});
      expect(ok, isFalse);
    });

    test('updateTimeSlot', () async {
      final ok = await provider.updateTimeSlot('1', {'kind': 'PICKUP'});
      expect(ok, isFalse);
    });

    test('deleteTimeSlot', () async {
      final ok = await provider.deleteTimeSlot('PICKUP', '1');
      expect(ok, isFalse);
    });

    test('saveShop with no shop loaded yet reports that, not a network error', () async {
      final ok = await provider.saveShop({'name': 'X'});
      expect(ok, isFalse);
      expect(provider.error, 'No shop loaded yet.');
    });

    test('saveShop with a shop loaded hits the network and fails gracefully', () async {
      provider.seedForTest(shop: {'id': 1, 'name': 'washing'});
      final ok = await provider.saveShop({'name': 'X'});
      expect(ok, isFalse);
      expect(provider.error, isNot('No shop loaded yet.'));
    });

    test('addExpense', () async {
      final ok = await provider.addExpense({'title': 'X', 'amount': 10});
      expect(ok, isFalse);
    });

    test('updateExpense', () async {
      final ok = await provider.updateExpense('1', {'title': 'X'});
      expect(ok, isFalse);
    });

    test('deleteExpense', () async {
      final ok = await provider.deleteExpense('1');
      expect(ok, isFalse);
    });

    test('saveAttendance', () async {
      final ok = await provider.saveAttendance(DateTime(2026, 8, 1), {'1': 'PRESENT'});
      expect(ok, isFalse);
      expect(provider.attendanceError, isNotNull);
    });

    test('recordSalaryPayment', () async {
      final ok = await provider.recordSalaryPayment(
        staffId: '1',
        month: DateTime(2026, 8),
        amount: 1000,
      );
      expect(ok, isFalse);
    });

    test('fetchSalaryHistory throws rather than silently returning nothing',
        () async {
      await expectLater(provider.fetchSalaryHistory('1'), throwsA(anything));
    });

    test('updateOrderStatus', () async {
      final ok = await provider.updateOrderStatus('1', 'READY');
      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });

    test('collectPayment', () async {
      final ok = await provider.collectPayment('1', 500);
      expect(ok, isFalse);
    });
  });

  group('loaders', () {
    test('loadAttendanceFor sets attendanceError and clears attendanceLoading',
        () async {
      expect(provider.attendanceLoading, isFalse);
      await provider.loadAttendanceFor(DateTime(2026, 8, 1));
      expect(provider.attendanceLoading, isFalse);
      expect(provider.attendanceError, isNotNull);
    });

    test('loadPayrollFor sets payrollError and clears payrollLoading', () async {
      expect(provider.payrollLoading, isFalse);
      await provider.loadPayrollFor(DateTime(2026, 8));
      expect(provider.payrollLoading, isFalse);
      expect(provider.payrollError, isNotNull);
    });

    test('loadReportsFor sets reportsError and clears reportsLoading', () async {
      expect(provider.reportsLoading, isFalse);
      await provider.loadReportsFor(DateTime(2026, 8, 1), DateTime(2026, 8, 31));
      expect(provider.reportsLoading, isFalse);
      expect(provider.reportsError, isNotNull);
    });

    test('loadDataFromBackend sets error and clears isLoading', () async {
      expect(provider.isLoading, isFalse);
      await provider.loadDataFromBackend();
      expect(provider.isLoading, isFalse);
      expect(provider.hasError, isTrue);
    });

    test('refresh delegates to loadDataFromBackend', () async {
      await provider.refresh();
      expect(provider.hasError, isTrue);
    });
  });
}
