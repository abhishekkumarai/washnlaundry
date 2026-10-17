import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/widgets/tag_filter.dart';

/// 140 two-word tags plus 10 very long ones, like the 150-tag overflow check.
final _manyTags = [
  for (var i = 0; i < 140; i++) 'tag-$i word',
  for (var i = 0; i < 10; i++)
    'a-very-long-tag-name-number-$i-that-goes-on-and-on-forever',
]..sort();

Widget _host(Widget child, {double width = 800}) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    );

class _RowHarness extends StatefulWidget {
  final List<String> tags;
  final Set<String> selected;
  const _RowHarness(this.tags, this.selected);
  @override
  State<_RowHarness> createState() => _RowHarnessState();
}

class _RowHarnessState extends State<_RowHarness> {
  @override
  Widget build(BuildContext context) => TagFilterRow(
        tags: widget.tags,
        selected: widget.selected,
        onChanged: () => setState(() {}),
      );
}

void main() {
  group('tag helpers', () {
    test('selected tags are pinned first, both groups sorted', () {
      expect(pinSelectedFirst(['b', 'a', 'd', 'c'], {'d', 'b'}),
          ['b', 'd', 'a', 'c']);
    });

    test('a selected tag not on offer is still listed', () {
      expect(pinSelectedFirst(['a'], {'z'}), ['z', 'a']);
    });

    test('picker filter is a case-insensitive substring match', () {
      expect(filterTags(['Express', 'delicate', 'xpress-ish'], 'XPRESS'),
          ['Express', 'xpress-ish']);
      expect(filterTags(['a', 'b'], '  '), ['a', 'b']);
      expect(filterTags(['a', 'b'], 'zzz'), isEmpty);
    });
  });

  group('TagFilterRow', () {
    testWidgets('few tags: all shown, no More button', (tester) async {
      await tester.pumpWidget(
          _host(const _RowHarness(['bulk', 'express'], <String>{})));
      expect(find.text('bulk'), findsOneWidget);
      expect(find.text('express'), findsOneWidget);
      expect(find.byKey(const Key('moreTagsButton')), findsNothing);
    });

    testWidgets('150 tags fit one row with a More count, no overflow',
        (tester) async {
      for (final width in [800.0, 360.0]) {
        await tester.pumpWidget(
            _host(_RowHarness(_manyTags, <String>{}), width: width));
        expect(tester.takeException(), isNull);
        final more = find.byKey(const Key('moreTagsButton'));
        expect(more, findsOneWidget);
        final label = tester
            .widgetList<Text>(find.descendant(of: more, matching: find.byType(Text)))
            .first
            .data!;
        final hidden = int.parse(RegExp(r'\((\d+)\)').firstMatch(label)!.group(1)!);
        final shown = _manyTags.where((t) => find.text(t).evaluate().isNotEmpty).length;
        expect(shown + hidden, _manyTags.length);
        expect(shown, greaterThan(0));
      }
    });

    testWidgets('a tag picked in the picker is pinned into the row',
        (tester) async {
      final selected = <String>{};
      await tester.pumpWidget(_host(_RowHarness(_manyTags, selected)));
      final last = _manyTags.last;
      expect(find.text(last), findsNothing);

      await tester.tap(find.byKey(const Key('moreTagsButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('tagPickerSearch')), last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('tagPick_$last')));
      await tester.pumpAndSettle();
      expect(selected, {last});
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text(last), findsOneWidget);
      expect(find.text('Clear (1)'), findsOneWidget);

      // Untick from the row; same set.
      await tester.tap(find.text(last));
      await tester.pump();
      expect(selected, isEmpty);
    });
  });

  group('TagPickerDialog', () {
    testWidgets('search filters the list, ticks are shared, Clear empties',
        (tester) async {
      final selected = <String>{'tag-1 word'};
      var changes = 0;
      await tester.pumpWidget(_host(TagPickerDialog(
        tags: _manyTags,
        selected: selected,
        onChanged: () => changes++,
      )));

      await tester.enterText(find.byKey(const Key('tagPickerSearch')), 'tag-14');
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.byKey(const ValueKey('tagPick_tag-14 word')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('tagPickerSearch')), 'tag-13');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tagPick_tag-135 word')), findsOneWidget);
      expect(find.text('tag-1 word'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tagPick_tag-135 word')));
      await tester.pump();
      expect(selected, {'tag-1 word', 'tag-135 word'});

      await tester.enterText(find.byKey(const Key('tagPickerSearch')), 'nope');
      await tester.pumpAndSettle();
      expect(find.text('No tags match.'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(selected, isEmpty);
      expect(changes, 2);
    });
  });

  group('MoreTagsChip', () {
    Widget preview(List<String> tags) => _host(Row(children: <Widget>[
          for (final t in tags.take(2)) Text('#$t'),
          if (tags.length > 2) MoreTagsChip(tags: tags),
        ]));

    testWidgets('absent at 2 tags or fewer', (tester) async {
      await tester.pumpWidget(preview(const ['a', 'b']));
      expect(find.byType(MoreTagsChip), findsNothing);
    });

    testWidgets('shows +N with the hidden count and lists all on tap',
        (tester) async {
      final tags = [for (var i = 0; i < 30; i++) 't$i'];
      await tester.pumpWidget(preview(tags));
      expect(find.text('+28'), findsOneWidget);
      await tester.tap(find.text('+28'));
      await tester.pumpAndSettle();
      expect(find.textContaining('#t29'), findsOneWidget);
    });
  });
}
