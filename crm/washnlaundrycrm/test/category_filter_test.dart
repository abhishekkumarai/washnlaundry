import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/widgets/category_filter.dart';

/// 100 services, every 10th with a very long name, like the overflow check.
final _many = [
  for (var i = 0; i < 100; i++)
    i % 10 == 0
        ? 'Service ${i.toString().padLeft(3, '0')} premium handcrafted delicate fabric care'
        : 'Service ${i.toString().padLeft(3, '0')}',
];

Widget _host(Widget child, {double width = 800}) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    );

class _Harness extends StatefulWidget {
  final List<String> categories;
  const _Harness(this.categories);
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String selected = '';
  @override
  Widget build(BuildContext context) => CategoryFilterRow(
        categories: widget.categories,
        selected: selected,
        onSelected: (v) => setState(() => selected = v),
      );
}

int _moreCount(WidgetTester tester) {
  final label = tester
      .widgetList<Text>(find.descendant(
          of: find.byKey(const Key('moreCategoriesButton')),
          matching: find.byType(Text)))
      .first
      .data!;
  return int.parse(RegExp(r'\((\d+)\)').firstMatch(label)!.group(1)!);
}

void main() {
  test('All first, then the selected category, then the rest in order', () {
    expect(pinSelectedCategory(['a', 'b', 'c'], ''), ['', 'a', 'b', 'c']);
    expect(pinSelectedCategory(['a', 'b', 'c'], 'c'), ['', 'c', 'a', 'b']);
  });

  testWidgets('few categories: all shown, no More button', (tester) async {
    await tester.pumpWidget(_host(const _Harness(['Ironing', 'Household'])));
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Ironing'), findsOneWidget);
    expect(find.byKey(const Key('moreCategoriesButton')), findsNothing);
  });

  testWidgets('100 services fit one row with a More count, no overflow',
      (tester) async {
    for (final width in [800.0, 360.0]) {
      await tester.pumpWidget(_host(_Harness(_many), width: width));
      expect(tester.takeException(), isNull);
      expect(find.text('All'), findsOneWidget);
      final shown =
          _many.where((c) => find.text(c).evaluate().isNotEmpty).length;
      expect(shown, greaterThan(0));
      // Every service is either a chip or counted behind More (All is extra).
      expect(shown + _moreCount(tester), _many.length);
    }
  });

  testWidgets('a service picked in the picker is selected and pinned',
      (tester) async {
    await tester.pumpWidget(_host(_Harness(_many)));
    const target = 'Service 077';
    expect(find.text(target), findsNothing);

    await tester.tap(find.byKey(const Key('moreCategoriesButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('categoryPickerSearch')), '077');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('categoryPick_$target')));
    await tester.pumpAndSettle();

    // Dialog closed; the choice sits right after All.
    expect(find.byType(Dialog), findsNothing);
    expect(find.text(target), findsOneWidget);
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    expect(state.selected, target);
    expect(tester.getTopLeft(find.text(target)).dx,
        greaterThan(tester.getTopLeft(find.text('All')).dx));

    // All goes back to everything.
    await tester.tap(find.text('All'));
    await tester.pump();
    expect(state.selected, '');
  });

  testWidgets('picker search with no match explains itself', (tester) async {
    await tester.pumpWidget(_host(CategoryPickerDialog(
      categories: _many,
      selected: '',
      onSelected: (_) {},
    )));
    await tester.enterText(
        find.byKey(const Key('categoryPickerSearch')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No services match.'), findsOneWidget);
  });
}
