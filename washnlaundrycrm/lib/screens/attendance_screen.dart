import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../widgets/load_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';

/// `/attendance` in the live app. Not captured yet, so this follows our own
/// conventions rather than cloning a screenshot — see LIVE_AUDIT.md
/// "Not captured". The live route is reachable (there are no plan tiers), so
/// it can be captured and this screen checked against it.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();

  /// Edits made since the last load, as `{staffId: status}`. Kept separate from
  /// the provider's saved register so an unsaved change survives a rebuild and
  /// so Save Register knows what it is sending.
  final Map<String, String> _pending = {};

  bool _saving = false;

  /// The four values `Attendance.STATUS_CHOICES` defines. LEAVE was missing
  /// from the old chip row even though the backend has always stored it and
  /// the dashboard's staff panel counts it.
  static const _statuses = ['PRESENT', 'HALF_DAY', 'ABSENT', 'LEAVE'];

  static const _statusColors = {
    'PRESENT': Color(0xFF10B981),
    'HALF_DAY': Color(0xFFF59E0B),
    'ABSENT': Color(0xFFEF4444),
    'LEAVE': Color(0xFF8B5CF6),
  };

  static String _statusLabel(String raw) => raw.replaceAll('_', ' ');

  @override
  void initState() {
    super.initState();
    // The whole-shop load only fetches today. Ask for the selected day
    // explicitly so the screen is correct even if it is opened on another date.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().loadAttendanceFor(_selectedDate);
    });
  }

  /// Takes no BuildContext parameter on purpose: a parameter would shadow
  /// `State.context`, and the `mounted` check after the await guards the State,
  /// not some other context that happened to be passed in.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A4FD6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted || picked == null || picked == _selectedDate) return;
    setState(() {
      _selectedDate = picked;
      // Marks belong to a date. Carrying them across would file one day's
      // register under another.
      _pending.clear();
    });
    context.read<AppProvider>().loadAttendanceFor(picked);
  }

  Future<void> _save(AppProvider provider, List<StaffModel> roster) async {
    final saved = provider.attendanceFor(_selectedDate);

    // Only staff with an explicit mark are sent. This used to fall back to
    // 'PRESENT' for anyone unmarked, which invented a *paid* day for someone
    // nobody had looked at — and flatly contradicted the rest of this screen,
    // where a staff member with no row renders as "not marked" precisely
    // because defaulting them would invent a day. Re-sending already-saved
    // marks is still free: the endpoint upserts.
    final marks = <String, String>{};
    for (final s in roster) {
      final mark = _pending[s.id] ?? saved[s.id];
      if (mark != null) marks[s.id] = mark;
    }

    if (marks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to save — mark at least one staff member.'),
          backgroundColor: Color(0xFF64748B),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await provider.saveAttendance(_selectedDate, marks);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _pending.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Attendance saved successfully'
              : provider.attendanceError ?? 'Could not save the register.',
        ),
        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
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
            final narrow = constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return Column(
              children: [
                narrow ? _narrowHeader() : _wideHeader(formattedDate),
                Expanded(child: _body(provider, roster, formattedDate)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _wideHeader(String formattedDate) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Text('Attendance',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(width: 8),
          Text(DateFormat('MMM yyyy').format(_selectedDate),
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const Spacer(),

          // Calendar Date Picker Button
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded,
                size: 16, color: Color(0xFF1A4FD6)),
            label: Text(
              formattedDate,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4FD6)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1A4FD6)),
              backgroundColor: const Color(0xFFEEF2FF),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  /// Below [SidebarNavigation.contentWideBreakpoint]: title/month can't share a row with a button
  /// whose label is a full weekday+date string. Stacks title+month above the
  /// date-picker button (on its own full-width row, shortened to `d MMM
  /// yyyy` — the weekday name is the part that doesn't fit and matters least).
  Widget _narrowHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Attendance',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(DateFormat('MMM yyyy').format(_selectedDate),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_rounded,
                  size: 16, color: Color(0xFF1A4FD6)),
              label: Text(
                DateFormat('d MMM yyyy').format(_selectedDate),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A4FD6)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1A4FD6)),
                backgroundColor: const Color(0xFFEEF2FF),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
      AppProvider provider, List<StaffModel> roster, String formattedDate) {
    // Page-level states track the whole-shop load, which is where the roster
    // comes from. A failed single-day fetch is reported inline instead — it
    // must not blank a roster that loaded perfectly well.
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
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily Attendance Register',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                    Text('Mark staff presence for $formattedDate',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (_saving || roster.isEmpty)
                    ? null
                    : () => _save(provider, roster),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: Colors.white),
                label: const Text('Save Register',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4FD6),
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (provider.attendanceError != null) ...[
            _dayError(provider.attendanceError!),
            const SizedBox(height: 16),
          ],
          if (roster.isEmpty) _emptyRoster() else _register(provider, roster),
        ],
      ),
    );
  }

  /// Inline banner for a failed day fetch or save — the register itself is
  /// still usable, so this does not take over the page.
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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

  Widget _register(AppProvider provider, List<StaffModel> roster) {
    final saved = provider.attendanceFor(_selectedDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: roster.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final s = roster[idx];
          final mark = _pending[s.id] ?? saved[s.id];
          return _registerRow(s, mark);
        },
      ),
    );
  }

  /// Replaces a `ListTile(trailing: Wrap(...))` that badly mislaid out at
  /// narrow width — `ListTile` gives its `trailing` slot unconstrained
  /// intrinsic width, and a `Wrap` inside it reported a huge intrinsic
  /// width back, squeezing `title`/`subtitle` down to a couple of pixels
  /// (the name rendered one letter per line). A plain Column sidesteps
  /// ListTile's layout algorithm entirely and works at any width.
  Widget _registerRow(StaffModel s, String? mark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEEF2FF),
                child: Text(
                  s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                    Text(
                      mark == null ? '${s.role} • not marked' : s.role,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _statuses.map((status) {
              final isSel = mark == status;
              return ChoiceChip(
                label: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSel ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                selected: isSel,
                selectedColor: _statusColors[status],
                backgroundColor: const Color(0xFFF1F5F9),
                onSelected: (val) {
                  if (val) setState(() => _pending[s.id] = status);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
