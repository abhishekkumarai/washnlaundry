import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/garment_model.dart';
import '../models/order_model.dart';

import 'package:flutter/foundation.dart';

/// Thrown for any failed API call. Callers are expected to catch this and show
/// an error state — the previous version swallowed failures and returned empty
/// lists, which made a backend outage look like an empty shop.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException${statusCode != null ? ' ($statusCode)' : ''}: $message';
}

class ApiService {
  /// Override at build time:
  ///   flutter build web --dart-define=API_BASE_URL=https://api.example.com/api
  ///
  /// Defaults to same-origin `/api`, which is what the nginx container serves.
  /// Hardcoding localhost broke every deploy and the Docker build.
  ///
  /// The one exception is `kDebugMode`: `flutter run -d chrome` has no nginx
  /// proxy in front of it, so a `manage.py runserver` backend on
  /// `127.0.0.1:8000` is otherwise unreachable without typing the dart-define
  /// every time. Gating this on `kDebugMode` rather than sniffing the host
  /// keeps it out of every `flutter build web` output (debug mode is always
  /// false there) — release and Docker builds can never see this fallback,
  /// regardless of what host the browser happens to be on.
  static String get baseUrl {
    const raw = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (raw.isNotEmpty) return raw;
    if (kDebugMode && kIsWeb) return 'http://127.0.0.1:8000/api';
    return '/api';
  }

  static Uri _uri(String path, [Map<String, String>? query]) {
    final normalised = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalised').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};
  static const _timeout = Duration(seconds: 15);

  static Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = _uri(path, query);
    try {
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(uri).timeout(_timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: _jsonHeaders, body: json.encode(body))
              .timeout(_timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: _jsonHeaders, body: json.encode(body))
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri).timeout(_timeout);
          break;
        default:
          throw ApiException('Unsupported method $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw ApiException(
        'Request to $path failed: ${response.body}',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not reach the server ($path): $e');
    }
  }

