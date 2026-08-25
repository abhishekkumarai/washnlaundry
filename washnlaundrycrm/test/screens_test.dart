import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/settings_screen.dart';
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

  group('SettingsScreen', () {
    final shop = {
      'id': 1,
      'name': 'washing',
      'phone': '+91 98765 43210',
      'whatsapp': '+91 98765 43210',
      'email': 'hello@washing.example',
      'address': 'Hbr layout, Bengaluru',
      'city': 'Bengaluru',
      'state': 'Karnataka',
      'pin_code': '560064',
    };

    testWidgets('hydrates the form from the loaded shop', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(shop: shop);
      await tester.pumpWidget(host(provider, const SettingsScreen()));
      await tester.pump();

      // Values come from the record, not from hardcoded defaults.
      expect(find.widgetWithText(TextField, 'washing'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Bengaluru'), findsOneWidget);
      expect(find.widgetWithText(TextField, '560064'), findsOneWidget);
    });

    testWidgets('shows no shop details before one loads', (tester) async {
      final provider = AppProvider(autoLoad: false);
      await tester.pumpWidget(host(provider, const SettingsScreen()));
      await tester.pump();

      // The old screen shipped a real shop's name and email as defaults.
      expect(find.widgetWithText(TextField, 'washing'), findsNothing);
      expect(find.text('emailabhishek2@gmail.com'), findsNothing);
    });

    testWidgets('does not clobber edits when the provider notifies again',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(shop: shop);
      await tester.pumpWidget(host(provider, const SettingsScreen()));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'washing'),
        'Washing Express',
      );
      await tester.pump();

      provider.seedForTest(shop: shop); // same shop id — must not re-hydrate
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Washing Express'), findsOneWidget);
    });
  });

  group('StaffScreen', () {
    final roster = [
      const StaffModel(
        id: '1',
        name: 'Ramesh Kumar',
        role: 'Head Washer',
        phone: '9711223344',
        monthlyWage: 17000,
        hasAppLogin: true,
      ),
      const StaffModel(
        id: '2',
        name: 'Mohan Das',
        role: 'Delivery Driver',
        phone: '9933441122',
        monthlyWage: 15000,
        hasAppLogin: true,
      ),
    ];

    testWidgets('renders the roster from the provider', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Head Washer'), findsOneWidget);
      expect(find.text('Mohan Das'), findsOneWidget);
    });

    testWidgets('the row actions menu opens a prefilled edit dialog',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Staff Member'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Ramesh Kumar'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('the edit dialog offers an active toggle', (tester) async {
      // Without this, "Show Inactive" could never match anything.
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();

      expect(
        find.text('Active — uncheck to remove from the roster'),
        findsOneWidget,
      );
    });

    testWidgets('the add dialog has no active toggle', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.text('Add Staff').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Active — uncheck to remove from the roster'),
        findsNothing,
      );
    });

    testWidgets('inactive members are hidden until Show Inactive is ticked',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(staff: [
          ...roster,
          const StaffModel(
            id: '9',
            name: 'Retired Person',
            role: 'Washer',
            phone: '9000000000',
            status: 'INACTIVE',
          ),
        ]);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      expect(find.text('Retired Person'), findsNothing);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      expect(find.text('Retired Person'), findsOneWidget);
    });

    testWidgets('the add button opens an empty dialog', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(staff: roster);
      await tester.pumpWidget(host(provider, const StaffScreen()));
      await tester.pump();

      await tester.tap(find.text('Add Staff').first);
      await tester.pumpAndSettle();

      expect(find.text('Add Staff Member'), findsOneWidget);
      expect(find.text('Add Staff'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Ramesh Kumar'), findsNothing);
    });
  });
}
