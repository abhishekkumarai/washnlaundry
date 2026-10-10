import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/widgets/shop_switch_modal.dart';

void main() {
  group('shopAvatarLetters', () {
    test('null or whitespace returns ?', () {
      expect(shopAvatarLetters(null), '?');
      expect(shopAvatarLetters(''), '?');
      expect(shopAvatarLetters('   '), '?');
    });

    test('single character names return the uppercase character', () {
      expect(shopAvatarLetters('a'), 'A');
      expect(shopAvatarLetters('s'), 'S');
    });

    test('two letter names return both uppercase characters', () {
      expect(shopAvatarLetters('AK'), 'AK');
      expect(shopAvatarLetters('ok'), 'OK');
    });

    test('long names return strictly the first two letters', () {
      expect(shopAvatarLetters('WashNLaundry'), 'WA');
      expect(shopAvatarLetters('Downtown Cleaners'), 'DO');
      expect(shopAvatarLetters('Express Dry Cleaning'), 'EX');
      expect(shopAvatarLetters('Laundromat'), 'LA');
    });

    test('names with special characters and symbols extract the first two alphanumeric letters', () {
      expect(shopAvatarLetters('A & B'), 'AB');
      expect(shopAvatarLetters('Wash & Fold'), 'WA');
      expect(shopAvatarLetters('Quick-Clean'), 'QU');
    });

    test('pure symbols fall back to first two characters', () {
      expect(shopAvatarLetters('!@#'), '!@');
      expect(shopAvatarLetters('!'), '!');
    });
  });

  testWidgets('showShopSwitchModalSheet renders two-letter avatars for listed shops',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appProvider = AppProvider();
    appProvider.setAvailableShops([
      {
        'id': 1,
        'name': 'WashNLaundry Main',
        'slug': 'washnlaundry-main',
        'email': 'main@washnlaundry.com',
      },
      {
        'id': 2,
        'name': 'Downtown Express',
        'slug': 'downtown-express',
        'email': 'downtown@washnlaundry.com',
      },
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showShopSwitchModalSheet(context),
                child: const Text('Open Switch Modal'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open the switch modal
    await tester.tap(find.text('Open Switch Modal'));
    await tester.pumpAndSettle();

    // Verify modal header
    expect(find.text('Switch Account'), findsOneWidget);

    // Verify shop names
    expect(find.text('WashNLaundry Main'), findsOneWidget);
    expect(find.text('Downtown Express'), findsOneWidget);

    // Verify avatar displays ONLY the first two letters
    expect(find.text('WA'), findsOneWidget);
    expect(find.text('DO'), findsOneWidget);

    // Assert long initials like 'WASHN' or 'DOWNT' are NOT present
    expect(find.text('WASHN'), findsNothing);
    expect(find.text('DOWNT'), findsNothing);

    // Tap the second shop to switch and dismiss modal
    await tester.tap(find.text('Downtown Express'));
    await tester.pumpAndSettle();

    // Modal should close
    expect(find.text('Switch Account'), findsNothing);
  });
}
