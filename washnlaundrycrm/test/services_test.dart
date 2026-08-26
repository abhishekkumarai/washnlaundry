import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/services_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

/// One category with three items covering three different pricing units, so a
/// per-piece assumption anywhere in the item card shows up as a failure.
final _ironing = GarmentCategoryModel.fromJson({
  'id': 1,
  'name': 'Ironing',
  'icon': 'Iron',
  'display_order': 1,
  'item_count': 3,
  'price_range': {'min': 15, 'max': 250},
});

final _catalogue = [
  GarmentItemModel.fromJson({
    'id': 1,
    'category': 1,
    'category_name': 'Ironing',
    'name': 'Shirt',
    'price': 15.0,
    'unit': 'PC',
    'turnaround_days': 1,
    'is_active': true,
  }),
  GarmentItemModel.fromJson({
    'id': 2,
    'category': 1,
    'category_name': 'Ironing',
    'name': 'Regular Cloths',
    'price': 85.0,
    'unit': 'KG',
    'turnaround_days': 2,
    'is_active': true,
  }),
  GarmentItemModel.fromJson({
    'id': 3,
    'category': 1,
    'category_name': 'Ironing',
    'name': 'Retired Item',
    'price': 250.0,
    'unit': 'SET',
    'turnaround_days': 1,
    'is_active': false,
  }),
];

AppProvider _seeded({
  List<GarmentCategoryModel>? categories,
  List<GarmentItemModel>? garments,
  List<ServiceAreaModel>? serviceAreas,
  List<TimeSlotModel>? pickupSlots,
}) =>
    AppProvider(autoLoad: false)
      ..seedForTest(
        categories: categories ?? [_ironing],
        garments: garments ?? _catalogue,
        serviceAreas: serviceAreas ?? const [],
        pickupSlots: pickupSlots ?? const [],
        deliverySlots: const [],
      );

