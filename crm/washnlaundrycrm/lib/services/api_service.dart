import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/customer_stats.dart';
import '../models/garment_model.dart';
import '../models/order_media_model.dart';
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

/// Generic container for paginated API responses.
class PaginatedResult<T> {
  final int count;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final String? next;
  final String? previous;
  final List<T> results;

  const PaginatedResult({
    required this.count,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    this.next,
    this.previous,
    required this.results,
  });

  bool get hasNext => next != null && currentPage < totalPages;
  bool get hasPrevious => previous != null && currentPage > 1;
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
    if (kDebugMode) {
      if (kIsWeb) return 'http://127.0.0.1:8000/api';
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8000/api';
      }
      return 'http://127.0.0.1:8000/api';
    }
    return '/api';
  }

  /// Turns a server-relative path from the API (`/api/order-media/.../file/`)
  /// into something the browser can fetch: joined to the API's own origin when
  /// the build talks to a different host, left relative when it is same-origin.
  /// Absolute URLs (presigned R2 links) pass through untouched.
  static String absoluteUrl(String url) {
    if (!url.startsWith('/')) return url;
    final base = baseUrl;
    if (base.startsWith('http')) return Uri.parse(base).origin + url;
    return url;
  }

  static Uri _uri(String path, [Map<String, String>? query]) {
    final normalised = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalised').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};
  static const _timeout = Duration(seconds: 60);

  /// Supplies the active tenant ID / slug sent as `X-Tenant-ID`. Set by
  /// `AppProvider` or `AuthProvider`.
  static String? Function()? tenantIdProvider;

  /// Supplies the Google ID token sent as `Authorization: Bearer`. Set by
  /// `AuthProvider`; null (or a null result) sends no header, which is what
  /// Demo Mode and a backend with API_AUTH_ENFORCED off expect.
  static Future<String?> Function()? tokenProvider;

  /// Called once on a 401 to get a fresh token (Google ID tokens last ~1h).
  /// Returning true retries the request once with the new token.
  static Future<bool> Function()? onUnauthorized;

  static Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool retried = false,
    bool auth = true,
  }) async {
    final uri = _uri(path, query);
    try {
      final token = auth ? await tokenProvider?.call() : null;
      final tenantId = tenantIdProvider?.call();
      final headers = <String, String>{
        if (method == 'POST' || method == 'PATCH') ..._jsonHeaders,
        if (token != null) 'Authorization': 'Bearer $token',
        if (tenantId != null && tenantId.isNotEmpty) 'X-Tenant-ID': tenantId,
      };
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: json.encode(body))
              .timeout(_timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: json.encode(body))
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          throw ApiException('Unsupported method $method');
      }

      if (response.statusCode == 401 && !retried && onUnauthorized != null) {
        if (await onUnauthorized!()) {
          return await _send(method, path,
              query: query, body: body, retried: true, auth: auth);
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw ApiException(
        describeError(response.body, path, statusCode: response.statusCode),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not reach the server ($path): $e');
    }
  }

  // ── Email + password sign-in (no token yet, so auth: false) ──────────────

  /// Where the emailed verify / reset links should land: this app's own origin.
  static String get _returnTo {
    try {
      return Uri.base.origin;
    } catch (_) {
      return '';
    }
  }

  static Future<void> signUp(
          String email, String password, String name, String phone) =>
      _send('POST', '/auth/signup/', auth: false, body: {
        'email': email,
        'password': password,
        'name': name,
        'phone': phone,
        'return_to': _returnTo,
      });

  /// Returns `{token, email}`.
  static Future<Map<String, dynamic>> logIn(String email, String password) async =>
      Map<String, dynamic>.from(await _send('POST', '/auth/login/',
          auth: false, body: {'email': email, 'password': password}) as Map);

  static Future<Map<String, dynamic>> verifyEmail(String token) async =>
      Map<String, dynamic>.from(await _send('POST', '/auth/verify-email/',
          auth: false, body: {'token': token}) as Map);

  static Future<void> forgotPassword(String email) =>
      _send('POST', '/auth/forgot-password/',
          auth: false, body: {'email': email, 'return_to': _returnTo});

  static Future<Map<String, dynamic>> resetPassword(
          String token, String password) async =>
      Map<String, dynamic>.from(await _send('POST', '/auth/reset-password/',
          auth: false, body: {'token': token, 'password': password}) as Map);

  // ── Roles and the customer view ────────────────────────────────────────────

  /// `/me/` - `{role: staff|customer|unlinked, email, customer?, pending_link?}`.
  static Future<Map<String, dynamic>> fetchMe() async =>
      Map<String, dynamic>.from(await _send('GET', '/me/') as Map);

  /// PATCH `/customer/me/` - the customer's own editable details
  /// (name, address, area, landmark, preference). Phone and email can't change.
  static Future<Map<String, dynamic>> updateMyProfile(
          Map<String, String> fields) async =>
      Map<String, dynamic>.from(
          await _send('PATCH', '/customer/me/', body: fields) as Map);

  static Future<List<Map<String, dynamic>>> fetchMyOrders() async {
    final data = await _send('GET', '/customer/orders/') as Map;
    return (data['orders'] as List)
        .map((o) => Map<String, dynamic>.from(o as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchRateCard() async {
    final data = await _send('GET', '/customer/rate-card/') as Map;
    return (data['categories'] as List)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
  }

  /// First sign-in for an unlinked Google account. A 201 means a Customer was
  /// created; a 202 (`pending: true`) means the phone already belongs to a
  /// customer and staff must approve the email link.
  static Future<Map<String, dynamic>> customerSignup(
          String name, String phone) async =>
      Map<String, dynamic>.from(await _send('POST', '/customer/me/',
          body: {'name': name, 'phone': phone}) as Map);

  static Future<void> requestPickup(
          {required String name,
          required String phone,
          required String address,
          required String service}) =>
      // No token: that endpoint's CORS preflight only allows Content-Type.
      _send('POST', '/leads/public/', auth: false, body: {
        'name': name,
        'phone': phone,
        'address': address,
        'service': service,
      });

  /// DRF error bodies are JSON, not prose — a raw dump like
  /// `{"start_date":["This staff member already has attendance recorded
  /// before this date."]}` used to go straight into a SnackBar unparsed.
  /// This pulls out the actual sentence(s) DRF is trying to say, covering
  /// its three error shapes: `{"detail": "..."}` (custom @action responses,
  /// object-level ValidationError), `{"non_field_errors": [...]}` (a bare
  /// string raised from serializer.validate()), and `{"field": [...], ...}`
  /// (validate_<field> / a model field's own validators). Anything that
  /// isn't valid JSON (an nginx/proxy HTML error page, a raw 500 traceback)
  /// falls back to the old dump rather than showing nothing.
  ///
  /// Public (not `_send`'s private detail) and pure — no HTTP client needed —
  /// so the parsing itself is directly unit-testable, unlike `_send`.
  static String describeError(String body, String path, {int? statusCode}) {
    if (statusCode == 404) {
      return 'The requested resource was not found.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Our server encountered an issue. Please try again shortly.';
    }
    if (body.isEmpty) return 'Request to $path failed with no response body.';
    try {
      final decoded = json.decode(body);
      if (decoded is Map) {
        if (decoded['detail'] is String) return decoded['detail'] as String;
        final parts = <String>[];
        decoded.forEach((key, value) {
          final text = value is List ? value.join(' ') : value.toString();
          parts.add(key == 'non_field_errors' ? text : '$key: $text');
        });
        if (parts.isNotEmpty) return parts.join(' ');
      } else if (decoded is List && decoded.isNotEmpty) {
        return decoded.join(' ');
      }
    } catch (_) {
      // Not JSON — fall through to generic or raw body below.
      if (body.contains('<html>') || body.contains('<html') || body.contains('502') || body.contains('500')) {
        return 'Our server encountered an issue. Please try again shortly.';
      }
    }
    return 'Request to $path failed: $body';
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

  static Future<List<OrderModel>> fetchOrders(
      {String? status, String? search}) async {
    final data = await _send('GET', '/orders/', query: {
      if (status != null && status.isNotEmpty && status != 'ALL')
        'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return _asList(data).map(OrderModel.fromJson).toList();
  }

  static Future<PaginatedResult<OrderModel>> fetchOrdersPaged({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _send('GET', '/orders/', query: {
      'page': '$page',
      'page_size': '$pageSize',
      if (status != null && status.isNotEmpty && status != 'ALL')
        'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    if (data is Map) {
      final results = _asList(data).map(OrderModel.fromJson).toList();
      return PaginatedResult<OrderModel>(
        count: (data['count'] as num?)?.toInt() ?? results.length,
        totalPages: (data['total_pages'] as num?)?.toInt() ?? 1,
        currentPage: (data['current_page'] as num?)?.toInt() ?? page,
        pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
        next: data['next'] as String?,
        previous: data['previous'] as String?,
        results: results,
      );
    }
    final list = _asList(data).map(OrderModel.fromJson).toList();
    return PaginatedResult<OrderModel>(
      count: list.length,
      totalPages: 1,
      currentPage: 1,
      pageSize: list.length,
      results: list,
    );
  }

  static Future<OrderModel> fetchOrder(String id) async {
    final data = await _send('GET', '/orders/$id/');
    return OrderModel.fromJson((data as Map).cast<String, dynamic>());
  }

  // ── Order photos & videos ────────────────────────────────────────────────

  /// Asks for an upload slot. The reply is the (pending) media plus an `upload`
  /// target: a presigned Cloudflare R2 URL in production, an API URL in dev.
  static Future<Map<String, dynamic>> createMediaSlot({
    required String filename,
    required String contentType,
    required int size,
  }) async {
    final data = await _send('POST', '/order-media/', body: {
      'filename': filename,
      'content_type': contentType,
      'size': size,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Sends the file's bytes to the slot's upload target. An R2 URL is already
  /// signed, so it must NOT get our Authorization / tenant headers; the API's
  /// own dev target needs them.
  static Future<void> putMediaBytes(
      Map<String, dynamic> upload, Uint8List bytes, String contentType) async {
    final uri = Uri.parse(absoluteUrl(upload['url'].toString()));
    final headers = <String, String>{
      ...((upload['headers'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v.toString())),
      'Content-Type': contentType,
    };
    if (uri.path.startsWith('/api/order-media/')) {
      final token = await tokenProvider?.call();
      final tenantId = tenantIdProvider?.call();
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (tenantId != null && tenantId.isNotEmpty) {
        headers['X-Tenant-ID'] = tenantId;
      }
    }
    try {
      final res = await http
          .put(uri, headers: headers, body: bytes)
          .timeout(const Duration(minutes: 5));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException(
          res.statusCode == 413
              ? 'That file is too large.'
              : 'Upload failed (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not upload the file: $e');
    }
  }

  static Future<OrderMediaModel> completeMedia(String id) async {
    final data = await _send('POST', '/order-media/$id/complete/', body: const {});
    return OrderMediaModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteMedia(String id) =>
      _send('DELETE', '/order-media/$id/');

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
  static Future<OrderModel> updateOrder(
      String id, Map<String, dynamic> payload) async {
    final data = await _send('PATCH', '/orders/$id/', body: payload);
    return OrderModel.fromJson((data as Map).cast<String, dynamic>());
  }

  /// The "Collect Payment" action on the order detail screen.
  static Future<OrderModel> collectPayment(
    String id,
    double amount, {
    String paymentMethod = PaymentMethod.cash,
  }) async {
    final data = await _send('POST', '/orders/$id/payment/', body: {
      'amount': amount,
      'payment_method': paymentMethod,
    });
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

  static Future<List<Map<String, dynamic>>> fetchDefaultServices() async {
    final data = await _send('GET', '/categories/default-services/');
    return _asList(data).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> loadDefaultServices({bool overwrite = false}) async {
    final data = await _send('POST', '/categories/load-defaults/', body: {
      'overwrite': overwrite,
    });
    return Map<String, dynamic>.from(data as Map);
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

  static Future<PaginatedResult<CustomerModel>> fetchCustomersPaged({
    String? search,
    String? filter,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _send('GET', '/customers/', query: {
      'page': '$page',
      'page_size': '$pageSize',
      if (search != null && search.isNotEmpty) 'search': search,
      if (filter != null && filter.isNotEmpty && filter != 'all') 'filter': filter,
    });
    if (data is Map) {
      final results = _asList(data).map(CustomerModel.fromJson).toList();
      return PaginatedResult<CustomerModel>(
        count: (data['count'] as num?)?.toInt() ?? results.length,
        totalPages: (data['total_pages'] as num?)?.toInt() ?? 1,
        currentPage: (data['current_page'] as num?)?.toInt() ?? page,
        pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
        next: data['next'] as String?,
        previous: data['previous'] as String?,
        results: results,
      );
    }
    final list = _asList(data).map(CustomerModel.fromJson).toList();
    return PaginatedResult<CustomerModel>(
      count: list.length,
      totalPages: 1,
      currentPage: 1,
      pageSize: list.length,
      results: list,
    );
  }

  /// Shop-wide counts for the Customers KPI cards (total / active / new / owing).
  static Future<CustomerStats> fetchCustomerStats() async {
    final data = await _send('GET', '/customers/stats/');
    return CustomerStats.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<CustomerModel> createCustomer(
      Map<String, dynamic> payload) async {
    final data = await _send('POST', '/customers/', body: payload);
    return CustomerModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<CustomerModel> updateCustomer(
      String id, Map<String, dynamic> payload) async {
    final data = await _send('PATCH', '/customers/$id/', body: payload);
    return CustomerModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteCustomer(String id) =>
      _send('DELETE', '/customers/$id/');

  /// Step 1 of bulk import: uploads the raw file and gets back its column
  /// names, a few sample rows, and a best-effort field-mapping guess, for
  /// the user to confirm/edit before anything is actually created.
  static Future<Map<String, dynamic>> importCustomersPreview(
      Uint8List bytes, String filename) async {
    final request =
        http.MultipartRequest('POST', _uri('/customers/import/preview/'))
          ..files
              .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    return _sendMultipart(request);
  }

  /// Step 2: re-uploads the file alongside the confirmed
  /// {targetField: sourceColumn} mapping and bulk-creates customers from it.
  /// Returns the import summary (created/updated/skipped counts) — rows
  /// missing a name/phone are always dropped; a row whose phone duplicates
  /// another row or an existing customer is dropped too, *unless*
  /// [overwriteDuplicates] is set, in which case that existing customer's
  /// other fields are updated instead (its phone is never touched).
  static Future<Map<String, dynamic>> importCustomersCommit(
    Uint8List bytes,
    String filename,
    Map<String, String> mapping, {
    bool overwriteDuplicates = false,
  }) async {
    final request =
        http.MultipartRequest('POST', _uri('/customers/import/commit/'))
          ..fields['mapping'] = json.encode(mapping)
          ..fields['overwrite_duplicates'] = overwriteDuplicates.toString()
          ..files
              .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    return _sendMultipart(request);
  }

  static Future<Map<String, dynamic>> _sendMultipart(
      http.MultipartRequest request) async {
    try {
      final token = await tokenProvider?.call();
      final tenantId = tenantIdProvider?.call();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (tenantId != null && tenantId.isNotEmpty) {
        request.headers['X-Tenant-ID'] = tenantId;
      }
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (json.decode(response.body) as Map).cast<String, dynamic>();
      }
      throw ApiException(
        describeError(response.body, request.url.path, statusCode: response.statusCode),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
          'Could not reach the server (${request.url.path}): $e');
    }
  }

  // ── Back office ────────────────────────────────────────────────────────────

  static Future<List<StaffModel>> fetchStaff() async {
    final data = await _send('GET', '/staff/');
    return _asList(data).map(StaffModel.fromJson).toList();
  }

  static Future<PaginatedResult<StaffModel>> fetchStaffPaged({
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _send('GET', '/staff/', query: {
      'page': '$page',
      'page_size': '$pageSize',
    });
    if (data is Map) {
      final results = _asList(data).map(StaffModel.fromJson).toList();
      return PaginatedResult<StaffModel>(
        count: (data['count'] as num?)?.toInt() ?? results.length,
        totalPages: (data['total_pages'] as num?)?.toInt() ?? 1,
        currentPage: (data['current_page'] as num?)?.toInt() ?? page,
        pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
        next: data['next'] as String?,
        previous: data['previous'] as String?,
        results: results,
      );
    }
    final list = _asList(data).map(StaffModel.fromJson).toList();
    return PaginatedResult<StaffModel>(
      count: list.length,
      totalPages: 1,
      currentPage: 1,
      pageSize: list.length,
      results: list,
    );
  }

  static Future<StaffModel> createStaff(Map<String, dynamic> payload) async {
    final data = await _send('POST', '/staff/', body: payload);
    return StaffModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<StaffModel> updateStaff(
      String id, Map<String, dynamic> payload) async {
    final data = await _send('PATCH', '/staff/$id/', body: payload);
    return StaffModel.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Owner-only: gives a staff member or customer (`kind` is 'staff' or
  /// 'customers') email + password sign-in to this shop.
  static Future<Map<String, dynamic>> setCredentials(
      String kind, String id, String email, String password) async {
    final data = await _send('POST', '/$kind/$id/credentials/',
        body: {'email': email, 'password': password});
    return (data as Map).cast<String, dynamic>();
  }

  /// Owner-only: removes that sign-in again.
  static Future<void> revokeCredentials(String kind, String id) async {
    await _send('DELETE', '/$kind/$id/credentials/');
  }

  static Future<Map<String, dynamic>> setStaffCredentials(
          String id, String email, String password) =>
      setCredentials('staff', id, email, password);

  static Future<void> revokeStaffCredentials(String id) =>
      revokeCredentials('staff', id);

  static Future<List<ExpenseModel>> fetchExpenses() async {
    final data = await _send('GET', '/expenses/');
    return _asList(data).map(ExpenseModel.fromJson).toList();
  }

  static Future<ExpenseModel> createExpense(
      Map<String, dynamic> payload) async {
    final data = await _send('POST', '/expenses/', body: payload);
    return ExpenseModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<ExpenseModel> updateExpense(
      String id, Map<String, dynamic> payload) async {
    final data = await _send('PATCH', '/expenses/$id/', body: payload);
    return ExpenseModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteExpense(String id) =>
      _send('DELETE', '/expenses/$id/');

  static Future<List<CreditModel>> fetchCredits() async {
    final data = await _send('GET', '/credits/');
    return _asList(data).map(CreditModel.fromJson).toList();
  }

  static Future<CreditModel> createCredit(
      Map<String, dynamic> payload) async {
    final data = await _send('POST', '/credits/', body: payload);
    return CreditModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<CreditModel> updateCredit(
      String id, Map<String, dynamic> payload) async {
    final data = await _send('PATCH', '/credits/$id/', body: payload);
    return CreditModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteCredit(String id) =>
      _send('DELETE', '/credits/$id/');

  static Future<List<CreditCategoryModel>> fetchCreditCategories() async {
    final data = await _send('GET', '/credit-categories/');
    return _asList(data).map(CreditCategoryModel.fromJson).toList();
  }

  static Future<CreditCategoryModel> createCreditCategory(
      Map<String, dynamic> payload) async {
    final data = await _send('POST', '/credit-categories/', body: payload);
    return CreditCategoryModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<CreditCategoryModel> updateCreditCategory(
      String id, Map<String, dynamic> payload) async {
    final data =
        await _send('PATCH', '/credit-categories/$id/', body: payload);
    return CreditCategoryModel.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<void> deleteCreditCategory(String id) =>
      _send('DELETE', '/credit-categories/$id/');

  static Future<List<AttendanceModel>> fetchAttendance({
    String? date,
    String? month,
  }) async {
    final data = await _send('GET', '/attendance/', query: {
      if (date != null && date.isNotEmpty) 'date': date,
      if (month != null && month.isNotEmpty) 'month': month,
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
  static Future<PayrollSummaryModel> fetchPayroll(
      {required String month}) async {
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
    final data =
        await _send('GET', '/salary-payments/', query: {'staff': staffId});
    return _asList(data).map(SalaryPaymentModel.fromJson).toList();
  }

  /// An advance against a month's wages — comes off net pay, distinct from a
  /// [recordSalaryPayment] payout. See `SalaryAdvance` on the backend.
  static Future<void> recordSalaryAdvance(Map<String, dynamic> payload) =>
      _send('POST', '/salary-advances/', body: payload);

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

  /// The active shop. `/shops/` lists every shop the caller belongs to, so the
  /// one matching the active tenant (slug or id) is picked, not just the first.
  static Future<Map<String, dynamic>?> fetchShop() async {
    final shops = _asList(await _send('GET', '/shops/'));
    if (shops.isEmpty) return null;
    final tenant = tenantIdProvider?.call();
    if (tenant != null && tenant.isNotEmpty) {
      for (final shop in shops) {
        if (shop['slug'] == tenant || '${shop['id']}' == tenant) return shop;
      }
    }
    return shops.first;
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

  // ── RAG Chat (Cloudflare Workers AI, KAN-112) ───────────────────────────────

  /// Streams incremental assistant text from `/api/rag/chat/` — a Django
  /// proxy in front of the washnlaundry-crm-rag Worker (see backend/api/services/
  /// rag_service.py) that keeps the worker's RAG_API_KEY out of this public
  /// web bundle. [history] is prior turns in the conversation, oldest first.
  ///
  /// The proxy passes through the worker's raw SSE bytes unmodified, in
  /// whichever of Workers AI's two streaming shapes the model used:
  /// `{"response": "token"}` (text-generation models) or the OpenAI-style
  /// `{"choices":[{"delta":{"content":"token"}}]}` (chat-tuned models, which
  /// is what the worker's tool-calling round actually uses).
  /// Direct Cloudflare Worker endpoint for RAG chat (KAN-112).
  /// Calling the worker directly from Flutter web avoids proxying SSE streams
  /// through Render's single-worker Gunicorn backend, preventing request
  /// deadlocks on tool calls and server starvation.
  static String get ragWorkerUrl {
    const raw = String.fromEnvironment('RAG_WORKER_URL', defaultValue: '');
    if (raw.isNotEmpty) return raw;
    return 'https://washnlaundry-crm-rag.abhishekkumarai.workers.dev/api/rag/chat';
  }

  static Stream<String> streamRagChat(
    String message, {
    List<Map<String, String>> history = const [],
  }) async* {
    final request = http.Request('POST', Uri.parse(ragWorkerUrl))
      ..headers.addAll(_jsonHeaders)
      ..body = json.encode({
        'message': message,
        if (history.isNotEmpty) 'history': history,
      });

    late http.StreamedResponse response;
    try {
      response = await http.Client().send(request);
    } catch (e) {
      throw ApiException('Could not reach the chat service: $e');
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw ApiException(
        describeError(body, ragWorkerUrl),
        statusCode: response.statusCode,
      );
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final events = buffer.split('\n\n');
      buffer = events.removeLast(); // last piece may still be incomplete
      for (final event in events) {
        final line = event.trim();
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') continue;

        String? token;
        try {
          final decoded = json.decode(data);
          if (decoded is Map) {
            final resp = decoded['response'];
            if (resp is String) {
              token = resp;
            } else {
              final choices = decoded['choices'];
              if (choices is List && choices.isNotEmpty) {
                final delta = choices.first['delta'];
                if (delta is Map && delta['content'] is String) {
                  token = delta['content'] as String;
                }
              }
            }
          }
        } catch (_) {
          // Malformed SSE fragment — skip it rather than crash the stream.
        }
        if (token != null && token.isNotEmpty) yield token;
      }
    }
  }

  // ── Meta & Social Suite ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchMetaSettings() async {
    final res = await _send('GET', '/meta-settings/');
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> updateMetaSettings(Map<String, dynamic> data) async {
    final settings = await fetchMetaSettings();
    final id = settings['id'];
    if (id != null) {
      final res = await _send('PATCH', '/meta-settings/$id/', body: data);
      return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    }
    final res = await _send('POST', '/meta-settings/', body: data);
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> verifyMetaSettings() async {
    final res = await _send('POST', '/meta-settings/verify/', body: {});
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<List<dynamic>> fetchMetaPosts() async {
    final res = await _send('GET', '/meta-posts/');
    return res is List ? res : [];
  }

  static Future<Map<String, dynamic>> createMetaPost(Map<String, dynamic> data) async {
    final res = await _send('POST', '/meta-posts/', body: data);
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> publishMetaPost(int postId) async {
    final res = await _send('POST', '/meta-posts/$postId/publish/', body: {});
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<List<dynamic>> fetchMetaConversations() async {
    final res = await _send('GET', '/meta-messages/conversations/');
    return res is List ? res : [];
  }

  static Future<List<dynamic>> fetchMetaMessages(String conversationId) async {
    final res = await _send('GET', '/meta-messages/', query: {'conversation_id': conversationId});
    return res is List ? res : [];
  }

  static Future<Map<String, dynamic>> sendMetaReply({
    required String conversationId,
    required String text,
    String platform = 'INSTAGRAM',
    String senderName = 'Staff Support',
    String senderType = 'STAFF',
    bool useAi = false,
  }) async {
    final res = await _send('POST', '/meta-messages/reply/', body: {
      'conversation_id': conversationId,
      'text': text,
      'platform': platform,
      'sender_name': senderName,
      'sender_type': senderType,
      'use_ai': useAi,
    });
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> sendWhatsAppMessage({
    required String phone,
    required String text,
    String? recipientName,
  }) async {
    final res = await _send('POST', '/meta-messages/send-whatsapp/', body: {
      'phone': phone,
      'text': text,
      if (recipientName != null && recipientName.isNotEmpty) 'recipient_name': recipientName,
    });
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<List<dynamic>> fetchMetaLeads() async {
    final res = await _send('GET', '/meta-leads/');
    return res is List ? res : [];
  }

  static Future<Map<String, dynamic>> convertMetaLead(int leadId) async {
    final res = await _send('POST', '/meta-leads/$leadId/convert/', body: {});
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> fetchMetaSocialAnalytics() async {
    final res = await _send('GET', '/meta-social/analytics/');
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> syncMetaSocial() async {
    final res = await _send('POST', '/meta-social/sync/', body: {});
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  // ── Personal WhatsApp via Neonize ─────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchNeonizeStatus() async {
    final res = await _send('GET', '/whatsapp/neonize/status/');
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> connectNeonize() async {
    final res = await _send('POST', '/whatsapp/neonize/connect/', body: {});
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> disconnectNeonize() async {
    final res = await _send('POST', '/whatsapp/neonize/disconnect/', body: {});
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  // ── Tenant Shop Provisioning & List ────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchShops() async {
    final res = await _send('GET', '/shops/');
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> provisionShop(Map<String, dynamic> data) async {
    final res = await _send('POST', '/shops/provision/', body: data);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Closes (archives) a shop: it stops serving requests but its data is kept.
  static Future<void> archiveShop(int id) => _send('DELETE', '/shops/$id/');

  static Future<List<Map<String, dynamic>>> fetchShopMembers(int id) async {
    final res = await _send('GET', '/shops/$id/members/');
    return _asList(res);
  }

  static Future<void> transferShopOwnership(int id, String email) =>
      _send('POST', '/shops/$id/transfer-ownership/', body: {'email': email});

  static Future<void> setDefaultShop(int id) =>
      _send('POST', '/shops/$id/set-default/');

  // ── Services Import & Export (KAN-138 / KAN-144 / KAN-145) ─────────────

  /// Fetches services export as multi-tab Excel (.xlsx) workbook bytes.
  static Future<Uint8List> exportServicesXlsx({List<int>? categoryIds}) async {
    final query = <String, String>{
      'export_format': 'xlsx',
      if (categoryIds != null && categoryIds.isNotEmpty)
        'category': categoryIds.join(','),
    };
    final uri = _uri('/categories/export/', query);
    final token = await tokenProvider?.call();
    final tenantId = tenantIdProvider?.call();
    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
      if (tenantId != null && tenantId.isNotEmpty) 'X-Tenant-ID': tenantId,
    };
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(
      describeError(response.body, '/categories/export/', statusCode: response.statusCode),
      statusCode: response.statusCode,
    );
  }

  /// Fetches services export as raw CSV text string.
  static Future<String> exportServicesCsv({List<int>? categoryIds}) async {
    final query = <String, String>{
      'export_format': 'csv',
      if (categoryIds != null && categoryIds.isNotEmpty)
        'category': categoryIds.join(','),
    };
    final uri = _uri('/categories/export/', query);
    final token = await tokenProvider?.call();
    final tenantId = tenantIdProvider?.call();
    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
      if (tenantId != null && tenantId.isNotEmpty) 'X-Tenant-ID': tenantId,
    };
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }
    throw ApiException(
      describeError(response.body, '/categories/export/', statusCode: response.statusCode),
      statusCode: response.statusCode,
    );
  }

  /// Fetches services export as structured JSON catalog.
  static Future<dynamic> exportServicesJson({List<int>? categoryIds}) async {
    final query = <String, String>{
      'export_format': 'json',
      if (categoryIds != null && categoryIds.isNotEmpty)
        'category': categoryIds.join(','),
    };
    return _send('GET', '/categories/export/', query: query);
  }

  /// Uploads CSV/XLSX to preview column headers, sample rows, and suggested mappings.
  static Future<Map<String, dynamic>> importServicesPreview(
      Uint8List bytes, String filename) async {
    final request =
        http.MultipartRequest('POST', _uri('/categories/import/preview/'))
          ..files
              .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    return _sendMultipart(request);
  }

  /// Commits services import with selected field mapping and duplicate handling.
  static Future<Map<String, dynamic>> importServicesCommit(
    Uint8List bytes,
    String filename,
    Map<String, String> mapping, {
    bool overwriteDuplicates = true,
  }) async {
    final request =
        http.MultipartRequest('POST', _uri('/categories/import/commit/'))
          ..fields['mapping'] = json.encode(mapping)
          ..fields['overwrite_duplicates'] = overwriteDuplicates.toString()
          ..files
              .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    return _sendMultipart(request);
  }

  // ── CRM Full Backup & Section Exports ─────────────────────────────────────

  /// Fetches a full multi-tab Excel (.xlsx) workbook backup containing all sections.
  static Future<Uint8List> exportBackupXlsx() async {
    final uri = _uri('/backup/export/', {'export_format': 'xlsx'});
    final token = await tokenProvider?.call();
    final tenantId = tenantIdProvider?.call();
    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
      if (tenantId != null && tenantId.isNotEmpty) 'X-Tenant-ID': tenantId,
    };
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(
      describeError(response.body, '/backup/export/', statusCode: response.statusCode),
      statusCode: response.statusCode,
    );
  }

  /// Imports a CSV/JSON file written by the matching section export into the
  /// current shop (staff, orders, attendance, payroll, expenses, credits).
  /// Existing rows are skipped; the result lists created/skipped/failed rows.
  static Future<Map<String, dynamic>> importBackupSection(
    String section,
    Uint8List bytes,
    String filename, {
    bool dryRun = false,
  }) async {
    final request =
        http.MultipartRequest('POST', _uri('/backup/import/$section/'))
          ..fields['dry_run'] = dryRun.toString()
          ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: filename));
    return _sendMultipart(request);
  }

  /// Fetches a full JSON backup of all CRM sections.
  static Future<dynamic> exportBackupJson() async {
    return _send('GET', '/backup/export/', query: {'export_format': 'json'});
  }

  /// Fetches a specific section (staff, orders, attendance, payroll, customers, expenses, credits, services) as CSV text.
  static Future<String> exportSectionCsv(String section) async {
    final uri = _uri('/backup/export/$section/', {'export_format': 'csv'});
    final token = await tokenProvider?.call();
    final tenantId = tenantIdProvider?.call();
    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
      if (tenantId != null && tenantId.isNotEmpty) 'X-Tenant-ID': tenantId,
    };
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }
    throw ApiException(
      describeError(response.body, '/backup/export/$section/', statusCode: response.statusCode),
      statusCode: response.statusCode,
    );
  }

  /// Fetches a specific section as structured JSON.
  static Future<dynamic> exportSectionJson(String section) async {
    return _send('GET', '/backup/export/$section/', query: {'export_format': 'json'});
  }
}


