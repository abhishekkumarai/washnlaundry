import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/attendance_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(1600, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  final today = DateTime.now();
  final roster = [
    const StaffModel(id: '1', name: 'Ramesh Kumar', role: 'Head Washer', phone: '1'),
    const StaffModel(id: '2', name: 'Geeta Devi', role: 'Dry Cleaning Specialist', phone: '2'),
    const StaffModel(
        id: '3', name: 'Bhola Prasad', role: 'Retired', phone: '3', status: 'INACTIVE'),
  ];

  final register = [
    AttendanceModel(id: '10', staffId: '1', staffName: 'Ramesh Kumar', date: today, status: 'HALF_DAY'),
    AttendanceModel(id: '11', staffId: '2', staffName: 'Geeta Devi', date: today, status: 'LEAVE'),
  ];

  /// The InkWell behind one status segment ("attendance-<staffId>-<STATUS>").
  /// Its onTap is null when that status is already selected (nothing to
  /// change) or the whole row is disabled.
  InkWell segment(WidgetTester tester, String staffId, String status) =>
      tester.widget<InkWell>(
          find.byKey(ValueKey('attendance-$staffId-$status')));

  group('AttendanceScreen start date', () {
    final futureStarter = StaffModel(
      id: '4',
      name: 'Not Yet Started',
      role: 'Washer',
      phone: '4',
      startDate: today.add(const Duration(days: 5)),
    );

    testWidgets('a staff member who has not started yet shows a joins-date hint',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [futureStarter]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.textContaining('joins'), findsOneWidget);
    });

    testWidgets('their status segments are disabled', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [futureStarter]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      for (final s in ['PRESENT', 'HALF_DAY', 'ABSENT', 'LEAVE']) {
        expect(segment(tester, '4', s).onTap, isNull, reason: s);
      }
    });

    testWidgets('tapping a disabled segment does not try to save',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [futureStarter]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('attendance-4-PRESENT')),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('joins'), findsOneWidget);
    });
  });

  group('AttendanceScreen', () {
    testWidgets('the roster comes from the provider, not a literal', (tester) async {
      // The screen used to hardcode six staff, none of whom were the seeded
      // roster — 'Mohan Das' and 'Anita Sharma' were pure invention.
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.textContaining('Ramesh Kumar'), findsWidgets);
      expect(find.textContaining('Geeta Devi'), findsWidgets);
      expect(find.textContaining('Mohan Das'), findsNothing);
      expect(find.textContaining('Anita Sharma'), findsNothing);
    });

    testWidgets('inactive staff are not on the register', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.textContaining('Bhola Prasad'), findsNothing);
    });

    testWidgets('name and role sit on one line', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.text('Ramesh Kumar  Head Washer'), findsOneWidget);
      expect(find.textContaining('not marked'), findsNothing);
    });

    testWidgets('saved marks show as the selected segment', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: roster, attendance: register);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(segment(tester, '1', 'HALF_DAY').onTap, isNull); // selected
      expect(segment(tester, '1', 'PRESENT').onTap, isNotNull);
      expect(segment(tester, '2', 'LEAVE').onTap, isNull);
      expect(segment(tester, '2', 'ABSENT').onTap, isNotNull);
    });

    testWidgets('the four statuses read like the live app', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      for (final (status, label) in [
        ('PRESENT', 'Present'),
        ('HALF_DAY', 'Half'),
        ('ABSENT', 'Absent'),
        ('LEAVE', 'Leave'),
      ]) {
        expect(
            find.descendant(
                of: find.byKey(ValueKey('attendance-1-$status')),
                matching: find.text(label)),
            findsOneWidget,
            reason: status);
      }
      expect(find.text('HALF DAY'), findsNothing);
    });

    testWidgets('there is no Save button — the register saves as you go',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.text('Save Register'), findsNothing);
      expect(find.text('Daily Attendance Register'), findsNothing);
    });

    testWidgets('a tap saves at once and a failure is reported, not hidden',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first], attendance: []);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('attendance-1-ABSENT')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // the request fails
      await tester.pumpAndSettle();
      // No Save press needed — the tap itself hit the network, and the
      // failure is a popup, not a silent success.
      expect(find.text('Could not save Ramesh Kumar'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('an untouched register marks nobody', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first], attendance: []);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      for (final s in ['PRESENT', 'HALF_DAY', 'ABSENT', 'LEAVE']) {
        expect(segment(tester, '1', s).onTap, isNotNull, reason: s);
      }
    });

    testWidgets('an empty roster says so', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: []);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.text('No active staff to mark.'), findsOneWidget);
    });

    testWidgets('the note field opens once someone is marked', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: roster, attendance: [register.first]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields, hasLength(2));
      expect(fields[0].enabled, isTrue); // Ramesh — marked
      expect(fields[1].enabled, isFalse); // Geeta — not marked yet
    });

    testWidgets('a saved check-in time is shown as a clock time',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first], attendance: [
          AttendanceModel(
            id: '20',
            staffId: '1',
            staffName: 'Ramesh Kumar',
            date: today,
            status: 'PRESENT',
            checkInTime: '15:47:00',
          ),
        ]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.text('3:47 PM'), findsOneWidget);
      expect(find.text('15:47:00'), findsNothing);
    });

    group('responsive layout', () {
      Future<void> pumpAt(WidgetTester tester, double width) async {
        tester.view
          ..physicalSize = Size(width, 1200)
          ..devicePixelRatio = 1.0;
        final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
        await tester.pumpWidget(host(provider, const AttendanceScreen()));
        await tester.pump();
      }

      final todayLabel =
          '${DateFormat('EEE, d MMM').format(DateTime.now())} · Today';

      testWidgets('the date button reads like the live one at wide width',
          (tester) async {
        await pumpAt(tester, 1400);
        expect(find.text(todayLabel), findsOneWidget);
        expect(find.text('Attendance'), findsWidgets);
      });

      testWidgets('phone width stacks the header without overflowing',
          (tester) async {
        await pumpAt(tester, 390);
        expect(find.text(todayLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Live attendance parity features', () {
      testWidgets('KPI cards render a card for each status', (tester) async {
        final provider = AppProvider(autoLoad: false)
          ..seedForTest(staff: roster, attendance: register);
        await tester.pumpWidget(host(provider, const AttendanceScreen()));
        await tester.pump();

        expect(find.text('Half Day'), findsWidgets);
        expect(find.text('Not marked'), findsWidgets);
      });

      testWidgets('Mark all present saves straight away', (tester) async {
        final provider = AppProvider(autoLoad: false)
          ..seedForTest(staff: roster, attendance: []);
        await tester.pumpWidget(host(provider, const AttendanceScreen()));
        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Mark all present'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1)); // the request fails
        await tester.pumpAndSettle();

        expect(find.text('Could not mark everyone present'), findsOneWidget);
      });

      testWidgets('Day view shows the register and the month grid; Month view '
          'only the grid', (tester) async {
        final provider = AppProvider(autoLoad: false)
          ..seedForTest(staff: roster, attendance: register);
        await tester.pumpWidget(host(provider, const AttendanceScreen()));
        await tester.pump();

        expect(find.text('Note'), findsOneWidget); // register header
        expect(find.text('Totals flow into Payroll'), findsOneWidget);

        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();
        expect(find.text('Note'), findsNothing);
        expect(find.text('Totals flow into Payroll'), findsOneWidget);

        await tester.tap(find.text('Day'));
        await tester.pumpAndSettle();
        expect(find.text('Note'), findsOneWidget);
      });

      testWidgets('the month grid steps months back and forward',
          (tester) async {
        final provider = AppProvider(autoLoad: false)
          ..seedForTest(staff: roster, attendance: register);
        await tester.pumpWidget(host(provider, const AttendanceScreen()));
        await tester.pump();

        // "September" in the current year, "December 2025" otherwise.
        String label(DateTime m) => m.year == DateTime.now().year
            ? DateFormat('MMMM').format(m)
            : DateFormat('MMMM yyyy').format(m);
        final now = DateTime.now();
        final current = DateTime(now.year, now.month);
        final previous = DateTime(now.year, now.month - 1);

        expect(find.text(label(current)), findsOneWidget);
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
        expect(find.text(label(previous)), findsOneWidget);
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
        expect(find.text(label(current)), findsOneWidget);
      });

      testWidgets('toggling Habits switches view to Attendance Habit Tracker & Streaks', (tester) async {
        final provider = AppProvider(autoLoad: false)
          ..seedForTest(staff: roster, attendance: register);
        await tester.pumpWidget(host(provider, const AttendanceScreen()));
        await tester.pump();

        expect(find.text('Attendance Habit Tracker & Streaks'), findsNothing);

        await tester.tap(find.text('Habits'));
        await tester.pumpAndSettle();

        expect(find.text('Attendance Habit Tracker & Streaks'), findsOneWidget);
        expect(find.text('Current Streak'), findsOneWidget);
        expect(find.text('Best Streak'), findsOneWidget);
        expect(find.text('Total Check-ins'), findsOneWidget);
        expect(find.text('Monthly Consistency'), findsOneWidget);
        expect(find.text('Staff Attendance Streak Leaderboard'), findsOneWidget);
      });
    });
  });

  group('AppProvider attendance', () {
    test('attendanceFor returns only the requested day', () {
      final yesterday = today.subtract(const Duration(days: 1));
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(attendance: [
          ...register,
          AttendanceModel(
              id: '12', staffId: '1', staffName: 'Ramesh Kumar', date: yesterday, status: 'ABSENT'),
        ]);

      expect(provider.attendanceFor(today), {'1': 'HALF_DAY', '2': 'LEAVE'});
      expect(provider.attendanceFor(yesterday), {'1': 'ABSENT'});
    });

    test('a day with no register is an empty map, not a defaulted one', () {
      final provider = AppProvider(autoLoad: false)..seedForTest(attendance: register);
      expect(provider.attendanceFor(DateTime(2020, 1, 1)), isEmpty);
    });

    test('dateKey zero-pads to the shape Django parses', () {
      expect(AppProvider.dateKey(DateTime(2026, 8, 1)), '2026-08-01');
      expect(AppProvider.dateKey(DateTime(2026, 12, 25)), '2026-12-25');
    });
  });
}