/// Moves to one of the four tabs by tapping its pill.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

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

  group('ServicesScreen items', () {
    testWidgets('price tags and chips use each item own unit', (tester) async {
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();
      // Retired Item (the 'set'-unit row) is inactive and hidden by default.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // The card used to hardcode "/ pc" and "Per piece" for every row.
      expect(find.text(' / pc'), findsWidgets);
      expect(find.text(' / kg'), findsOneWidget);
      expect(find.text(' / set'), findsOneWidget);
      expect(find.text('Per kg'), findsOneWidget);
    });

    testWidgets('inactive items are hidden until Show Inactive is ticked',
        (tester) async {
      // Both the item-level filter and the "Show Inactive" checkbox used to
      // do nothing — every item showed regardless, so there was no way to
      // actually confirm disabling one had any visible effect.
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();

      expect(find.text('Retired Item'), findsNothing);
      expect(find.text('Inactive'), findsNothing);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(find.text('Retired Item'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      // Two active item badges, plus the category header's own Active pill.
      expect(find.text('Active'), findsNWidgets(3));
    });

    testWidgets('an inactive category reads Inactive, not a hardcoded Active',
        (tester) async {
      // The sidebar dot and the category header's pill were both hardcoded
      // green/"Active" regardless of the category's real `is_active` flag.
      final retired = GarmentCategoryModel.fromJson({
        'id': 2,
        'name': 'Retired Category',
        'icon': 'Home',
        'display_order': 2,
        'item_count': 0,
        'price_range': {'min': 0, 'max': 0},
        'is_active': false,
      });
      await tester.pumpWidget(host(
        _seeded(categories: [_ironing, retired]),
        const ServicesScreen(),
      ));
      await tester.pump();

      // Ironing (active, selected by default) shows Active; nothing reads
      // Inactive yet.
      expect(find.text('Inactive'), findsNothing);

      await tester.tap(find.text('Retired Category'));
      await tester.pumpAndSettle();

      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('editing an already-inactive category keeps Status Inactive',
        (tester) async {
      // The Edit dialog's Status switch was hardcoded to start Active no
      // matter what — saving any edit to an inactive category (even just
      // its name) silently reactivated it.
      final retired = GarmentCategoryModel.fromJson({
        'id': 2,
        'name': 'Retired Category',
        'icon': 'Home',
        'display_order': 1,
        'item_count': 0,
        'price_range': {'min': 0, 'max': 0},
        'is_active': false,
      });
      await tester.pumpWidget(host(
        _seeded(categories: [retired], garments: const []),
        const ServicesScreen(),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Service'), findsOneWidget);
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isFalse);
    });

    testWidgets('an empty catalogue offers a category instead of crashing',
        (tester) async {
      await tester.pumpWidget(
        host(_seeded(categories: const [], garments: const []), const ServicesScreen()),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('No services'), findsOneWidget);
      expect(find.text('New service category'), findsOneWidget);
    });

    testWidgets('Edit Service / Item opens without crashing', (tester) async {
      // A bare `Spacer()` in this dialog's `actions` used to throw at layout
      // time — `AlertDialog.actions` lays out through an `OverflowBar`,
      // which doesn't support flex children. Release builds showed a blank
      // grey box where the whole form should be, with no visible error.
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();

      // Index 0 is the category header's own edit pencil ("Edit Service");
      // index 1 is Shirt's, the first item card.
      await tester.tap(find.byIcon(Icons.edit_outlined).at(1));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Service / Item'), findsOneWidget);
      expect(find.text('Shirt'), findsWidgets); // prefilled name field
      expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save Changes'), findsOneWidget);
    });
  });

  group('ServicesScreen Add Item', () {
    Future<void> openModal(WidgetTester tester) async {
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();
      await tester.tap(find.text('+ New Service'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens with the live defaults', (tester) async {
      await openModal(tester);

      expect(find.text('Add New Service / Garment Item'), findsOneWidget);
      // Category preselected, unit and turnaround defaulted — not blank.
      expect(find.text('Per piece'), findsWidgets);
      expect(find.text('1d'), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, 'Save Item'), findsOneWidget);
    });

    testWidgets('refuses a blank name and a bad price, and stays open',
        (tester) async {
      await openModal(tester);
      await tester.enterText(find.widgetWithText(TextField, 'e.g. 150'), 'abc');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Item'));
      await tester.pumpAndSettle();

      expect(find.text('Item name is required'), findsOneWidget);
      expect(find.text('Enter a valid price'), findsOneWidget);
      // The old modal silently no-opped; the dialog must survive to be fixed.
      expect(find.text('Add New Service / Garment Item'), findsOneWidget);
    });

    testWidgets('a zero price is not a valid price', (tester) async {
      await openModal(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Jacket / Blazer'), 'Blazer');
      await tester.enterText(find.widgetWithText(TextField, 'e.g. 150'), '0');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Item'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid price'), findsOneWidget);
      expect(find.text('Item name is required'), findsNothing);
    });

    testWidgets('typing clears the error it fixed', (tester) async {
      await openModal(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Item'));
      await tester.pumpAndSettle();
      expect(find.text('Item name is required'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Jacket / Blazer'), 'Blazer');
      await tester.pumpAndSettle();
      expect(find.text('Item name is required'), findsNothing);
    });
  });

  group('ServicesScreen New Service category', () {
    testWidgets('the sidebar offers it and it validates the name',
        (tester) async {
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();

      await tester.tap(find.text('New service category'));
      await tester.pumpAndSettle();
      expect(find.text('Add Service'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Service'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a service name.'), findsOneWidget);
    });

    testWidgets('offers Turnaround Days, not the icon picker the live app lacks',
        (tester) async {
      // The live app's Add Service modal is Name / Active / Turnaround Days —
      // no icon picker. Ours used to offer one instead of Turnaround Days.
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();

      await tester.tap(find.text('New service category'));
      await tester.pumpAndSettle();

      expect(find.text('Turnaround Days'), findsOneWidget);
      expect(find.text('Service Icon'), findsNothing);
    });
  });

  group('ServicesScreen service areas', () {
    testWidgets('renders the areas the backend returned', (tester) async {
      final provider = _seeded(serviceAreas: [
        ServiceAreaModel.fromJson({'id': 1, 'name': 'HBR Layout'}),
        ServiceAreaModel.fromJson({'id': 2, 'name': 'Banaswadi'}),
      ]);
      await tester.pumpWidget(host(provider, const ServicesScreen()));
      await tester.pump();
      await openTab(tester, 'Service Areas');

      // These used to be a local list that started empty regardless of the API.
      expect(find.text('HBR Layout'), findsOneWidget);
      expect(find.text('Banaswadi'), findsOneWidget);
      expect(find.text('No areas added yet'), findsNothing);
    });

    testWidgets('a duplicate area is rejected without a request',
        (tester) async {
      final provider = _seeded(serviceAreas: [
        ServiceAreaModel.fromJson({'id': 1, 'name': 'HBR Layout'}),
      ]);
      await tester.pumpWidget(host(provider, const ServicesScreen()));
      await tester.pump();
      await openTab(tester, 'Service Areas');

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter area name'), 'hbr layout');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump();

      expect(find.text('"hbr layout" is already a service area'), findsOneWidget);
    });

    testWidgets('an empty area name is rejected', (tester) async {
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();
      await openTab(tester, 'Service Areas');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump();

      expect(find.text('Enter an area name'), findsOneWidget);
    });
  });

  group('ServicesScreen time slots', () {
    final slots = [
      TimeSlotModel.fromJson({
        'id': 1,
        'kind': 'PICKUP',
        'start_time': '09:00:00',
        'end_time': '11:00:00',
        'capacity': null,
        'is_active': true,
      }),
      TimeSlotModel.fromJson({
        'id': 2,
        'kind': 'PICKUP',
        'start_time': '14:00:00',
        'end_time': '16:00:00',
        'capacity': 20,
        'is_active': false,
      }),
    ];

    testWidgets('renders the slots the backend returned', (tester) async {
      await tester.pumpWidget(
          host(_seeded(pickupSlots: slots), const ServicesScreen()));
      await tester.pump();
      await openTab(tester, 'Pickup');

      expect(find.text('9:00 AM - 11:00 AM'), findsOneWidget);
      expect(find.text('2:00 PM - 4:00 PM'), findsOneWidget);
      // Once on the null-capacity row, once as the Capacity field's own hint.
      expect(find.text('Unlimited'), findsNWidgets(2));
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('an empty schedule says so instead of showing fake slots',
        (tester) async {
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();
      await openTab(tester, 'Pickup');

      // The screen used to ship four hardcoded slots on every account.
      expect(find.text('No time slots added yet'), findsOneWidget);
      expect(find.text('9:00 AM - 11:00 AM'), findsNothing);
    });

    testWidgets('saving without both times is rejected', (tester) async {
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();
      await openTab(tester, 'Pickup');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pump();

      expect(find.text('Pick a start and an end time'), findsOneWidget);
    });
  });

  group('ServicesScreen responsive layout', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view
        ..physicalSize = Size(width, 1200)
        ..devicePixelRatio = 1.0;
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();
    }

    testWidgets('shows the category rail and labeled New Service at wide width',
        (tester) async {
      await pumpAt(tester, 1900);

      expect(find.text('SERVICE CATEGORIES'), findsOneWidget);
      expect(find.text('+ New Service'), findsOneWidget);
    });

    testWidgets(
        'collapses the category rail to chips and New Service to an icon '
        'at phone width', (tester) async {
      await pumpAt(tester, 390);

      expect(find.text('SERVICE CATEGORIES'), findsNothing);
      expect(find.text('+ New Service'), findsNothing);
      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('Ironing'), findsWidgets);
    });

    testWidgets('the tab bar scrolls horizontally at phone width instead of '
        'overflowing', (tester) async {
      await pumpAt(tester, 390);

      expect(find.text('Items'), findsOneWidget);
      expect(find.text('Service Areas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
