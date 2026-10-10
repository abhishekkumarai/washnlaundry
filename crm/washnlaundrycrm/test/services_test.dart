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
    'is_active': true,
  }),
  GarmentItemModel.fromJson({
    'id': 2,
    'category': 1,
    'category_name': 'Ironing',
    'name': 'Regular Cloths',
    'price': 85.0,
    'unit': 'KG',
    'is_active': true,
  }),
  GarmentItemModel.fromJson({
    'id': 3,
    'category': 1,
    'category_name': 'Ironing',
    'name': 'Retired Item',
    'price': 250.0,
    'unit': 'SET',
    'is_active': false,
  }),
  GarmentItemModel.fromJson({
    'id': 4,
    'category': 1,
    'category_name': 'Ironing',
    'name': 'Sofa Cover',
    'price': 300.0,
    'unit': 'SET',
    'is_active': true,
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

      // The card used to hardcode "/ pc" and "Per piece" for every row.
      expect(find.text(' / pc'), findsWidgets);
      expect(find.text(' / kg'), findsOneWidget);
      // Two SET items: Sofa Cover, and the inactive Retired Item (still listed).
      expect(find.text(' / set'), findsNWidgets(2));
      expect(find.text('Per kg'), findsOneWidget);
    });

    testWidgets('inactive items stay listed, marked off, so they can be re-enabled',
        (tester) async {
      // Hiding them made a switched-off item vanish from the only screen that
      // can switch it back on.
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();

      expect(find.text('Retired Item'), findsOneWidget);
      expect(find.text('Items (4) · 1 inactive'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      // One switch per item, and exactly the retired one is off.
      final switches =
          tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value);
      expect(switches.where((on) => !on).length, 1);
      expect(switches.where((on) => on).length, 3);
    });

    testWidgets('with every item active the header shows no inactive note',
        (tester) async {
      final active = _catalogue.where((g) => g.isActive).toList();
      await tester.pumpWidget(
          host(_seeded(garments: active), const ServicesScreen()));
      await tester.pump();

      expect(find.text('Items (3)'), findsOneWidget);
      expect(find.text('Off'), findsNothing);
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

      // Category header edit action via 3-dots menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit category'));
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

      // Shirt is the first row in the items table
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Service / Item'), findsOneWidget);
      expect(find.text('Shirt'), findsWidgets); // prefilled name field
      expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save Changes'), findsOneWidget);
    });

    testWidgets('redundant edit icon is removed from category header and item cards (KAN-154)',
        (tester) async {
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();

      // Category header has no standalone edit icon tooltip, only 3-dots menu
      expect(find.byTooltip('Edit Category'), findsNothing);
      expect(find.byTooltip('More actions'), findsOneWidget);

      // Verify item card in grid view has only 3-dots menu and no redundant edit button
      tester.view.physicalSize = const Size(800, 1200);
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert_rounded), findsWidgets);
      // Tap 3-dots menu on first item card and verify Edit item is available
      await tester.tap(find.byIcon(Icons.more_vert_rounded).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Edit item'), findsOneWidget);
      await tester.tap(find.text('Edit item'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Service / Item'), findsOneWidget);
    });
  });

  group('ServicesScreen Add Item', () {
    Future<void> openModal(WidgetTester tester) async {
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens with the live defaults', (tester) async {
      await openModal(tester);

      expect(find.text('Add New Service / Garment Item'), findsOneWidget);
      // Category preselected, unit defaulted — not blank.
      expect(find.text('Per piece'), findsWidgets);
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

    testWidgets('offers no icon picker and no Turnaround Days field',
        (tester) async {
      // No icon picker — icon is chosen from a fixed set keyed by category
      // name. Turnaround Days was removed from the model entirely at the
      // user's request, so it must not appear here either.
      await tester.pumpWidget(host(_seeded(), const ServicesScreen()));
      await tester.pump();

      await tester.tap(find.text('New service category'));
      await tester.pumpAndSettle();

      expect(find.text('Service Icon'), findsNothing);
      expect(find.text('Turnaround Days'), findsNothing);
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

    testWidgets('shows the category rail at wide width', (tester) async {
      await pumpAt(tester, 1900);

      expect(find.text('SERVICE CATEGORIES'), findsOneWidget);
    });

    testWidgets('collapses the category rail to chips at phone width',
        (tester) async {
      await pumpAt(tester, 390);

      expect(find.text('SERVICE CATEGORIES'), findsNothing);
      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('Ironing'), findsWidgets);
    });

    testWidgets('has no Items/Service Areas/Pickup/Delivery tab bar',
        (tester) async {
      await pumpAt(tester, 390);

      expect(find.text('Service Areas'), findsNothing);
      expect(find.text('Pickup'), findsNothing);
      expect(find.text('Delivery'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
