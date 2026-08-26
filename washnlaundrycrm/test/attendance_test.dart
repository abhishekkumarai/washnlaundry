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

  group('AttendanceScreen', () {
    testWidgets('the roster comes from the provider, not a literal', (tester) async {
      // The screen used to hardcode six staff, none of whom were the seeded
      // roster — 'Mohan Das' and 'Anita Sharma' were pure invention.
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Geeta Devi'), findsOneWidget);
      expect(find.text('Mohan Das'), findsNothing);
      expect(find.text('Anita Sharma'), findsNothing);
    });

    testWidgets('inactive staff are not on the register', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.text('Bhola Prasad'), findsNothing);
    });

    testWidgets('saved marks are reflected as selected chips', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: roster, attendance: register);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      final halfDay = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'HALF DAY').first,
      );
      expect(halfDay.selected, isTrue);

      final leave = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'LEAVE').at(1),
      );
      expect(leave.selected, isTrue);
    });

    testWidgets('LEAVE is offered, not just the old three statuses', (tester) async {
      // The backend has always stored LEAVE and the dashboard counts it, but
      // the chip row only ever offered PRESENT / HALF_DAY / ABSENT.
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.widgetWithText(ChoiceChip, 'PRESENT'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'HALF DAY'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'ABSENT'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'LEAVE'), findsOneWidget);
    });

    testWidgets('an unmarked staff member says so', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first], attendance: []);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      // "not marked" is a different state from ABSENT and must read that way.
      expect(find.text('Head Washer • not marked'), findsOneWidget);
    });

    testWidgets('tapping a chip selects it', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first], attendance: []);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(ChoiceChip, 'ABSENT'));
      await tester.pump();

      final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'ABSENT'));
      expect(chip.selected, isTrue);
    });

    testWidgets('a failed save reports the error instead of claiming success',
        (tester) async {
      // The old Save Register showed a green "saved successfully" snackbar
      // unconditionally, without making any network call at all.
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: [roster.first]);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      await tester.tap(find.text('Save Register'));
      await tester.pump(); // start the save
      await tester.pump(const Duration(seconds: 1)); // let it fail

      expect(find.text('Attendance saved successfully'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('saving an untouched register marks nobody present',
        (tester) async {
      // Save used to send `_pending[id] ?? saved[id] ?? 'PRESENT'` for the
      // whole roster, so pressing it without marking anyone invented a *paid*
      // day for every staff member — contradicting the "not marked is not
      // ABSENT" care this screen takes everywhere else.
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first], attendance: []);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      await tester.tap(find.text('Save Register'));
      await tester.pump();

      expect(find.text('Nothing to save — mark at least one staff member.'),
          findsOneWidget);
      // Still "not marked" afterwards — saving did not quietly fill it in.
      expect(find.text('Head Washer • not marked'), findsOneWidget);
    });

    testWidgets('saving sends the staff who were marked', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [roster.first], attendance: []);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(ChoiceChip, 'ABSENT'));
      await tester.pump();
      await tester.tap(find.text('Save Register'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // It got as far as the network (which fails in tests) rather than
      // stopping at "nothing to save".
      expect(find.text('Nothing to save — mark at least one staff member.'),
          findsNothing);
    });

    testWidgets('an empty roster says so and disables saving', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: []);
      await tester.pumpWidget(host(provider, const AttendanceScreen()));
      await tester.pump();

      expect(find.text('No active staff to mark.'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save Register'),
      );
      expect(button.onPressed, isNull);
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

      testWidgets('shows the full date on the picker button at wide width',
          (tester) async {
        await pumpAt(tester, 1400);

        final formatted =
            DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());
        expect(find.text(formatted), findsOneWidget);
      });

      testWidgets(
          'shortens the date button and stacks it below the title at phone '
          'width', (tester) async {
        await pumpAt(tester, 390);

        final full = DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());
        final short = DateFormat('d MMM yyyy').format(DateTime.now());
        expect(find.text(full), findsNothing);
        expect(find.text(short), findsOneWidget);
        expect(tester.takeException(), isNull);
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
