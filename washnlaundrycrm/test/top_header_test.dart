import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/widgets/top_header.dart';

/// `TopHeader` is shared by Dashboard, Payroll, and Expenses. This pins its
/// New Order button collapsing to icon-only below
/// `SidebarNavigation.contentWideBreakpoint`, the same idiom Orders and
/// Customer Detail already use for their own copy of this button.
void main() {
  Future<void> pumpAt(WidgetTester tester, double width,
      {required VoidCallback onNewOrderPressed}) async {
    tester.view
      ..physicalSize = Size(width, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TopHeader(title: 'Dashboard', onNewOrderPressed: onNewOrderPressed),
      ),
    ));
  }

  testWidgets('shows the labeled button at desktop width', (tester) async {
    var pressed = false;
    await pumpAt(tester, 1400, onNewOrderPressed: () => pressed = true);

    expect(find.text('New Order'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    expect(pressed, isTrue);
  });

  testWidgets('collapses to an icon-only button below the content breakpoint',
      (tester) async {
    var pressed = false;
    await pumpAt(tester, 600, onNewOrderPressed: () => pressed = true);

    expect(find.text('New Order'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byTooltip('New Order'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    expect(pressed, isTrue);
  });
}
