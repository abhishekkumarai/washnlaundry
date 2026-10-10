import '../models/customer_stats.dart';
import '../models/garment_model.dart';
import 'api_service.dart';

export '../models/customer_stats.dart';

/// Which KPI tab of the Customers screen a page is filtered by.
class CustomerFilter {
  static const all = 'all';
  static const active = 'active';
  static const isNew = 'new';
  static const owing = 'owing';
}

/// One page of customers plus the numbers a pager needs.
class CustomerPage {
  final List<CustomerModel> items;
  final int count;
  final int totalPages;
  final int page;

  const CustomerPage({
    required this.items,
    required this.count,
    required this.totalPages,
    required this.page,
  });
}

/// Where the Customers screen gets its rows. The screen asks for one page at a
/// time (search and tab filter included) instead of holding every customer.
abstract class CustomerDirectory {
  Future<CustomerPage> page({
    String search = '',
    String filter = CustomerFilter.all,
    int page = 1,
    int pageSize = 10,
  });

  Future<CustomerStats> stats();
}

/// Production: the API does the paging, searching and counting.
class ApiCustomerDirectory implements CustomerDirectory {
  const ApiCustomerDirectory();

  @override
  Future<CustomerPage> page({
    String search = '',
    String filter = CustomerFilter.all,
    int page = 1,
    int pageSize = 10,
  }) async {
    final result = await ApiService.fetchCustomersPaged(
        search: search.trim(), filter: filter, page: page, pageSize: pageSize);
    return CustomerPage(
      items: result.results,
      count: result.count,
      totalPages: result.totalPages < 1 ? 1 : result.totalPages,
      page: result.currentPage,
    );
  }

  @override
  Future<CustomerStats> stats() => ApiService.fetchCustomerStats();
}

/// Tests (and anything holding a ready-made list): the same contract, computed
/// over a list in memory with the same rules the server applies.
class InMemoryCustomerDirectory implements CustomerDirectory {
  final List<CustomerModel> Function() source;

  /// Amount a customer owes on delivered orders (the provider derives it from
  /// the orders it holds).
  final double Function(CustomerModel) dues;

  InMemoryCustomerDirectory(this.source, this.dues);

  static bool _isNew(CustomerModel c) {
    final at = c.createdAt;
    if (at == null) return false;
    final now = DateTime.now();
    return at.year == now.year && at.month == now.month;
  }

  List<CustomerModel> _filtered(String search, String filter) {
    final q = search.trim().toLowerCase();
    return source().where((c) {
      final matchesSearch = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.area.toLowerCase().contains(q);
      final matchesTab = switch (filter) {
        CustomerFilter.active => c.totalOrders > 0,
        CustomerFilter.isNew => _isNew(c),
        CustomerFilter.owing => dues(c) > 0,
        _ => true,
      };
      return matchesSearch && matchesTab;
    }).toList();
  }

  @override
  Future<CustomerPage> page({
    String search = '',
    String filter = CustomerFilter.all,
    int page = 1,
    int pageSize = 10,
  }) async {
    final all = _filtered(search, filter);
    final totalPages = all.isEmpty ? 1 : (all.length / pageSize).ceil();
    final current = page.clamp(1, totalPages);
    final start = (current - 1) * pageSize;
    final end = (start + pageSize).clamp(0, all.length);
    return CustomerPage(
      items: all.sublist(start, end),
      count: all.length,
      totalPages: totalPages,
      page: current,
    );
  }

  @override
  Future<CustomerStats> stats() async {
    final all = source();
    return CustomerStats(
      total: all.length,
      active: all.where((c) => c.totalOrders > 0).length,
      newThisMonth: all.where(_isNew).length,
      owing: all.where((c) => dues(c) > 0).length,
    );
  }
}
