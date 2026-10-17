import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/services/api_service.dart';

import 'support_offline_http.dart';

/// `ApiService` had zero direct unit coverage before this file — every
/// screen/provider test that touches it does so indirectly through
/// `AppProvider`. There is no mock HTTP client wired into this suite (see
/// `app_provider_coverage_test.dart`'s note on the same gap), so what's
/// pinned down here is that every public call surfaces a real, catchable
/// `ApiException` — "could not reach the server" — rather than a raw
/// platform exception leaking past `_send`'s catch-all. That's a real
/// contract: it's the one `AppProvider`'s every `try { ... } on ApiException`
/// depends on to fail gracefully instead of crashing the screen.
void main() {
  Future<void> expectApiException(Future<void> Function() call) =>
      withOfflineHttp(() => expectLater(call(), throwsA(isA<ApiException>())));

  group('ApiService surfaces ApiException, not a raw platform error', () {
    test('fetchDashboardStats', () => expectApiException(ApiService.fetchDashboardStats));

    test('fetchOrders', () => expectApiException(ApiService.fetchOrders));
    test('fetchOrder', () => expectApiException(() => ApiService.fetchOrder('1')));
    test('createOrder', () => expectApiException(() => ApiService.createOrder({})));
    test('updateOrderStatus',
        () => expectApiException(() => ApiService.updateOrderStatus('1', 'READY')));
    test('updateOrder', () => expectApiException(() => ApiService.updateOrder('1', {})));
    test('collectPayment', () => expectApiException(() => ApiService.collectPayment('1', 10)));

    test('fetchGarmentItems', () => expectApiException(ApiService.fetchGarmentItems));
    test('fetchGarmentItems(includeInactive: true)',
        () => expectApiException(() => ApiService.fetchGarmentItems(includeInactive: true)));
    test('fetchCategories', () => expectApiException(ApiService.fetchCategories));
    test('saveGarmentItem (create)', () => expectApiException(() => ApiService.saveGarmentItem({})));
    test('saveGarmentItem (update)',
        () => expectApiException(() => ApiService.saveGarmentItem({}, id: '1')));
    test('createCategory', () => expectApiException(() => ApiService.createCategory({})));
    test('updateCategory', () => expectApiException(() => ApiService.updateCategory('1', {})));
    test('deleteCategory', () => expectApiException(() => ApiService.deleteCategory('1')));
    test('deleteGarmentItem', () => expectApiException(() => ApiService.deleteGarmentItem('1')));

    test('fetchCustomers', () => expectApiException(ApiService.fetchCustomers));
    test('fetchCustomers(search:)',
        () => expectApiException(() => ApiService.fetchCustomers(search: 'ram')));
    test('createCustomer', () => expectApiException(() => ApiService.createCustomer({})));
    test('updateCustomer', () => expectApiException(() => ApiService.updateCustomer('1', {})));
    test('deleteCustomer', () => expectApiException(() => ApiService.deleteCustomer('1')));

    test('fetchStaff', () => expectApiException(ApiService.fetchStaff));
    test('createStaff', () => expectApiException(() => ApiService.createStaff({})));
    test('updateStaff', () => expectApiException(() => ApiService.updateStaff('1', {})));

    test('fetchExpenses', () => expectApiException(ApiService.fetchExpenses));
    test('createExpense', () => expectApiException(() => ApiService.createExpense({})));
    test('updateExpense', () => expectApiException(() => ApiService.updateExpense('1', {})));
    test('deleteExpense', () => expectApiException(() => ApiService.deleteExpense('1')));

    test('fetchAttendance', () => expectApiException(ApiService.fetchAttendance));
    test('fetchAttendance(date:)',
        () => expectApiException(() => ApiService.fetchAttendance(date: '2026-08-01')));
    test('saveAttendance', () => expectApiException(() => ApiService.saveAttendance('2026-08-01', const [])));

    test('fetchPayroll', () => expectApiException(() => ApiService.fetchPayroll(month: '2026-08')));
    test('recordSalaryPayment', () => expectApiException(() => ApiService.recordSalaryPayment({})));
    test('fetchSalaryPayments', () => expectApiException(() => ApiService.fetchSalaryPayments(staffId: '1')));

    test('fetchReports', () => expectApiException(ApiService.fetchReports));
    test('fetchReports(from:to:)', () => expectApiException(
        () => ApiService.fetchReports(from: '2026-08-01', to: '2026-08-31')));

    test('fetchServiceAreas', () => expectApiException(ApiService.fetchServiceAreas));
    test('createServiceArea', () => expectApiException(() => ApiService.createServiceArea({})));
    test('deleteServiceArea', () => expectApiException(() => ApiService.deleteServiceArea('1')));

    test('fetchTimeSlots', () => expectApiException(ApiService.fetchTimeSlots));
    test('fetchTimeSlots(kind:)',
        () => expectApiException(() => ApiService.fetchTimeSlots(kind: 'PICKUP')));
    test('createTimeSlot', () => expectApiException(() => ApiService.createTimeSlot({})));
    test('updateTimeSlot', () => expectApiException(() => ApiService.updateTimeSlot('1', {})));
    test('deleteTimeSlot', () => expectApiException(() => ApiService.deleteTimeSlot('1')));

    test('fetchShop', () => expectApiException(ApiService.fetchShop));
    test('updateShop', () => expectApiException(() => ApiService.updateShop('1', {})));

    test('fetchMeta', () => expectApiException(ApiService.fetchMeta));
  });

  group('ApiException', () {
    test('toString is just the message, never "ApiException (403): ..."', () {
      final e = ApiException('Not allowed.', statusCode: 403);
      expect(e.toString(), 'Not allowed.');
      expect('$e', isNot(contains('ApiException')));
      expect(e.statusCode, 403); // still available to code
    });
  });

  group('friendlyError', () {
    test('uses the server reason, with the action for context', () {
      final e = ApiException("This isn't available in Demo Mode.", statusCode: 403);
      expect(friendlyError(e, 'create the shop'),
          "Couldn't create the shop. This isn't available in Demo Mode.");
      expect(friendlyError(e), "This isn't available in Demo Mode.");
    });

    test('adds a full stop when the reason has none', () {
      expect(friendlyError(ApiException('Shop name is required'), 'save'),
          "Couldn't save. Shop name is required.");
    });

    test('anything that is not an ApiException gets a generic line, never its text', () {
      final msg = friendlyError(const FormatException('Unexpected character at 3'), 'load');
      expect(msg, "Couldn't load. Something went wrong. Please try again.");
      expect(msg, isNot(contains('FormatException')));
      expect(friendlyError(StateError('Bad state: x')), 'Something went wrong. Please try again.');
    });
  });

  group('ApiService.describeError', () {
    // A raw JSON dump used to reach the SnackBar unparsed — these pin the
    // three DRF error shapes it now turns into an actual sentence, plus the
    // non-JSON fallback.
    test('a validate_<field> error surfaces as "Field label: message"', () {
      // e.g. StaffSerializer.validate_start_date.
      final msg = ApiService.describeError(
        '{"start_date":["This staff member already has attendance recorded '
        'before this date."]}',
        '/staff/109/',
      );
      expect(msg,
          'Start date: This staff member already has attendance recorded before this date.');
    });

    test('a custom @action {"detail": ...} response is used as-is', () {
      // e.g. AttendanceViewSet.bulk's start-date rejection.
      final msg = ApiService.describeError(
        '{"detail":"Cannot mark attendance before start date for: Ramesh Kumar."}',
        '/attendance/bulk/',
      );
      expect(msg, 'Cannot mark attendance before start date for: Ramesh Kumar.');
    });

    test('a bare-string serializer.validate() error drops the field label',
        () {
      // e.g. SalaryPaymentSerializer.validate raising a plain string, which
      // DRF wraps as non_field_errors — there's no real field to prefix.
      final msg = ApiService.describeError(
        '{"non_field_errors":["This payment would exceed what Ramesh Kumar '
        'is owed for July 2026 (200.0 remaining)."]}',
        '/salary-payments/',
      );
      expect(msg,
          'This payment would exceed what Ramesh Kumar is owed for July 2026 (200.0 remaining).');
    });

    test('multiple field errors are all included', () {
      final msg = ApiService.describeError(
        '{"name":["This field is required."],"phone":["This field is required."]}',
        '/staff/',
      );
      expect(msg, contains('Name: This field is required.'));
      expect(msg, contains('Phone: This field is required.'));
    });

    test('a non-JSON HTML proxy or 502/500 page returns clean generic server failure message',
        () {
      final msg =
          ApiService.describeError('<html>502 Bad Gateway</html>', '/staff/');
      expect(msg, 'Our server encountered an issue. Please try again shortly.');
    });

    test('a 404 statusCode returns generic not found message', () {
      final msg = ApiService.describeError('{"detail":"Not found."}', '/orders/999/', statusCode: 404);
      expect(msg, 'The requested resource was not found.');
    });

    test('a 500+ statusCode returns clean generic server failure message', () {
      final msg = ApiService.describeError('Traceback (most recent call last)...', '/dashboard/stats/', statusCode: 500);
      expect(msg, 'Our server encountered an issue. Please try again shortly.');
    });

    test('an empty or non-JSON body never shows the path or the raw body', () {
      expect(ApiService.describeError('', '/staff/'),
          'Something went wrong. Please try again.');
      expect(ApiService.describeError('', '/staff/', statusCode: 403),
          "You don't have permission to do that.");
      expect(ApiService.describeError('', '/me/', statusCode: 401),
          'Your session has expired. Please sign in again.');
      final odd = ApiService.describeError('weird proxy text', '/orders/', statusCode: 418);
      expect(odd, isNot(contains('/orders/')));
      expect(odd, isNot(contains('weird proxy text')));
    });
  });
}
