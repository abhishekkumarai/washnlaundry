import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/widgets/load_state.dart';

/// `ErrorState`/`LoadingState` — the panels every screen falls back to on a
/// failed or in-flight load — had no direct test of their own; every screen
/// test that reaches one does so as a side effect of a provider error, never
/// asserting the widgets' own default title, Retry wiring, or spinner.
void main() {
  Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('ErrorState shows the default title and the given message',
      (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(host(provider, const ErrorState(message: 'Something broke.')));

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Something broke.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('ErrorState honours a custom title and 404 status code', (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(host(
      provider,
      const ErrorState(
        statusCode: 404,
        message: 'The requested order was not found.',
      ),
    ));

    expect(find.text('Error 404'), findsOneWidget);
    expect(find.text('Page Not Found'), findsOneWidget);
    expect(find.text('The requested order was not found.'), findsOneWidget);
  });

  testWidgets('ErrorState honours 500 status code and onHome button', (tester) async {
    final provider = AppProvider(autoLoad: false);
    var homePressed = false;
    await tester.pumpWidget(host(
      provider,
      ErrorState(
        statusCode: 500,
        message: 'Our server encountered an issue.',
        onHome: () => homePressed = true,
      ),
    ));

    expect(find.text('Error 500'), findsOneWidget);
    expect(find.text('Server Error'), findsOneWidget);
    expect(find.text('Back to Dashboard'), findsOneWidget);

    await tester.tap(find.text('Back to Dashboard'));
    await tester.pump();
    expect(homePressed, isTrue);
  });

  testWidgets('Retry calls back into AppProvider.refresh()', (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(host(provider, const ErrorState(message: 'Broke.')));

    await tester.tap(find.text('Try Again'));
    await tester.pump();

    // No server reachable in this test environment, so `refresh()` settles
    // into its own error state — the point here is only that the button is
    // really wired to it and nothing throws on the way.
    expect(tester.takeException(), isNull);
    expect(provider.hasError, isTrue);
  });

  testWidgets('LoadingState renders a spinner', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingState()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
