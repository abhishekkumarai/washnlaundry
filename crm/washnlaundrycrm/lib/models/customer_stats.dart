/// Shop-wide counts for the KPI cards. They never depend on the search box or
/// the page being viewed, so they do not move while paging.
class CustomerStats {
  final int total;
  final int active;
  final int newThisMonth;
  final int owing;

  const CustomerStats({
    this.total = 0,
    this.active = 0,
    this.newThisMonth = 0,
    this.owing = 0,
  });

  factory CustomerStats.fromJson(Map<String, dynamic> json) => CustomerStats(
        total: (json['total'] as num?)?.toInt() ?? 0,
        active: (json['active'] as num?)?.toInt() ?? 0,
        newThisMonth: (json['new'] as num?)?.toInt() ?? 0,
        owing: (json['owing'] as num?)?.toInt() ?? 0,
      );
}
