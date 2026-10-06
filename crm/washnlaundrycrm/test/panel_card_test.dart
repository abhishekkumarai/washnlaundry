import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/utils/money.dart';
import 'package:washnlaundrycrm/widgets/panel_card.dart';

/// `PanelCard` and `StatRow` — the shared chrome every dashboard panel is
/// built from — were only ever exercised indirectly, through whichever panel
/// happened to be under test elsewhere. This pins their own optional
/// branches (subtitle, trailing, caption) directly.
void main() {
  tearDown(Money.reset);

  group('PanelCard', () {
    testWidgets('renders the title alone when subtitle and trailing are omitted',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PanelCard(title: 'Panel', child: Text('body')),
      ));

      expect(find.text('Panel'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('renders a subtitle and a trailing widget when given', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PanelCard(
          title: 'Panel',
          subtitle: 'Sub',
          trailing: Text('Trailing'),
          child: Text('body'),
        ),
      ));

      expect(find.text('Sub'), findsOneWidget);
      expect(find.text('Trailing'), findsOneWidget);
    });
  });

  group('StatRow', () {
    testWidgets('renders label and value without a caption', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: StatRow(
            icon: Icons.star,
            iconColor: Colors.blue,
            iconBackground: Colors.white,
            label: 'Label',
            value: '42',
          ),
        ),
      ));

      expect(find.text('Label'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders a caption when given', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: StatRow(
            icon: Icons.star,
            iconColor: Colors.blue,
            iconBackground: Colors.white,
            label: 'Label',
            caption: 'Extra detail',
            value: '42',
          ),
        ),
      ));

      expect(find.text('Extra detail'), findsOneWidget);
    });
  });

  group('formatPercent', () {
    test('null is an em dash, not 0%', () {
      expect(formatPercent(null), '—');
    });

    test('a whole number drops the decimal', () {
      expect(formatPercent(12.0), '12%');
    });

    test('a fractional value keeps one decimal', () {
      expect(formatPercent(12.5), '12.5%');
    });
  });

  group('initialsFor', () {
    test('null or blank is a question mark', () {
      expect(initialsFor(null), '?');
      expect(initialsFor('   '), '?');
    });

    test('a single short word stays as-is, upper-cased', () {
      expect(initialsFor('AK'), 'AK');
      expect(initialsFor('a'), 'A');
    });

    test('a single long word is truncated to two letters', () {
      expect(initialsFor('washing'), 'WA');
    });

    test('multiple words take the first letter of the first two', () {
      expect(initialsFor('Ramesh Kumar'), 'RK');
      expect(initialsFor('  Ramesh   Kumar  '), 'RK');
    });
  });
}
