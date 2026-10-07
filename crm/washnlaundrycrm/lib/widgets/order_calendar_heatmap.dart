import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// A month-view calendar for the Orders screen, coloring each day by how
/// many orders came in on it — a heatmap over [table_calendar] rather than
/// a plain date picker. Tapping a day returns it to the caller so it can be
/// applied as a single-day filter, same shape as [AppDatePicker.pickDateRange]
/// but browsable month-to-month instead of typed/scrolled.
class OrderCalendarHeatmap extends StatefulWidget {
  const OrderCalendarHeatmap({
    super.key,
    required this.countsByDay,
    this.initialFocusedDay,
  });

  /// Order counts keyed by the start of each day (`DateTime(y, m, d)`).
  final Map<DateTime, int> countsByDay;
  final DateTime? initialFocusedDay;

  static const Color primaryBlue = Color(0xFF182C4F);
  static const Color slateText = Color(0xFF141A24);
  static const Color mutedText = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE4E0D8);

  /// Launches the heatmap in a dialog and resolves to the tapped day, or
  /// `null` if dismissed without a selection.
  static Future<DateTime?> pickDay({
    required BuildContext context,
    required Map<DateTime, int> countsByDay,
    DateTime? initialFocusedDay,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: OrderCalendarHeatmap(
          countsByDay: countsByDay,
          initialFocusedDay: initialFocusedDay,
        ),
      ),
    );
  }

  @override
  State<OrderCalendarHeatmap> createState() => _OrderCalendarHeatmapState();
}

class _OrderCalendarHeatmapState extends State<OrderCalendarHeatmap> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialFocusedDay ?? DateTime.now();
    _selectedDay = widget.initialFocusedDay;
  }

  DateTime _normalize(DateTime day) => DateTime(day.year, day.month, day.day);

  int _countFor(DateTime day) => widget.countsByDay[_normalize(day)] ?? 0;

  int get _maxCount => widget.countsByDay.values.isEmpty
      ? 0
      : widget.countsByDay.values.reduce((a, b) => a > b ? a : b);

  /// Heat color for a day's order count — white at zero, ramping up to full
  /// brand blue at the busiest day in [countsByDay] so the scale is relative
  /// to this shop's own order volume rather than a fixed threshold.
  Color _heatColor(int count) {
    if (count <= 0 || _maxCount <= 0) return Colors.white;
    final intensity = 0.15 + 0.65 * (count / _maxCount);
    return Color.lerp(Colors.white, OrderCalendarHeatmap.primaryBlue, intensity)!;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Orders calendar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: OrderCalendarHeatmap.slateText,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            TableCalendar<void>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2035),
              rowHeight: 46,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) =>
                  _selectedDay != null && isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
                Navigator.of(context).pop(_normalize(selected));
              },
              onPageChanged: (focused) => _focusedDay = focused,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OrderCalendarHeatmap.slateText,
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OrderCalendarHeatmap.mutedText,
                ),
                weekendStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OrderCalendarHeatmap.mutedText,
                ),
              ),
              calendarStyle: const CalendarStyle(outsideDaysVisible: false),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) =>
                    _dayCell(day, _countFor(day)),
                todayBuilder: (context, day, focusedDay) =>
                    _dayCell(day, _countFor(day), isToday: true),
                selectedBuilder: (context, day, focusedDay) =>
                    _dayCell(day, _countFor(day), isSelected: true),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendSwatch(Colors.white, 'None'),
                const SizedBox(width: 10),
                _legendSwatch(
                    _heatColor((_maxCount / 2).ceil().clamp(1, _maxCount == 0 ? 1 : _maxCount)),
                    'Some'),
                const SizedBox(width: 10),
                _legendSwatch(_heatColor(_maxCount), 'Busy'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(DateTime day, int count,
      {bool isToday = false, bool isSelected = false}) {
    final onHeat = count > (_maxCount / 2);
    return Container(
      margin: const EdgeInsets.all(3),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _heatColor(count),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? OrderCalendarHeatmap.primaryBlue
                    : isToday
                        ? OrderCalendarHeatmap.primaryBlue.withValues(alpha: 0.5)
                        : OrderCalendarHeatmap.borderColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                color: onHeat ? Colors.white : OrderCalendarHeatmap.slateText,
              ),
            ),
          ),
          // Order count for the day — the color heat alone doesn't say a
          // number, so the count is spelled out as a badge.
          if (count > 0)
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                key: ValueKey('order-count-badge-${_normalize(day)}'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: OrderCalendarHeatmap.primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  '$count',
                  semanticsLabel: '$count orders',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendSwatch(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: OrderCalendarHeatmap.borderColor),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: OrderCalendarHeatmap.mutedText)),
      ],
    );
  }
}
