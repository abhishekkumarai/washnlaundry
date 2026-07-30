import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/widgets/sidebar_navigation.dart';

Widget wrap(AppProvider provider, Widget child) {
  return ChangeNotifierProvider<AppProvider>.value(
    value: provider,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  // The rail has 14 items; the default 800x600 test surface cuts off the last
  // few, so give it a desktop-height viewport.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!;
    view.physicalSize = const Size(1200, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('sidebar renders the navigation items', (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(wrap(provider, const SidebarNavigation()));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('New Order'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tapping a nav item changes the selected index', (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(wrap(provider, const SidebarNavigation()));

    expect(provider.currentNavIndex, 0);
    await tester.tap(find.text('Orders'));
    await tester.pump();

    expect(provider.currentNavIndex, 2);
  });

  testWidgets('Settings is reachable now that it is wired up', (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(wrap(provider, const SidebarNavigation()));

    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(provider.currentNavIndex, 13);
  });

  testWidgets('disabled items are inert and marked Soon', (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(wrap(provider, const SidebarNavigation()));

    expect(find.text('Soon'), findsWidgets);

    await tester.tap(find.text('Apps'));
    await tester.pump();

    expect(provider.currentNavIndex, 0);
  });
}
