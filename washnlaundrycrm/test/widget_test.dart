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

  Future<void> pumpAtWidth(WidgetTester tester, double width) async {
    final view = tester.view;
    view.physicalSize = Size(width, 1400);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      wrap(AppProvider(autoLoad: false), const SidebarNavigation()),
    );
  }

  double railWidth(WidgetTester tester) =>
      tester.getSize(find.byType(SidebarNavigation)).width;

  group('responsive rail', () {
    testWidgets('is full width on a desktop viewport', (tester) async {
      await pumpAtWidth(tester, 1400);
      expect(railWidth(tester), SidebarNavigation.expandedWidth);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('collapses to an icon rail on a tablet viewport', (tester) async {
      await pumpAtWidth(tester, 900);
      expect(railWidth(tester), SidebarNavigation.railWidth);
      // Labels are gone, but the icons — and so the navigation — remain.
      expect(find.text('Dashboard'), findsNothing);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    });

    testWidgets('uses the narrow rail on a phone viewport', (tester) async {
      await pumpAtWidth(tester, 600);
      expect(railWidth(tester), SidebarNavigation.narrowRailWidth);
    });

    testWidgets('stays navigable when collapsed', (tester) async {
      final provider = AppProvider(autoLoad: false);
      tester.view
        ..physicalSize = const Size(600, 1400)
        ..devicePixelRatio = 1.0;
      await tester.pumpWidget(wrap(provider, const SidebarNavigation()));

      await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
      await tester.pump();

      expect(provider.currentNavIndex, 2);
    });

    testWidgets('toggle collapses an expanded rail', (tester) async {
      final provider = AppProvider(autoLoad: false);
      tester.view
        ..physicalSize = const Size(1400, 1400)
        ..devicePixelRatio = 1.0;
      await tester.pumpWidget(wrap(provider, const SidebarNavigation()));

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();

      expect(provider.sidebarCollapsed, isTrue);
      expect(railWidth(tester), SidebarNavigation.railWidth);
    });

    testWidgets('the last nav item is reachable on a short viewport', (tester) async {
      // 14 items do not fit a laptop-height window, so the rail must scroll to
      // its end — otherwise Settings is simply unreachable.
      final provider = AppProvider(autoLoad: false);
      tester.view
        ..physicalSize = const Size(1400, 700)
        ..devicePixelRatio = 1.0;
      await tester.pumpWidget(wrap(provider, const SidebarNavigation()));

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pump();

      expect(provider.currentNavIndex, 13);
    });

    testWidgets('the toggle is not offered below the breakpoint', (tester) async {
      // The rail is already forced collapsed, so a collapse control would lie.
      await pumpAtWidth(tester, 900);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
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
