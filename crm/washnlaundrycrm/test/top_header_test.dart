import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/widgets/top_header.dart';

/// `TopHeader` is shared by Dashboard, Payroll, and Expenses. This pins its
/// New Order button collapsing to icon-only below
/// `SidebarNavigation.contentWideBreakpoint`, the same idiom Orders and
/// Customer Detail already use for their own copy of this button.
void main() {
  Future<void> pumpAt(WidgetTester tester, double width,
      {required VoidCallback onActionPressed}) async {
    tester.view
      ..physicalSize = Size(width, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TopHeader(title: 'Dashboard', onActionPressed: onActionPressed),
      ),
    ));
  }

  testWidgets('shows the labeled button at desktop width', (tester) async {
    var pressed = false;
    await pumpAt(tester, 1400, onActionPressed: () => pressed = true);

    expect(find.text('New Order'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    expect(pressed, isTrue);
  });

  testWidgets('collapses to an icon-only button below the content breakpoint',
      (tester) async {
    var pressed = false;
    await pumpAt(tester, 600, onActionPressed: () => pressed = true);

    expect(find.text('New Order'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byTooltip('New Order'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    expect(pressed, isTrue);
  });

  testWidgets(
      'omits the action button entirely when onActionPressed is null',
      (tester) async {
    // Expenses' own body already has an "Add Expense" button — passing one
    // here too would just be a second control doing the same job.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TopHeader(title: 'Expenses')),
    ));

    expect(find.text('New Order'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
  });

  testWidgets('does not render a dead help icon in the header', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TopHeader(title: 'Dashboard')),
    ));
    expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
    expect(find.byTooltip('Help'), findsNothing);
  });
}
