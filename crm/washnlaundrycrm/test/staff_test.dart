import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/staff_screen.dart';

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

  final roster = [
    const StaffModel(id: '1', name: 'Ramesh Kumar', role: 'Head Washer', phone: '9876543210'),
    StaffModel(
      id: '2',
      name: 'Geeta Devi',
      role: 'Dry Cleaning',
      phone: '9876543211',
      startDate: DateTime(2026, 3, 1),
    ),
  ];

  group('StaffScreen Start Date', () {
    testWidgets('Add Staff Member defaults Start Date to today', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Staff').first);
      await tester.pumpAndSettle();

      expect(find.text('Add Staff Member'), findsOneWidget);
      expect(
        find.text(DateFormat('d MMM yyyy').format(DateTime.now())),
        findsOneWidget,
      );
    });

    testWidgets('Edit Staff Member shows Not set for a staff member with no start date',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      // Ramesh Kumar (id 1) has no startDate in the fixture above.
      await tester.tap(find.text('Ramesh Kumar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Staff Member'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('Edit Staff Member shows an existing start date, not Not set',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.text('Geeta Devi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details').first);
      await tester.pumpAndSettle();

      expect(find.text('1 Mar 2026'), findsOneWidget);
      expect(find.text('Not set'), findsNothing);
    });

    testWidgets('the clear button resets an existing start date to Not set',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.text('Geeta Devi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details').first);
      await tester.pumpAndSettle();
      expect(find.text('1 Mar 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear start date'));
      await tester.pumpAndSettle();

      expect(find.text('Not set'), findsOneWidget);
      expect(find.text('1 Mar 2026'), findsNothing);
      // The clear button itself disappears once there's nothing to clear.
      expect(find.byTooltip('Clear start date'), findsNothing);
    });
  });

  group('StaffScreen save errors', () {
    testWidgets(
        'a failed save shows a popup and keeps the dialog open, not a lost edit',
        (tester) async {
      // Used to Navigator.pop the dialog unconditionally before checking
      // whether the save actually succeeded — a failure closed the form,
      // discarding everything typed, with only a SnackBar (easy to miss,
      // and gone with the dialog) explaining why.
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.text('Ramesh Kumar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pump(); // start the save
      await tester.pump(const Duration(seconds: 1)); // let it fail (no server)

      expect(find.text('Could not save "Ramesh Kumar"'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNWidgets(2));
      // The Edit dialog itself is still there, behind the error popup.
      expect(find.text('Edit Staff Member'), findsOneWidget);
    });
  });

  group('StaffScreen Status & Subtabs', () {
    final mixedRoster = [
      const StaffModel(
        id: '1',
        name: 'Ramesh Kumar',
        role: 'Head Washer',
        phone: '9876543210',
        status: 'INACTIVE',
      ),
      const StaffModel(
        id: '2',
        name: 'Geeta Devi',
        role: 'Dry Cleaning',
        phone: '9876543211',
        status: 'ACTIVE',
      ),
    ];

    testWidgets('All Staff tab shows both active and inactive members',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: mixedRoster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      // "All Staff" tab is selected by default and should list both
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Geeta Devi'), findsOneWidget);
    });

    testWidgets('Active and Inactive subtabs filter staff appropriately',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: mixedRoster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      // Tap Active tab
      await tester.tap(find.byKey(const ValueKey('staff-subtab-Active')));
      await tester.pumpAndSettle();
      expect(find.text('Geeta Devi'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsNothing);

      // Tap Inactive tab
      await tester.tap(find.byKey(const ValueKey('staff-subtab-Inactive')));
      await tester.pumpAndSettle();
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Geeta Devi'), findsNothing);
    });

    testWidgets('Staff modal has no Status section (status is toggled from the list)',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: mixedRoster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Staff').first);
      await tester.pumpAndSettle();

      expect(find.text('Add Staff Member'), findsOneWidget);
      final dialogFinder = find.byType(AlertDialog);
      expect(find.descendant(of: dialogFinder, matching: find.text('Status')), findsNothing);
      expect(find.descendant(of: dialogFinder, matching: find.text('1. Active')), findsNothing);
      expect(find.descendant(of: dialogFinder, matching: find.byIcon(Icons.radio_button_checked)), findsNothing);
    });

    testWidgets('Status column in staff table renders an on/off switch per member',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: mixedRoster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      // One switch per row: Geeta is on (Active), Ramesh is off (Inactive).
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(2));
      expect(switches.where((s) => s.value), hasLength(1));
      expect(switches.where((s) => !s.value), hasLength(1));
      expect(switches.every((s) => s.onChanged != null), isTrue);
      // The old two-chip radio is gone from the table.
      expect(find.text('1. Active'), findsNothing);
      expect(find.text('2. Inactive'), findsNothing);
    });
  });

  group('StaffScreen table sorting', () {
    // Wages chosen so string order ('9000' > '18000') and numeric order
    // disagree — a text sort on wage would fail here.
    const sortRoster = [
      StaffModel(id: '1', name: 'Mohan', role: 'Washer', phone: '3',
          monthlyWage: 18000),
      StaffModel(id: '2', name: 'anita', role: 'Ironer', phone: '1',
          monthlyWage: 9000, status: 'INACTIVE'),
      StaffModel(id: '3', name: 'Geeta', role: 'Driver', phone: '2',
          monthlyWage: 12000),
    ];

    List<String> rowOrder(WidgetTester tester) {
      final names = ['Mohan', 'anita', 'Geeta'];
      final ys = {
        for (final n in names) n: tester.getTopLeft(find.text(n)).dy,
      };
      return names..sort((a, b) => ys[a]!.compareTo(ys[b]!));
    }

    Future<void> pump(WidgetTester tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: sortRoster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();
    }

    testWidgets('keeps the backend order until a header is tapped',
        (tester) async {
      await pump(tester);
      expect(rowOrder(tester), ['Mohan', 'anita', 'Geeta']);
    });

    testWidgets('name sorts case-insensitively; a second tap reverses',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('staff-sort-name')));
      await tester.pump();
      expect(rowOrder(tester), ['anita', 'Geeta', 'Mohan']);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('staff-sort-name')));
      await tester.pump();
      expect(rowOrder(tester), ['Mohan', 'Geeta', 'anita']);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('wage sorts numerically, not as text', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('staff-sort-wage')));
      await tester.pump();
      expect(rowOrder(tester), ['anita', 'Geeta', 'Mohan']);
    });

    testWidgets('status groups active before inactive, ties by name',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('staff-sort-status')));
      await tester.pump();
      expect(rowOrder(tester), ['Geeta', 'Mohan', 'anita']);
    });
  });

  group('StaffScreen detail page', () {
    testWidgets('tapping a row opens that staff page with profile and actions',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.text('Geeta Devi'));
      await tester.pumpAndSettle();

      expect(find.text('Back to Staff'), findsOneWidget);
      expect(find.text('Edit details'), findsOneWidget);
      expect(find.text('Mark inactive'), findsOneWidget);
      expect(find.text('Enable sign-in'), findsOneWidget);
      // No Edit modal opened by the tap itself.
      expect(find.text('Edit Staff Member'), findsNothing);
    });

    testWidgets('back returns to the roster', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.text('Geeta Devi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staffDetailBack')));
      await tester.pumpAndSettle();

      expect(find.text('Back to Staff'), findsNothing);
      expect(find.text('Ramesh Kumar'), findsWidgets);
    });
  });
}
