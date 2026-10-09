import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/settings_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

void main() {
  const categories = [
    CreditCategoryModel(id: '1', name: 'Laundry Income', creditCount: 3),
    CreditCategoryModel(id: '2', name: 'Delivery Charges'),
    CreditCategoryModel(id: '3', name: 'Other', isActive: false),
  ];

  AppProvider seeded() =>
      AppProvider(autoLoad: false)..seedForTest(creditCategories: categories);

  void setWidth(WidgetTester tester, double width) {
    tester.view
      ..physicalSize = Size(width, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('SettingsScreen tabs (desktop, 1400px)', () {
    testWidgets('lists Credit categories in the vertical tab list',
        (tester) async {
      setWidth(tester, 1400);
      await tester.pumpWidget(host(seeded(), const SettingsScreen()));
      await tester.pump();

      expect(find.byKey(const ValueKey('settings-tab-credit-categories')),
          findsOneWidget);
      // Opens on Business profile, which is the only tab with a Save button.
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-chip-credit-categories')),
          findsNothing);
    });

    testWidgets('Credit categories tab shows the list, add field and switches',
        (tester) async {
      setWidth(tester, 1400);
      await tester.pumpWidget(host(seeded(), const SettingsScreen()));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('settings-tab-credit-categories')));
      await tester.pumpAndSettle();

      expect(find.text('Laundry Income'), findsOneWidget);
      expect(find.text('Delivery Charges'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.byKey(const ValueKey('credit-category-add-field')),
          findsOneWidget);
      // Each change saves on its own — no page-level Save here.
      expect(find.text('Save changes'), findsNothing);

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(3));
      expect(switches.where((s) => !s.value), hasLength(1));
    });

    testWidgets('a category in use cannot be deleted, an unused one can',
        (tester) async {
      setWidth(tester, 1400);
      await tester.pumpWidget(host(
          seeded(), const SettingsScreen(initialTab: 'credit-categories')));
      await tester.pump();

      IconButton deleteIn(String id) => tester.widget<IconButton>(find.descendant(
          of: find.byKey(ValueKey('credit-category-$id')),
          matching: find.widgetWithIcon(IconButton, Icons.delete_outline)));

      expect(find.text('3 credits'), findsOneWidget);
      expect(deleteIn('1').onPressed, isNull);
      expect(deleteIn('1').tooltip, 'In use — turn it off instead');
      expect(deleteIn('2').onPressed, isNotNull);
    });

    testWidgets('initialTab opens straight on Credit categories',
        (tester) async {
      setWidth(tester, 1400);
      await tester.pumpWidget(host(
          seeded(), const SettingsScreen(initialTab: 'credit-categories')));
      await tester.pump();

      expect(find.byKey(const ValueKey('credit-category-add-field')),
          findsOneWidget);
    });

    testWidgets('an unknown initialTab falls back to Business profile',
        (tester) async {
      setWidth(tester, 1400);
      await tester.pumpWidget(
          host(seeded(), const SettingsScreen(initialTab: 'nope')));
      await tester.pump();

      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('unbuilt tabs say so instead of showing the profile form',
        (tester) async {
      setWidth(tester, 1400);
      await tester.pumpWidget(host(seeded(), const SettingsScreen()));
      await tester.pump();

      expect(find.byKey(const ValueKey('settings-tab-tax-currency')), findsNothing);
      expect(find.byKey(const ValueKey('settings-tab-bank-details')), findsNothing);
      expect(find.byKey(const ValueKey('settings-tab-operations')), findsNothing);
      expect(find.byKey(const ValueKey('settings-tab-preferences')), findsNothing);
      expect(find.byKey(const ValueKey('settings-tab-subscription')), findsNothing);
      expect(find.byKey(const ValueKey('settings-tab-payment-history')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('settings-tab-help')));
      await tester.pumpAndSettle();

      expect(find.text('Not available yet.'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('Store Location'), findsNothing);
    });
  });

  group('SettingsScreen tabs (phone, 600px)', () {
    testWidgets('the tab column becomes a chip row', (tester) async {
      setWidth(tester, 600);
      await tester.pumpWidget(host(seeded(), const SettingsScreen()));
      await tester.pump();

      expect(find.byKey(const ValueKey('settings-tab-credit-categories')),
          findsNothing);

      final chip =
          find.byKey(const ValueKey('settings-chip-credit-categories'));
      // The chip row builds lazily, so scroll it into existence first.
      await tester.dragUntilVisible(
          chip, find.byType(ListView).first, const Offset(-200, 0));
      // dragUntilVisible stops at the first sliver of the chip; bring all of
      // it on screen so the tap lands on it.
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);

      expect(find.byKey(const ValueKey('credit-category-add-field')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
