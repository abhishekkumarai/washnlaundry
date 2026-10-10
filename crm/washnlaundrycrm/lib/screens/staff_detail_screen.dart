import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/garment_model.dart';
import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';

/// One staff member's page: profile, the actions available on them, this
/// month's payroll position with their payout history, and attendance
/// *metadata* (counts, rate, last mark) - never the day-by-day register.
///
/// Reached from the Staff list, which swaps its body for this the same way the
/// Customers list does. [member] is the roster view-model the list builds
/// (`id`, `name`, `role`, `phone`, `email`, `wage`, `status`, `hasAppLogin`,
/// `startDate`); the list rebuilds it from the provider so edits show here.
class StaffDetailScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onSignIn;

  const StaffDetailScreen({
    super.key,
    required this.member,
    required this.onBack,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onSignIn,
  });

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  bool _loading = true;
  String? _error;
  PayrollEntryModel? _payroll;
  List<SalaryPaymentModel> _payments = const [];
  List<AttendanceModel> _attendance = const [];

  String get _id => widget.member['id'] as String;
  String get _name => widget.member['name'] as String;
  bool get _active => widget.member['status'] == 'ACTIVE';
  bool get _hasLogin => widget.member['hasAppLogin'] == true;
  DateTime get _month {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final monthKey = DateFormat('yyyy-MM').format(_month);
    try {
      final results = await Future.wait([
        ApiService.fetchPayroll(month: monthKey),
        ApiService.fetchSalaryPayments(staffId: _id),
        ApiService.fetchAttendance(month: monthKey),
      ]);
      if (!mounted) return;
      final summary = results[0] as PayrollSummaryModel;
      final all = results[2] as List<AttendanceModel>;
      setState(() {
        _payroll = summary.entries
            .where((e) => e.staffId == _id)
            .cast<PayrollEntryModel?>()
            .firstWhere((_) => true, orElse: () => null);
        _payments = results[1] as List<SalaryPaymentModel>;
        _attendance = all.where((a) => a.staffId == _id).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load this staff member\'s details.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow =
                constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return Column(
              children: [
                _header(narrow),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(narrow ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _profileCard(narrow),
                        const SizedBox(height: 16),
                        _actions(),
                        const SizedBox(height: 16),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 3, color: Color(0xFF182C4F))),
                          )
                        else if (_error != null)
                          _errorPanel()
                        else ...[
                          _kpiRow(narrow),
                          const SizedBox(height: 16),
                          LayoutBuilder(builder: (context, inner) {
                            final stacked = inner.maxWidth <
                                SidebarNavigation.contentStackBreakpoint;
                            final payroll = _payrollPanel();
                            final attendance = _attendancePanel();
                            if (stacked) {
                              return Column(children: [
                                payroll,
                                const SizedBox(height: 16),
                                attendance,
                              ]);
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: payroll),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: attendance),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header & profile ───────────────────────────────────────────────────────

  Widget _header(bool narrow) {
    return Container(
      height: narrow ? 56 : 64,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Row(
        children: [
          InkWell(
            key: const Key('staffDetailBack'),
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_rounded,
                      size: 18, color: Color(0xFF182C4F)),
                  if (!narrow) ...[
                    const SizedBox(width: 6),
                    const Text('Back to Staff',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF182C4F))),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: narrow ? 4 : 16),
          if (!narrow) ...[
            Container(height: 20, width: 1, color: const Color(0xFFD9D5CB)),
            const SizedBox(width: 16),
            const Text('Staff / ',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
          Expanded(
            child: Text(_name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: narrow ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF141A24))),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
      );

  Widget _profileCard(bool narrow) {
    final m = widget.member;
    final start = m['startDate'] as DateTime?;
    final email = (m['email'] as String?) ?? '';
    final role = m['role'] as String;
    final phone = m['phone'] as String;

    final details = <Widget>[
      _fact(Icons.phone_outlined, phone.isEmpty ? 'No phone on file' : phone),
      _fact(Icons.email_outlined, email.isEmpty ? 'No sign-in email' : email),
      _fact(
          Icons.event_outlined,
          start == null
              ? 'Start date not recorded'
              : 'Joined ${DateFormat('d MMM yyyy').format(start)} (${_tenure(start)})'),
      _fact(Icons.payments_outlined,
          '${Money.symbol}${(m['wage'] as num).toInt()} / month'),
    ];

    return Container(
      padding: EdgeInsets.all(narrow ? 14 : 18),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: narrow ? 22 : 26,
                backgroundColor: const Color(0xFF182C4F),
                child: Text(
                  _name.isNotEmpty ? _name[0].toUpperCase() : 'S',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF141A24))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _pill(role, const Color(0xFF182C4F),
                            const Color(0xFFEFF6FF)),
                        _active
                            ? _pill('Active', const Color(0xFF16A34A),
                                const Color(0xFFDCFCE7))
                            : _pill('Inactive', const Color(0xFF64748B),
                                const Color(0xFFF1EFEA)),
                        _hasLogin
                            ? _pill('Can sign in', const Color(0xFF2563EB),
                                const Color(0xFFDBEAFE))
                            : _pill('No sign-in', const Color(0xFF64748B),
                                const Color(0xFFF1EFEA)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1EFEA)),
          const SizedBox(height: 12),
          Wrap(spacing: 24, runSpacing: 8, children: details),
        ],
      ),
    );
  }

  Widget _fact(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          ),
        ],
      );

  static String _tenure(DateTime start) {
    final now = DateTime.now();
    var months = (now.year - start.year) * 12 + now.month - start.month;
    if (now.day < start.day) months -= 1;
    if (months < 1) return 'under a month';
    if (months < 12) return '$months mo';
    final y = months ~/ 12;
    final r = months % 12;
    return r == 0 ? '$y yr' : '$y yr $r mo';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Widget _actions() {
    Widget button(String label, IconData icon, VoidCallback onTap,
        {Color color = const Color(0xFF334155)}) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE4E0D8)),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        button('Edit details', Icons.edit_outlined, widget.onEdit),
        button(
            _active ? 'Mark inactive' : 'Reactivate',
            _active ? Icons.person_off_outlined : Icons.person_outline,
            widget.onToggleStatus),
        button(
            _hasLogin ? 'Manage sign-in' : 'Enable sign-in',
            _hasLogin ? Icons.key_rounded : Icons.lock_open_rounded,
            widget.onSignIn),
      ],
    );
  }

  // ── KPIs ───────────────────────────────────────────────────────────────────

  Widget _errorPanel() => Container(
        padding: const EdgeInsets.all(20),
        decoration: _panel,
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF475569)))),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF64748B))),
            ),
          ]),
          const SizedBox(height: 8),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
        ],
      ),
    );
  }

  String _money(double v) => '${Money.symbol}${v.toStringAsFixed(0)}';

  Widget _kpiRow(bool narrow) {
    final p = _payroll;
    final marked = _attendance.length;
    final rate = _attendanceRate;
    final cards = [
      _kpi(
          'Net pay (${DateFormat('MMM').format(_month)})',
          p == null ? '—' : _money(p.netPay),
          Icons.account_balance_wallet_outlined,
          const Color(0xFF182C4F)),
      _kpi('Paid', p == null ? '—' : _money(p.paidAmount),
          Icons.check_circle_outline_rounded, const Color(0xFF10B981)),
      _kpi(
          'Pending',
          p == null ? '—' : _money(p.pendingAmount),
          Icons.hourglass_bottom_rounded,
          (p?.pendingAmount ?? 0) > 0
              ? const Color(0xFFDC2626)
              : const Color(0xFF10B981)),
      _kpi('Days marked', '$marked', Icons.event_available_outlined,
          const Color(0xFF2563EB)),
      _kpi('Attendance', rate == null ? '—' : '${rate.round()}%',
          Icons.trending_up_rounded, const Color(0xFFF59E0B)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth < 480 ? 2 : (c.maxWidth < 760 ? 3 : 5);
      const gap = 10.0;
      final width = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final k in cards) SizedBox(width: width, child: k)],
      );
    });
  }

  // ── Payroll ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141A24))),
          ),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
      );

  Widget _line(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color ?? const Color(0xFF141A24))),
      ]),
    );
  }

  Widget _payrollPanel() {
    final p = _payroll;
    final recent = _payments.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Payroll',
              trailing: DateFormat('MMMM yyyy').format(_month)),
          if (p == null)
            const Text('No payroll record for this month yet.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))
          else ...[
            _line('Monthly wage', _money(p.monthlyWage)),
            _line(
                'Days worked',
                p.daysWorked.toStringAsFixed(
                    p.daysWorked == p.daysWorked.roundToDouble() ? 0 : 1)),
            _line('Gross earned', _money(p.totalSalary)),
            _line('Advances', '− ${_money(p.advancesAmount)}'),
            const Divider(height: 14, color: Color(0xFFF1EFEA)),
            _line('Net pay', _money(p.netPay), bold: true),
            _line('Paid', _money(p.paidAmount), color: const Color(0xFF10B981)),
            _line('Pending', _money(p.pendingAmount),
                bold: true,
                color: p.pendingAmount > 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF10B981)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: switch (p.status) {
                'PAID' => _pill(
                    'Paid', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
                'PARTIAL' => _pill('Partial', const Color(0xFFB45309),
                    const Color(0xFFFEF3C7)),
                _ => _pill(
                    'Unpaid', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
              },
            ),
          ],
          const SizedBox(height: 16),
          _sectionTitle('Payout history',
              trailing: _payments.isEmpty ? null : '${_payments.length} total'),
          if (recent.isEmpty)
            const Text('No salary payouts recorded.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))
          else
            for (final pay in recent)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  const Icon(Icons.south_west_rounded,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${pay.month == null ? '—' : DateFormat('MMM yyyy').format(pay.month!)}'
                      '${pay.paidOn == null ? '' : ' · paid ${DateFormat('d MMM').format(pay.paidOn!.toLocal())}'}'
                      ' · ${pay.method.replaceAll('_', ' ').toLowerCase()}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF475569)),
                    ),
                  ),
                  Text(_money(pay.amount),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A24))),
                ]),
              ),
        ],
      ),
    );
  }

  // ── Attendance (metadata only) ─────────────────────────────────────────────

  int _count(String status) =>
      _attendance.where((a) => a.status == status).length;

  /// Present = 1, half day = 0.5, over days marked; null when nothing marked.
  double? get _attendanceRate {
    if (_attendance.isEmpty) return null;
    final worked = _count('PRESENT') + 0.5 * _count('HALF_DAY');
    return worked / _attendance.length * 100;
  }

  Widget _attendancePanel() {
    final last = (_attendance.where((a) => a.date != null).toList()
          ..sort((a, b) => b.date!.compareTo(a.date!)))
        .cast<AttendanceModel?>()
        .firstWhere((_) => true, orElse: () => null);
    final stats = <(String, int, Color)>[
      ('Present', _count('PRESENT'), const Color(0xFF16A34A)),
      ('Half day', _count('HALF_DAY'), const Color(0xFFB45309)),
      ('Leave', _count('LEAVE'), const Color(0xFF2563EB)),
      ('Absent', _count('ABSENT'), const Color(0xFFDC2626)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Attendance',
              trailing: DateFormat('MMMM yyyy').format(_month)),
          if (_attendance.isEmpty)
            const Text('Nothing marked this month yet.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))
          else ...[
            for (final s in stats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: s.$3, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(s.$1,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF64748B)))),
                  Text('${s.$2}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
              ),
            const Divider(height: 14, color: Color(0xFFF1EFEA)),
            _line('Days marked', '${_attendance.length}'),
            _line('Attendance rate', '${_attendanceRate!.round()}%',
                bold: true),
            if (last != null)
              _line(
                  'Last marked',
                  '${DateFormat('d MMM').format(last.date!)} · '
                      '${last.status.replaceAll('_', ' ').toLowerCase()}'),
          ],
        ],
      ),
    );
  }
}

const BoxDecoration _panel = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFE4E0D8))),
);
