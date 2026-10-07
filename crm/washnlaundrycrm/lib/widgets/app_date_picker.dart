import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Unified cross-platform date and date-range picker for Web and Android/Mobile.
///
/// Wraps [calendar_date_picker2] with the CRM's primary brand theme
/// (#1A4FD6), rounded Material surfaces, and adaptive sizing across
/// desktop browsers and mobile touchscreens.
class AppDatePicker {
  AppDatePicker._();

  static const Color primaryBlue = Color(0xFF182C4F);
  static const Color slateText = Color(0xFF141A24);
  static const Color mutedText = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE4E0D8);

  /// Launches a single date picker modal dialog styled for Web and Android.
  static Future<DateTime?> pickDate({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? title,
  }) async {
    final start = firstDate ?? DateTime(2020);
    final end = lastDate ?? DateTime(2035);
    final initial = initialDate ?? DateTime.now();

    final config = CalendarDatePicker2WithActionButtonsConfig(
      calendarType: CalendarDatePicker2Type.single,
      firstDate: start,
      lastDate: end,
      selectedDayHighlightColor: primaryBlue,
      selectedDayTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      todayTextStyle: const TextStyle(
        color: primaryBlue,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      dayTextStyle: const TextStyle(
        color: slateText,
        fontSize: 13,
      ),
      weekdayLabelTextStyle: const TextStyle(
        color: mutedText,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      controlsTextStyle: const TextStyle(
        color: slateText,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      dayBorderRadius: BorderRadius.circular(8),
      yearTextStyle: const TextStyle(
        color: slateText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      centerAlignModePicker: true,
      okButtonTextStyle: const TextStyle(
        color: primaryBlue,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      cancelButtonTextStyle: const TextStyle(
        color: mutedText,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    );

    final mediaWidth = MediaQuery.of(context).size.width;
    final isDesktop = kIsWeb && mediaWidth > 640;
    final dialogSize = Size(isDesktop ? 360 : mediaWidth * 0.9, 395);

    final results = await showCalendarDatePicker2Dialog(
      context: context,
      config: config,
      dialogSize: dialogSize,
      borderRadius: BorderRadius.circular(16),
      value: [initial],
      dialogBackgroundColor: Colors.white,
    );

    if (results != null && results.isNotEmpty && results.first != null) {
      return results.first;
    }
    return null;
  }

  /// Launches a date range picker dialog tailored for Web and Android.
  static Future<DateTimeRange?> pickDateRange({
    required BuildContext context,
    DateTimeRange? initialRange,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final start = firstDate ?? DateTime(2020);
    final end = lastDate ?? DateTime(2035);

    final config = CalendarDatePicker2WithActionButtonsConfig(
      calendarType: CalendarDatePicker2Type.range,
      firstDate: start,
      lastDate: end,
      selectedDayHighlightColor: primaryBlue,
      selectedRangeHighlightColor: primaryBlue.withValues(alpha: 0.12),
      selectedRangeDayTextStyle: const TextStyle(
        color: primaryBlue,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      selectedDayTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      todayTextStyle: const TextStyle(
        color: primaryBlue,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      dayTextStyle: const TextStyle(
        color: slateText,
        fontSize: 13,
      ),
      weekdayLabelTextStyle: const TextStyle(
        color: mutedText,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      controlsTextStyle: const TextStyle(
        color: slateText,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      dayBorderRadius: BorderRadius.circular(8),
      centerAlignModePicker: true,
      okButtonTextStyle: const TextStyle(
        color: primaryBlue,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      cancelButtonTextStyle: const TextStyle(
        color: mutedText,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    );

    final mediaWidth = MediaQuery.of(context).size.width;
    final isDesktop = kIsWeb && mediaWidth > 640;
    final dialogSize = Size(isDesktop ? 385 : mediaWidth * 0.92, 410);

    final initialValues = <DateTime?>[];
    if (initialRange != null) {
      initialValues.add(initialRange.start);
      initialValues.add(initialRange.end);
    } else {
      final now = DateTime.now();
      initialValues.add(now);
      initialValues.add(now);
    }

    final results = await showCalendarDatePicker2Dialog(
      context: context,
      config: config,
      dialogSize: dialogSize,
      borderRadius: BorderRadius.circular(16),
      value: initialValues,
      dialogBackgroundColor: Colors.white,
    );

    if (results != null && results.isNotEmpty && results.first != null) {
      final startDate = results.first!;
      final endDate = (results.length > 1 && results[1] != null)
          ? results[1]!
          : startDate;
      return DateTimeRange(start: startDate, end: endDate);
    }
    return null;
  }
}

/// A responsive, consistent button widget to trigger date selection.
class AppDateButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final double? width;
  final Color? backgroundColor;
  final Color? textColor;

  const AppDateButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.calendar_today_rounded,
    this.width,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15, color: textColor ?? const Color(0xFF334155)),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textColor ?? const Color(0xFF334155),
        ),
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: Size(width ?? double.infinity, 44),
        backgroundColor: backgroundColor ?? Colors.white,
        foregroundColor: textColor ?? const Color(0xFF334155),
        side: const BorderSide(color: Color(0xFFD9D5CB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
