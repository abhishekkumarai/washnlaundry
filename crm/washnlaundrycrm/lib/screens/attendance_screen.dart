import 'package:flutter/material.dart';
import 'package:flutter_calendar_collection/business/habit_tracker/streak_counter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/error_dialog.dart';
import '../widgets/load_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';

enum AttendanceViewMode { day, month, habits }

/// `/attendance` screen.
/// Includes:
/// 1. Header with date picker, prev/next day steppers, Day/Month view toggles,
///    and "Mark all present" button.
/// 2. 5 KPI summary cards: Present, Half Day, Absent, Leave, and Not marked.
/// 3. Daily Staff Attendance Register with segmented status toggles, note inputs,
///    and check-in time picker.
/// 4. Monthly Attendance Calendar Heatmap / Matrix displaying all days in the month
///    with today highlighted, status icons, monthly totals, and status legend.
/// 5. Habit Tracker & Attendance Streaks powered by flutter_calendar_collection StreakCounter.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  late DateTime _calendarMonth;
  AttendanceViewMode _viewMode = AttendanceViewMode.day;
  String? _selectedHabitStaffId;

  /// Edits made since the last load, as `{staffId: status}`.
  final Map<String, String> _pending = {};
  final Map<String, String> _notes = {};
  final Map<String, String> _checkInTimes = {};

  bool _saving = false;

  static const _statuses = ['PRESENT', 'HALF_DAY', 'ABSENT', 'LEAVE'];

  static const _statusColors = {
    'PRESENT': Color(0xFF10B981),
    'HALF_DAY': Color(0xFFF59E0B),
    'ABSENT': Color(0xFFEF4444),
    'LEAVE': Color(0xFF8B5CF6),
  };

  bool _notYetStarted(StaffModel s, [DateTime? targetDate]) {
    final date = targetDate ?? _selectedDate;
    return s.startDate != null &&
        DateUtils.dateOnly(date).isBefore(DateUtils.dateOnly(s.startDate!));
  }

  @override
  void initState() {
    super.initState();
    _calendarMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<AppProvider>();
        provider.loadAttendanceFor(_selectedDate);
        provider.loadAttendanceForMonth(_calendarMonth);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await AppDatePicker.pickDate(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (!mounted || picked == null || picked == _selectedDate) return;
    setState(() {
      _selectedDate = picked;
      _pending.clear();
      _calendarMonth = DateTime(picked.year, picked.month, 1);
    });
    final provider = context.read<AppProvider>();
    provider.loadAttendanceFor(picked);
    provider.loadAttendanceForMonth(_calendarMonth);
  }

  void _stepDay(int delta) {
    final next = _selectedDate.add(Duration(days: delta));
    setState(() {
      _selectedDate = next;
      _pending.clear();
      if (next.month != _calendarMonth.month ||
          next.year != _calendarMonth.year) {
        _calendarMonth = DateTime(next.year, next.month, 1);
        context.read<AppProvider>().loadAttendanceForMonth(_calendarMonth);
      }
    });
    context.read<AppProvider>().loadAttendanceFor(next);
  }

  void _stepMonth(int delta) {
    setState(() {
      _calendarMonth =
          DateTime(_calendarMonth.year, _calendarMonth.month + delta, 1);
    });
    context.read<AppProvider>().loadAttendanceForMonth(_calendarMonth);
  }

  /// Like the live app, the register saves as you go — there is no Save
  /// button. "Mark all present" goes straight to the backend too.
  Future<void> _markAllPresent(AppProvider provider) async {
    setState(() => _saving = true);
    final ok = await provider.markAllPresent(_selectedDate);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All active staff marked Present.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      await showErrorDialog(
        context,
        title: 'Could not mark everyone present',
        message: provider.attendanceError ?? 'Unknown error.',
      );
    }
  }

  /// Now as the backend's TimeField expects it — "HH:mm", 24-hour. (The
  /// screen used to send "03:47 PM", which Django rejects.)
  static String _nowHhMm() => DateFormat('HH:mm').format(DateTime.now());

  /// "15:47" / "15:47:00" → "3:47 PM" for display; anything unparseable is
  /// shown as-is.
  static String _displayTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return raw;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }

  /// Saves one staff member's mark for the selected day immediately. The
  /// status shows at once (via [_pending]) and is cleared once the backend
  /// has it, or rolled back with an error if it refused.
  Future<void> _saveOne(StaffModel s, String status) async {
    final provider = context.read<AppProvider>();
    final rec = provider.attendanceRecord(_selectedDate, s.id);
    final hasCheckIn =
        (_checkInTimes[s.id] ?? rec?.checkInTime ?? '').isNotEmpty;
    // Marking someone in stamps a check-in time, as the live app does; it
    // can be corrected from the row's ⋮ menu.
    if (!hasCheckIn && (status == 'PRESENT' || status == 'HALF_DAY')) {
      _checkInTimes[s.id] = _nowHhMm();
    }
    setState(() => _pending[s.id] = status);
    final ok = await provider.saveAttendance(
      _selectedDate,
      {s.id: status},
      checkInTimes:
          _checkInTimes.containsKey(s.id) ? {s.id: _checkInTimes[s.id]} : null,
      notes: _notes.containsKey(s.id) ? {s.id: _notes[s.id]!} : null,
    );
    if (!mounted) return;
    setState(() => _pending.remove(s.id));
    if (!ok) {
      await showErrorDialog(
        context,
        title: 'Could not save ${s.name}',
        message: provider.attendanceError ?? 'Unknown error.',
      );
    }
  }

  /// Saves a changed note once the field loses focus — only for someone
  /// already marked, since the backend stores notes on the day's record.
  void _saveNote(StaffModel s) {
    final provider = context.read<AppProvider>();
    final rec = provider.attendanceRecord(_selectedDate, s.id);
    final mark = _pending[s.id] ?? provider.attendanceFor(_selectedDate)[s.id];
    final note = _notes[s.id];
    if (mark == null || note == null || note == (rec?.notes ?? '')) return;
    _saveOne(s, mark);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final formattedDate =
        DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate);
    final roster = provider.staff.where((s) => s.isActive).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow =
                constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return _body(provider, roster, formattedDate, narrow);
          },
        ),
      ),
    );
  }

  /// "Fri, 25 Sep · Today" — the live app's date button label.
  String get _dateButtonLabel {
    final base = DateFormat('EEE, d MMM').format(_selectedDate);
    return DateUtils.isSameDay(_selectedDate, DateTime.now())
        ? '$base · Today'
        : base;
  }

  static const _pageTitle = Text(
    'Attendance',
    style: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Color(0xFF0F172A),
    ),
  );

  /// Live layout: title, then the date button and ‹ › beside it on the left;
  /// the view toggle and "Mark all present" on the right.
  Widget _wideHeader() {
    final provider = context.read<AppProvider>();
    // A Wrap, not a Row: at the tight end of "wide" the right-hand group
    // drops to its own line instead of overflowing. Full width, or
    // spaceBetween has no free space to push that group right.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pageTitle,
              const SizedBox(width: 14),
              _dateNavigationControls(_dateButtonLabel),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _viewModeToggle(),
              const SizedBox(width: 12),
              _markAllPresentButton(provider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _narrowHeader() {
    final provider = context.read<AppProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle,
        const SizedBox(height: 10),
        _dateNavigationControls(_dateButtonLabel, isNarrow: true),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _viewModeToggle(isNarrow: true),
              _markAllPresentButton(provider, isCompact: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateNavigationControls(String dateLabel, {bool isNarrow = false}) {
    final dateButton = OutlinedButton(
      key: const ValueKey('attendance-date-button'),
      onPressed: _pickDate,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 15, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              dateLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Color(0xFF64748B)),
        ],
      ),
    );

    if (isNarrow) {
      return Row(
        children: [
          Expanded(child: dateButton),
          const SizedBox(width: 6),
          _stepButton(
              Icons.chevron_left_rounded, () => _stepDay(-1), 'Previous day'),
          const SizedBox(width: 4),
          _stepButton(
              Icons.chevron_right_rounded, () => _stepDay(1), 'Next day'),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dateButton,
        const SizedBox(width: 6),
        _stepButton(
            Icons.chevron_left_rounded, () => _stepDay(-1), 'Previous day'),
        const SizedBox(width: 4),
        _stepButton(Icons.chevron_right_rounded, () => _stepDay(1), 'Next day'),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
      ),
    );
  }

  Widget _viewModeToggle({bool isNarrow = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleOption('Day', AttendanceViewMode.day, isNarrow: isNarrow),
          _toggleOption('Month', AttendanceViewMode.month, isNarrow: isNarrow),
          _toggleOption('Habits', AttendanceViewMode.habits,
              isNarrow: isNarrow),
        ],
      ),
    );
  }

  Widget _toggleOption(String label, AttendanceViewMode mode,
      {bool isNarrow = false}) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isNarrow ? 11 : 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _markAllPresentButton(AppProvider provider, {bool isCompact = false}) {
    return OutlinedButton.icon(
      onPressed: _saving ? null : () => _markAllPresent(provider),
      icon: const Icon(Icons.how_to_reg_outlined,
          size: 16, color: Color(0xFF2563EB)),
      label: Text(
        isCompact ? 'Mark All' : 'Mark all present',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2563EB),
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF2563EB)),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _body(
    AppProvider provider,
    List<StaffModel> roster,
    String formattedDate,
    bool narrow,
  ) {
    if (provider.hasError) {
      return ErrorState(
        title: 'Error loading attendance',
        message: provider.error!,
      );
    }
    if (provider.isLoading) {
      return const LoadingState();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(narrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          narrow ? _narrowHeader() : _wideHeader(),
          const SizedBox(height: 16),

          // 5 KPI Summary Cards Row
          _kpiCardsRow(provider, roster, narrow),
          const SizedBox(height: 16),

          if (provider.attendanceError != null) ...[
            _dayError(provider.attendanceError!),
            const SizedBox(height: 16),
          ],

          // The live Day view shows the month grid under the register;
          // Month view is the grid alone.
          if (_viewMode == AttendanceViewMode.day) ...[
            _dailyRegisterCard(provider, roster, formattedDate, narrow),
            const SizedBox(height: 16),
            _monthlyMatrixCard(provider, roster, narrow),
          ] else if (_viewMode == AttendanceViewMode.month)
            _monthlyMatrixCard(provider, roster, narrow)
          else
            _habitTrackerCard(provider, roster, narrow),
        ],
      ),
    );
  }

  Widget _kpiCardsRow(
      AppProvider provider, List<StaffModel> roster, bool narrow) {
    final saved = provider.attendanceFor(_selectedDate);

    int presentCount = 0;
    int halfDayCount = 0;
    int absentCount = 0;
    int leaveCount = 0;
    int notMarkedCount = 0;

    for (final s in roster) {
      if (_notYetStarted(s)) continue;
      final status = _pending[s.id] ?? saved[s.id];
      switch (status) {
        case 'PRESENT':
          presentCount++;
          break;
        case 'HALF_DAY':
          halfDayCount++;
          break;
        case 'ABSENT':
          absentCount++;
          break;
        case 'LEAVE':
          leaveCount++;
          break;
        default:
          notMarkedCount++;
          break;
      }
    }

    final cards = [
      _kpiCard(
        title: 'Present',
        count: presentCount,
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF10B981),
        bgColor: const Color(0xFFECFDF5),
      ),
      _kpiCard(
        title: 'Half Day',
        count: halfDayCount,
        icon: Icons.schedule_rounded,
        iconColor: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFFFBEB),
      ),
      _kpiCard(
        title: 'Absent',
        count: absentCount,
        icon: Icons.highlight_off_rounded,
        iconColor: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFEF2F2),
      ),
      _kpiCard(
        title: 'Leave',
        count: leaveCount,
        icon: Icons.flight_takeoff_rounded,
        iconColor: const Color(0xFF64748B),
        bgColor: const Color(0xFFF1F5F9),
      ),
      _kpiCard(
        title: 'Not marked',
        count: notMarkedCount,
        icon: Icons.help_outline_rounded,
        iconColor: const Color(0xFF64748B),
        bgColor: const Color(0xFFF8FAFC),
      ),
    ];

    if (narrow) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(width: 140, child: c)).toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                  child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: c,
              )))
          .toList(),
    );
  }

  Widget _kpiCard({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyRegisterCard(
    AppProvider provider,
    List<StaffModel> roster,
    String formattedDate,
    bool narrow,
  ) {
    // No title bar and no Save button: the live register is just the table,
    // and every mark saves as it is made (see _saveOne).
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (roster.isEmpty)
            _emptyRoster()
          else if (!narrow)
            _wideTableView(provider, roster)
          else
            _narrowListView(provider, roster),
        ],
      ),
    );
  }

  Widget _wideTableView(AppProvider provider, List<StaffModel> roster) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Staff',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Note',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Check-in',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              SizedBox(width: 36),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: roster.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, idx) {
            final s = roster[idx];
            final saved = provider.attendanceFor(_selectedDate);
            final rec = provider.attendanceRecord(_selectedDate, s.id);
            final mark = _pending[s.id] ?? saved[s.id];
            return _dailyStaffRow(s, mark, rec);
          },
        ),
      ],
    );
  }

  Widget _narrowListView(AppProvider provider, List<StaffModel> roster) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: roster.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, idx) {
        final s = roster[idx];
        final saved = provider.attendanceFor(_selectedDate);
        final rec = provider.attendanceRecord(_selectedDate, s.id);
        final mark = _pending[s.id] ?? saved[s.id];
        return _dailyStaffRowNarrow(s, mark, rec);
      },
    );
  }

  Widget _dailyStaffRow(StaffModel s, String? mark, AttendanceModel? rec) {
    final notYetStarted = _notYetStarted(s);
    final checkIn = _checkInTimes[s.id] ?? rec?.checkInTime;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Staff Column
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name and role on one line, as in the live register.
                Expanded(child: _staffNameLine(s, notYetStarted)),
              ],
            ),
          ),

          // Status Column
          Expanded(
            flex: 5,
            // scaleDown: shrinks the group slightly rather than overflowing
            // when the Status column is narrow.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _statusGroup(s, mark, notYetStarted),
            ),
          ),

          // Note Column
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Focus(
                onFocusChange: (focused) {
                  if (!focused) _saveNote(s);
                },
                child: TextFormField(
                  key: ValueKey('note_${s.id}'),
                  initialValue: _notes[s.id] ?? rec?.notes ?? '',
                  enabled: mark != null,
                  onChanged: (val) => _notes[s.id] = val,
                  onFieldSubmitted: (_) => _saveNote(s),
                  decoration: InputDecoration(
                    hintText:
                        mark == null ? 'Not marked yet' : 'Add note (optional)',
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),

          // Check-in Column
          Expanded(
            flex: 2,
            child: Text(
              checkIn != null && checkIn.isNotEmpty
                  ? _displayTime(checkIn)
                  : '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: checkIn != null
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),

          // Action Menu Column
          PopupMenuButton<String>(
            icon:
                const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
            onSelected: (val) {
              if (val == 'check_in') {
                _pickCheckInTime(s);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'check_in',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('Check-in time', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dailyStaffRowNarrow(
      StaffModel s, String? mark, AttendanceModel? rec) {
    final notYetStarted = _notYetStarted(s);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _staffNameLine(s, notYetStarted)),
            ],
          ),
          const SizedBox(height: 10),
          _statusGroup(s, mark, notYetStarted, expand: true),
        ],
      ),
    );
  }

  /// "abhishek  Staff" — the name, then the role in grey on the same line.
  Widget _staffNameLine(StaffModel s, bool notYetStarted) {
    final role = notYetStarted
        ? '${s.role} · joins ${DateFormat('d MMM yyyy').format(s.startDate!)}'
        : s.role;
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: s.name,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A)),
        ),
        TextSpan(
          text: '  $role',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  static const _statusGroupLabels = {
    'PRESENT': 'Present',
    'HALF_DAY': 'Half',
    'ABSENT': 'Absent',
    'LEAVE': 'Leave',
  };

  /// The live app's joined "Present | Half | Absent | Leave" control. A tap
  /// saves immediately.
  Widget _statusGroup(StaffModel s, String? mark, bool notYetStarted,
      {bool expand = false}) {
    Widget segment(int i) {
      final status = _statuses[i];
      final selected = mark == status;
      final colour = _statusColors[status]!;
      final first = i == 0;
      final last = i == _statuses.length - 1;
      final cell = InkWell(
        key: ValueKey('attendance-${s.id}-$status'),
        onTap: notYetStarted || selected ? null : () => _saveOne(s, status),
        child: Container(
          height: 30,
          constraints: const BoxConstraints(minWidth: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colour.withValues(alpha: 0.14) : Colors.white,
            border: Border(
              left: first
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            borderRadius: BorderRadius.horizontal(
              left: first ? const Radius.circular(6) : Radius.zero,
              right: last ? const Radius.circular(6) : Radius.zero,
            ),
          ),
          child: Text(
            _statusGroupLabels[status]!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: notYetStarted
                  ? const Color(0xFFCBD5E1)
                  : selected
                      ? colour
                      : const Color(0xFF334155),
            ),
          ),
        ),
      );
      return expand ? Expanded(child: cell) : cell;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (var i = 0; i < _statuses.length; i++) segment(i)],
      ),
    );
  }

  Future<void> _pickCheckInTime(StaffModel s) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    // 24-hour "HH:mm" — what the backend's TimeField accepts.
    _checkInTimes[s.id] =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final provider = context.read<AppProvider>();
    final mark = _pending[s.id] ?? provider.attendanceFor(_selectedDate)[s.id];
    await _saveOne(s, mark ?? 'PRESENT');
  }

  Widget _monthlyMatrixCard(
      AppProvider provider, List<StaffModel> roster, bool narrow) {
    final monthName = DateFormat('MMMM yyyy').format(_calendarMonth);
    final daysInMonth =
        DateUtils.getDaysInMonth(_calendarMonth.year, _calendarMonth.month);
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Matrix header: "‹ September ›" on the left, as in the live app —
          // no card title.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _stepMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  tooltip: 'Previous month',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Text(
                  _calendarMonth.year == DateTime.now().year
                      ? DateFormat('MMMM').format(_calendarMonth)
                      : monthName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  onPressed: () => _stepMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  tooltip: 'Next month',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Grid Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Staff | Days (1..N) | Totals
                  Row(
                    children: [
                      const SizedBox(
                        width: 140,
                        child: Text(
                          'Staff',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      for (int day = 1; day <= daysInMonth; day++) ...[
                        _monthDayHeaderCell(day, now),
                      ],
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 90,
                        child: Text(
                          'Totals',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Per-Staff Rows
                  for (final s in roster) ...[
                    _monthStaffMatrixRow(provider, s, daysInMonth, now),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Footer: Legend and "Totals flow into Payroll"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _legendItem('Present', const Color(0xFF10B981)),
                _legendItem('Half Day', const Color(0xFFF59E0B)),
                _legendItem('Absent', const Color(0xFFEF4444)),
                _legendItem('Leave', const Color(0xFF64748B)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('?',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 6),
                    const Text('Not marked',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                const Tooltip(
                  message:
                      'Present and half days are used to calculate salaries on the Payroll page',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Totals flow into Payroll',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.info_outline,
                          size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthDayHeaderCell(int day, DateTime now) {
    final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
    final weekdayInitial = DateFormat('E').format(date)[0];
    final isToday =
        now.year == date.year && now.month == date.month && now.day == day;

    return Container(
      width: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFF2563EB) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isToday ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            weekdayInitial,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _monthStaffMatrixRow(
    AppProvider provider,
    StaffModel s,
    int daysInMonth,
    DateTime now,
  ) {
    int present = 0;
    int halfDay = 0;
    int absent = 0;
    int leave = 0;

    final cells = <Widget>[];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
      final isFuture =
          DateUtils.dateOnly(date).isAfter(DateUtils.dateOnly(now));
      final notStarted = _notYetStarted(s, date);

      String? mark;
      if (DateUtils.dateOnly(date) == DateUtils.dateOnly(_selectedDate) &&
          _pending.containsKey(s.id)) {
        mark = _pending[s.id];
      } else {
        mark = provider.attendanceFor(date)[s.id];
      }

      if (mark == 'PRESENT') present++;
      if (mark == 'HALF_DAY') halfDay++;
      if (mark == 'ABSENT') absent++;
      if (mark == 'LEAVE') leave++;

      cells.add(_monthCell(s, date, mark,
          isFuture: isFuture, notStarted: notStarted));
    }

    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
        ...cells,
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            '$present · $halfDay · $absent · $leave',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155)),
          ),
        ),
      ],
    );
  }

  Widget _monthCell(
    StaffModel s,
    DateTime date,
    String? mark, {
    required bool isFuture,
    required bool notStarted,
  }) {
    if (isFuture || notStarted) {
      return Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        child: const Text('—',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
      );
    }

    Widget content;
    Color bgColor = Colors.transparent;
    Border? border;

    switch (mark) {
      case 'PRESENT':
        bgColor = const Color(0xFFD1FAE5);
        content = const Icon(Icons.check, size: 14, color: Color(0xFF10B981));
        break;
      case 'HALF_DAY':
        bgColor = const Color(0xFFFEF3C7);
        content = const Text('½',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD97706)));
        break;
      case 'ABSENT':
        bgColor = const Color(0xFFFEE2E2);
        content = const Icon(Icons.close, size: 14, color: Color(0xFFEF4444));
        break;
      case 'LEAVE':
        bgColor = const Color(0xFFF1F5F9);
        content = const Icon(Icons.flight_takeoff,
            size: 12, color: Color(0xFF64748B));
        break;
      default:
        border = Border.all(color: const Color(0xFFCBD5E1));
        content = const Text('?',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)));
        break;
    }

    return InkWell(
      onTap: () => _toggleCellStatus(s, date, mark),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: border,
        ),
        child: content,
      ),
    );
  }

  void _toggleCellStatus(StaffModel s, DateTime date, String? currentStatus) {
    final nextStatus = currentStatus == null
        ? 'PRESENT'
        : currentStatus == 'PRESENT'
            ? 'HALF_DAY'
            : currentStatus == 'HALF_DAY'
                ? 'ABSENT'
                : currentStatus == 'ABSENT'
                    ? 'LEAVE'
                    : null;

    if (nextStatus == null) return;
    // The selected day goes through the register's own save, so its row and
    // KPIs update the same way a status tap does.
    if (DateUtils.isSameDay(date, _selectedDate)) {
      _saveOne(s, nextStatus);
    } else {
      context.read<AppProvider>().saveAttendance(date, {s.id: nextStatus});
    }
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _dayError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 17, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          ),
          TextButton(
            onPressed: () =>
                context.read<AppProvider>().loadAttendanceFor(_selectedDate),
            child: const Text('Retry',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }

  Widget _emptyRoster() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: const Column(
        children: [
          Icon(Icons.groups_outlined, size: 34, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text('No active staff to mark.',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          SizedBox(height: 4),
          Text('Add someone on the Staff screen first.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  StreakCounter _getStreakCounterFor(
      StaffModel? staff, List<StaffModel> roster, AppProvider provider) {
    final completed = <DateTime>{};
    if (staff != null) {
      for (final a in provider.attendance) {
        if (a.staffId == staff.id &&
            (a.status == 'PRESENT' || a.status == 'HALF_DAY') &&
            a.date != null) {
          completed.add(DateTime(a.date!.year, a.date!.month, a.date!.day));
        }
      }
      if (_pending.containsKey(staff.id)) {
        final p = _pending[staff.id];
        final todayOnly = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day);
        if (p == 'PRESENT' || p == 'HALF_DAY') {
          completed.add(todayOnly);
        } else {
          completed.remove(todayOnly);
        }
      }
    } else {
      final activeIds = roster.map((s) => s.id).toSet();
      for (final a in provider.attendance) {
        if (activeIds.contains(a.staffId) &&
            (a.status == 'PRESENT' || a.status == 'HALF_DAY') &&
            a.date != null) {
          completed.add(DateTime(a.date!.year, a.date!.month, a.date!.day));
        }
      }
      for (final entry in _pending.entries) {
        if (activeIds.contains(entry.key) &&
            (entry.value == 'PRESENT' || entry.value == 'HALF_DAY')) {
          completed.add(DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day));
        }
      }
    }
    return StreakCounter(completedDates: completed);
  }

  Widget _habitTrackerCard(
      AppProvider provider, List<StaffModel> roster, bool narrow) {
    final selectedStaff = _selectedHabitStaffId != null
        ? roster.firstWhere(
            (s) => s.id == _selectedHabitStaffId,
            orElse: () => roster.isNotEmpty
                ? roster.first
                : const StaffModel(id: '0', name: 'None', role: '', phone: ''),
          )
        : null;
    final isTeamOverview = selectedStaff == null;

    final currentCounter = _getStreakCounterFor(
      selectedStaff,
      roster,
      provider,
    );

    final currentStreak = currentCounter.currentStreak;
    final longestStreak = currentCounter.longestStreak;
    final totalCheckins = currentCounter.totalCompleted;
    final monthRate = currentCounter.completionRateInMonth(
        _calendarMonth.year, _calendarMonth.month);
    final monthCompleted = currentCounter.completedInMonth(
        _calendarMonth.year, _calendarMonth.month);
    final monthTotal = currentCounter.totalDaysInMonth(
        _calendarMonth.year, _calendarMonth.month);

    final monthName = DateFormat('MMMM yyyy').format(_calendarMonth);

    final staffStats = roster.map((s) {
      final counter = _getStreakCounterFor(s, roster, provider);
      return (
        staff: s,
        counter: counter,
        currentStreak: counter.currentStreak,
        longestStreak: counter.longestStreak,
        totalCompleted: counter.totalCompleted,
        monthRate: counter.completionRateInMonth(
            _calendarMonth.year, _calendarMonth.month),
      );
    }).toList()
      ..sort((a, b) {
        final c = b.currentStreak.compareTo(a.currentStreak);
        return c != 0 ? c : b.monthRate.compareTo(a.monthRate);
      });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Subtitle + Staff Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _habitHeaderTitle(),
                      const SizedBox(height: 12),
                      _staffFilterChips(roster),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _habitHeaderTitle()),
                      _staffFilterChips(roster),
                    ],
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4 Habit KPI Metric Cards
                _habitKpiRow(
                  currentStreak: currentStreak,
                  longestStreak: longestStreak,
                  totalCheckins: totalCheckins,
                  monthRate: monthRate,
                  monthCompleted: monthCompleted,
                  monthTotal: monthTotal,
                  monthName: monthName,
                  narrow: narrow,
                ),
                const SizedBox(height: 20),

                // Monthly Consistency Progress
                _habitMonthlyConsistencyBar(
                  monthName: monthName,
                  monthRate: monthRate,
                  monthCompleted: monthCompleted,
                  monthTotal: monthTotal,
                ),
                const SizedBox(height: 24),

                // Streak Leaderboard Table
                _habitLeaderboard(staffStats, narrow),
                const SizedBox(height: 24),

                // Month Calendar Grid / Heatmap for selected staff
                _habitMonthGrid(
                  counter: currentCounter,
                  staffName:
                      isTeamOverview ? 'Team Overall' : selectedStaff.name,
                  narrow: narrow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitHeaderTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFFEA580C), size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'Attendance Habit Tracker & Streaks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Track continuous active work streaks, consistency rates, and check-in habits.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _staffFilterChips(List<StaffModel> roster) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChoiceChip(
            label: const Text('All Team',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            selected: _selectedHabitStaffId == null,
            selectedColor: const Color(0xFF2563EB),
            backgroundColor: const Color(0xFFF1F5F9),
            labelStyle: TextStyle(
              color: _selectedHabitStaffId == null
                  ? Colors.white
                  : const Color(0xFF475569),
            ),
            onSelected: (val) {
              if (val) setState(() => _selectedHabitStaffId = null);
            },
          ),
          ...roster.map((s) {
            final isSel = _selectedHabitStaffId == s.id;
            return Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: ChoiceChip(
                label: Text(s.name,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
                selected: isSel,
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : const Color(0xFF475569),
                ),
                onSelected: (val) {
                  setState(() => _selectedHabitStaffId = val ? s.id : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _habitKpiRow({
    required int currentStreak,
    required int longestStreak,
    required int totalCheckins,
    required double monthRate,
    required int monthCompleted,
    required int monthTotal,
    required String monthName,
    required bool narrow,
  }) {
    final cards = [
      _habitKpiMetric(
        icon: Icons.local_fire_department_rounded,
        iconColor: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
        label: 'Current Streak',
        value: '$currentStreak days',
        subtitle: currentStreak > 0
            ? 'Active consecutive shifts'
            : 'No active streak',
      ),
      _habitKpiMetric(
        icon: Icons.emoji_events_rounded,
        iconColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFEF3C7),
        label: 'Best Streak',
        value: '$longestStreak days',
        subtitle: 'All-time personal record',
      ),
      _habitKpiMetric(
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF10B981),
        bgColor: const Color(0xFFD1FAE5),
        label: 'Total Check-ins',
        value: '$totalCheckins days',
        subtitle: 'Verified present shifts',
      ),
      _habitKpiMetric(
        icon: Icons.pie_chart_outline_rounded,
        iconColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        label: 'Monthly Consistency',
        value: '${(monthRate * 100).toStringAsFixed(0)}%',
        subtitle: '$monthCompleted of $monthTotal days in $monthName',
      ),
    ];

    if (narrow) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(width: 150, child: c)).toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                  child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: c,
              )))
          .toList(),
    );
  }

  Widget _habitKpiMetric({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _habitMonthlyConsistencyBar({
    required String monthName,
    required double monthRate,
    required int monthCompleted,
    required int monthTotal,
  }) {
    final barColor = monthRate >= 0.8
        ? const Color(0xFF10B981)
        : monthRate >= 0.5
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Consistency for $monthName',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155)),
              ),
              const Spacer(),
              Text(
                '$monthCompleted / $monthTotal shifts (${(monthRate * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: monthTotal > 0
                  ? (monthCompleted / monthTotal).clamp(0.0, 1.0)
                  : 0.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitLeaderboard(List<dynamic> stats, bool narrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Staff Attendance Streak Leaderboard',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, idx) {
              final item = stats[idx];
              final s = item.staff as StaffModel;
              final currentStreak = item.currentStreak as int;
              final longestStreak = item.longestStreak as int;
              final monthRate = item.monthRate as double;

              final medal = idx == 0
                  ? '🥇'
                  : idx == 1
                      ? '🥈'
                      : idx == 2
                          ? '🥉'
                          : '#${idx + 1}';

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(medal,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Text(
                        s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A4FD6)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A))),
                          Text(s.role,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: currentStreak > 0
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🔥 $currentStreak d streak',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: currentStreak > 0
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!narrow) ...[
                      Text(
                        'Best: $longestStreak d',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 70,
                        child: Text(
                          '${(monthRate * 100).toStringAsFixed(0)}% rate',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _habitMonthGrid({
    required StreakCounter counter,
    required String staffName,
    required bool narrow,
  }) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_calendarMonth.year, _calendarMonth.month);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Habit Calendar — $staffName',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
            const Spacer(),
            Text(
              DateFormat('MMMM yyyy').format(_calendarMonth),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(daysInMonth, (i) {
            final day = i + 1;
            final date =
                DateTime(_calendarMonth.year, _calendarMonth.month, day);
            final isFuture =
                DateUtils.dateOnly(date).isAfter(DateUtils.dateOnly(now));
            final isCompleted = counter.isCompleted(date);
            final isToday = DateUtils.isSameDay(date, now);

            Color bgColor = const Color(0xFFF1F5F9);
            Color textColor = const Color(0xFF64748B);
            Widget icon = const SizedBox.shrink();

            if (isCompleted) {
              bgColor = const Color(0xFFD1FAE5);
              textColor = const Color(0xFF065F46);
              icon =
                  const Icon(Icons.check, size: 10, color: Color(0xFF10B981));
            } else if (isFuture) {
              bgColor = const Color(0xFFF8FAFC);
              textColor = const Color(0xFFCBD5E1);
            }

            return Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
                border: isToday
                    ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
                    : Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday || isCompleted
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 12,
                    child: icon,
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
