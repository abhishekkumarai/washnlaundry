import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/widgets/app_shell.dart';
import 'package:washnlaundrycrm/widgets/sidebar_navigation.dart';

import 'support/router_test_utils.dart';

// Mirrors the real per-screen wiring — `Scaffold(drawer: const AppDrawer(),
// body: AppShell(body: ...))` — inside `hostWithRouter`'s own outer Scaffold,
// so `Scaffold.of(context)` inside `AppShell`/`AppDrawer` resolves to this
// inner Scaffold (the nearest ancestor), exactly as it does for a real screen.
Widget wrap(AppProvider provider, {Widget? body}) {
  return hostWithRouter(
    provider,
    Scaffold(
      drawer: const AppDrawer(),
      body: AppShell(body: body ?? const SizedBox.expand()),
    ),
  );
}

// Locates the screen's own Scaffold (the one carrying `drawer:`) rather than
// `hostWithRouter`'s outer one, so `.isDrawerOpen` reads the right state — a
// GlobalKey would work too, but collides across the two routes briefly alive
// during a GoRouter transition since `hostWithRouter` reuses one child
// instance for every route.
ScaffoldState ourScaffold(WidgetTester tester) => tester.state<ScaffoldState>(
      find.byWidgetPredicate((w) => w is Scaffold && w.drawer != null),
    );

Future<void> pumpAtWidth(WidgetTester tester, double width, Widget widget) async {
  tester.view
    ..physicalSize = Size(width, 1400)
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(widget);
}

Finder persistentRail() =>
    find.byWidgetPredicate((w) => w is SidebarNavigation && !w.inDrawer);
Finder drawerRail() =>
    find.byWidgetPredicate((w) => w is SidebarNavigation && w.inDrawer);

void main() {
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

  group('AppShell above the breakpoint', () {
    testWidgets('shows the persistent rail and no hamburger bar', (tester) async {
      await pumpAtWidth(tester, 1400, wrap(AppProvider(autoLoad: false)));

      expect(persistentRail(), findsOneWidget);
      // No top bar with a drawer hamburger ('Menu')... the rail's own
      // collapse toggle is a hamburger icon too, but it is a different control.
      expect(find.byTooltip('Menu'), findsNothing);
      expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
    });
  });

  testWidgets('Scan sits right after Orders in the sidebar', (tester) async {
    await pumpAtWidth(tester, 1400, wrap(AppProvider(autoLoad: false)));
    double y(String label) => tester.getTopLeft(find.text(label).first).dy;
    expect(y('Orders') < y('Scan'), isTrue);
    expect(y('Scan') < y('Customers'), isTrue);
  });

  group('Social Suite and Chat (switched on per shop, off by default)', () {
    testWidgets('neither is in the sidebar for a shop without them', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(shop: {'name': 'Off Wash'});
      await pumpAtWidth(tester, 1400, wrap(provider));
      expect(find.text('Social Suite', skipOffstage: false), findsNothing);
      expect(find.text('Chat', skipOffstage: false), findsNothing);
      expect(find.text('Settings', skipOffstage: false), findsOneWidget);
    });

    testWidgets('each shows only when its own switch is on', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(shop: {'name': 'Chat Wash', 'chat_enabled': true});
      await pumpAtWidth(tester, 1400, wrap(provider));
      expect(find.text('Chat', skipOffstage: false), findsOneWidget);
      expect(find.text('Social Suite', skipOffstage: false), findsNothing);

      provider.seedForTest(shop: {'name': 'Both', 'chat_enabled': true,
          'social_suite_enabled': true});
      await tester.pump();
      expect(find.text('Social Suite', skipOffstage: false), findsOneWidget);
      expect(find.text('Chat', skipOffstage: false), findsOneWidget);
    });
  });

  group('AppShell below the breakpoint', () {
    testWidgets('shows the hamburger bar and drops the persistent rail',
        (tester) async {
      await pumpAtWidth(tester, 600, wrap(AppProvider(autoLoad: false)));

      expect(persistentRail(), findsNothing);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });

    testWidgets('tapping the hamburger opens a Drawer with the full nav list',
        (tester) async {
      await pumpAtWidth(tester, 600, wrap(AppProvider(autoLoad: false)));

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(drawerRail(), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('picking a destination in the Drawer navigates and closes it',
        (tester) async {
      final provider = AppProvider(autoLoad: false);
      await pumpAtWidth(tester, 600, wrap(provider));

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      expect(ourScaffold(tester).isDrawerOpen, isTrue);

      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(provider.currentNavIndex, 2);
      expect(ourScaffold(tester).isDrawerOpen, isFalse);
    });
  });
}