  static List<Map<String, dynamic>> _asList(dynamic decoded) {
    // Tolerates both a bare list and DRF's paginated {"results": [...]} shape.
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && decoded['results'] is List) {
      return (decoded['results'] as List).cast<Map<String, dynamic>>();
    }
    return const [];
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    final data = await _send('GET', '/dashboard/stats/');
    return (data as Map).cast<String, dynamic>();
  }

  // ── Orders ─────────────────────────────────────────────────────────────────

  static Future<List<OrderModel>> fetchOrders({String? status, String? search}) async {
    final data = await _send('GET', '/orders/', query: {
      if (status != null && status.isNotEmpty && status != 'ALL') 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return _asList(data).map(OrderModel.fromJson).toList();
  }

  static Future<OrderModel> fetchOrder(String id) async {
    final data = await _send('GET', '/orders/$id/');
    return OrderModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<OrderModel> createOrder(Map<String, dynamic> payload) async {
    final data = await _send('POST', '/orders/', body: payload);
    return OrderModel.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Moves the order to [status] and stamps the matching timeline field.
  /// [note] is the optional free text from the Update Status dialog.
  static Future<OrderModel> updateOrderStatus(
    String id,
    String status, {
    String? note,
  }) async {
    final data = await _send('POST', '/orders/$id/status/', body: {
      'status': status,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return OrderModel.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Edits the order header — customer, fulfilment type, expected date, notes.
  static Future<OrderModel> updateOrder(String id, Map<String, dynamic> payload) async {
    final data = await _send('PATCH', '/orders/$id/', body: payload);
    return OrderModel.fromJson((data as Map).cast<String, dynamic>());
  }

  /// The "Collect Payment" action on the order detail screen.
  static Future<OrderModel> collectPayment(String id, double amount) async {
    final data = await _send('POST', '/orders/$id/payment/', body: {'amount': amount});
    return OrderModel.fromJson((data as Map).cast<String, dynamic>());
  }

  // ── Catalogue ──────────────────────────────────────────────────────────────

  static Future<List<GarmentItemModel>> fetchGarmentItems({
    bool includeInactive = false,
  }) async {
    final data = await _send('GET', '/items/', query: {
      if (includeInactive) 'include_inactive': 'true',
    });
    return _asList(data).map(GarmentItemModel.fromJson).toList();
  }

  static Future<List<GarmentCategoryModel>> fetchCategories() async {
    final data = await _send('GET', '/categories/');
    return _asList(data).map(GarmentCategoryModel.fromJson).toList();
  }

  static Future<GarmentItemModel> saveGarmentItem(
    Map<String, dynamic> payload, {
    String? id,
  }) async {
    final data = id == null
        ? await _send('POST', '/items/', body: payload)
        : await _send('PATCH', '/items/$id/', body: payload);
    return GarmentItemModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<GarmentCategoryModel> createCategory(
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('POST', '/categories/', body: payload);
    return GarmentCategoryModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<GarmentCategoryModel> updateCategory(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('PATCH', '/categories/$id/', body: payload);
    return GarmentCategoryModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteCategory(String id) =>
      _send('DELETE', '/categories/$id/');

  static Future<void> deleteGarmentItem(String id) =>
      _send('DELETE', '/items/$id/');

  // ── Customers ──────────────────────────────────────────────────────────────

  static Future<List<CustomerModel>> fetchCustomers({String? search}) async {
    final data = await _send('GET', '/customers/', query: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return _asList(data).map(CustomerModel.fromJson).toList();
  }

  static Future<CustomerModel> createCustomer(Map<String, dynamic> payload) async {
    final data = await _send('POST', '/customers/', body: payload);
    return CustomerModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<CustomerModel> updateCustomer(String id, Map<String, dynamic> payload) async {
    final data = await _send('PATCH', '/customers/$id/', body: payload);
    return CustomerModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteCustomer(String id) =>
      _send('DELETE', '/customers/$id/');

  // ── Back office ────────────────────────────────────────────────────────────

  static Future<List<StaffModel>> fetchStaff() async {
    final data = await _send('GET', '/staff/');
    return _asList(data).map(StaffModel.fromJson).toList();
  }

  static Future<StaffModel> createStaff(Map<String, dynamic> payload) async {
    final data = await _send('POST', '/staff/', body: payload);
    return StaffModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<StaffModel> updateStaff(String id, Map<String, dynamic> payload) async {
    final data = await _send('PATCH', '/staff/$id/', body: payload);
    return StaffModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<List<ExpenseModel>> fetchExpenses() async {
    final data = await _send('GET', '/expenses/');
    return _asList(data).map(ExpenseModel.fromJson).toList();
  }

  static Future<ExpenseModel> createExpense(Map<String, dynamic> payload) async {
    final data = await _send('POST', '/expenses/', body: payload);
    return ExpenseModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<ExpenseModel> updateExpense(String id, Map<String, dynamic> payload) async {
    final data = await _send('PATCH', '/expenses/$id/', body: payload);
    return ExpenseModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteExpense(String id) =>
      _send('DELETE', '/expenses/$id/');

  static Future<List<AttendanceModel>> fetchAttendance({String? date}) async {
    final data = await _send('GET', '/attendance/', query: {
      if (date != null && date.isNotEmpty) 'date': date,
    });
    return _asList(data).map(AttendanceModel.fromJson).toList();
  }

  /// Saves a whole day's register in one call. [date] is `YYYY-MM-DD` and each
  /// entry is `{'staff': id, 'status': 'PRESENT'}`. The backend upserts, so
  /// re-saving a day already marked overwrites it instead of colliding with
  /// the (staff, date) uniqueness constraint.
  ///
  /// Returns the saved register — the whole day, not just the rows sent.
  static Future<List<AttendanceModel>> saveAttendance(
    String date,
    List<Map<String, dynamic>> entries,
  ) async {
    final data = await _send('POST', '/attendance/bulk/', body: {
      'date': date,
      'entries': entries,
    });
    return _asList(data).map(AttendanceModel.fromJson).toList();
  }

  // ── Payroll ────────────────────────────────────────────────────────────────

  /// [month] is `YYYY-MM`. Wages are derived from the attendance register
  /// server-side, so this is one call rather than staff + attendance + payments.
  static Future<PayrollSummaryModel> fetchPayroll({required String month}) async {
    final data = await _send('GET', '/payroll/', query: {'month': month});
    return PayrollSummaryModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> recordSalaryPayment(Map<String, dynamic> payload) =>
      _send('POST', '/salary-payments/', body: payload);

  /// One staff member's payout history — every [SalaryPayment] row, not just
  /// the current month `fetchPayroll` derives totals from. The server already
  /// orders these newest-first (`-month, -paid_on`).
  static Future<List<SalaryPaymentModel>> fetchSalaryPayments({
    required String staffId,
  }) async {
    final data = await _send('GET', '/salary-payments/', query: {'staff': staffId});
    return _asList(data).map(SalaryPaymentModel.fromJson).toList();
  }

  // ── Reports ────────────────────────────────────────────────────────────────

  /// [from] and [to] are `YYYY-MM-DD`. Omitted, the server reports on the
  /// current month.
  static Future<ReportsModel> fetchReports({String? from, String? to}) async {
    final data = await _send('GET', '/reports/', query: {
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    });
    return ReportsModel.fromJson((data as Map).cast<String, dynamic>());
  }

  // ── Scheduling ─────────────────────────────────────────────────────────────

  static Future<List<ServiceAreaModel>> fetchServiceAreas() async {
    final data = await _send('GET', '/service-areas/');
    return _asList(data).map(ServiceAreaModel.fromJson).toList();
  }

  static Future<ServiceAreaModel> createServiceArea(
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('POST', '/service-areas/', body: payload);
    return ServiceAreaModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteServiceArea(String id) =>
      _send('DELETE', '/service-areas/$id/');

  static Future<List<TimeSlotModel>> fetchTimeSlots({String? kind}) async {
    final data = await _send('GET', '/time-slots/', query: {
      if (kind != null && kind.isNotEmpty) 'kind': kind,
    });
    return _asList(data).map(TimeSlotModel.fromJson).toList();
  }

  /// [payload] carries `start_time`/`end_time` as "HH:MM:SS" (Django `TimeField`)
  /// and a null `capacity` for an unlimited slot.
  static Future<TimeSlotModel> createTimeSlot(
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('POST', '/time-slots/', body: payload);
    return TimeSlotModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<TimeSlotModel> updateTimeSlot(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('PATCH', '/time-slots/$id/', body: payload);
    return TimeSlotModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteTimeSlot(String id) =>
      _send('DELETE', '/time-slots/$id/');

  // ── Shop ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchShop() async {
    final shops = _asList(await _send('GET', '/shops/'));
    return shops.isEmpty ? null : shops.first;
  }

  static Future<Map<String, dynamic>> updateShop(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('PATCH', '/shops/$id/', body: payload);
    return (data as Map).cast<String, dynamic>();
  }

  // ── Meta ───────────────────────────────────────────────────────────────────

  /// The canonical vocabularies (payment methods, expense categories, statuses)
  /// that the screens used to hardcode one copy of each.
  static Future<MetaModel> fetchMeta() async {
    final data = await _send('GET', '/meta/');
    return MetaModel.fromJson((data as Map).cast<String, dynamic>());
  }
}
