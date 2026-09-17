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
    const StaffModel(id: '1', name: 'Ramesh Kumar', role: 'Head Washer', phone: '1'),
    StaffModel(
      id: '2',
      name: 'Geeta Devi',
      role: 'Dry Cleaning',
      phone: '2',
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

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pump(); // start the save
      await tester.pump(const Duration(seconds: 1)); // let it fail (no server)

      expect(find.text('Could not save "Ramesh Kumar"'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNWidgets(2));
      // The Edit dialog itself is still there, behind the error popup.
      expect(find.text('Edit Staff Member'), findsOneWidget);
    });
  });
}
