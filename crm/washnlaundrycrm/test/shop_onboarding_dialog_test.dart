import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/widgets/shop_onboarding_dialog.dart';

void main() {
  testWidgets('ShopOnboardingDialog renders Cancel button and dismisses on tap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => const ShopOnboardingDialog(),
                );
                dismissed = true;
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );

    // Open the dialog
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Verify modal elements
    expect(find.text('Set up your store'), findsOneWidget);
    expect(find.text('Create Store & Launch CRM'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Tap Cancel button
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify dialog was dismissed
    expect(find.text('Set up your store'), findsNothing);
    expect(dismissed, isTrue);
  });

  testWidgets('ShopOnboardingDialog dismisses when close icon button is tapped',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => const ShopOnboardingDialog(),
                );
                dismissed = true;
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );

    // Open the dialog
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Tap Close icon button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify dialog was dismissed
    expect(find.text('Set up your store'), findsNothing);
    expect(dismissed, isTrue);
  });
}

