import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/widgets/app_date_picker.dart';

void main() {
  testWidgets('AppDateButton displays label and responds to tap', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDateButton(
            label: 'Select Date',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Select Date'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);

    await tester.tap(find.text('Select Date'));
    expect(tapped, isTrue);
  });

  testWidgets('AppDatePicker.pickDate opens dialog on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => AppDatePicker.pickDate(
                  context: context,
                  initialDate: DateTime(2026, 8, 15),
                ),
                child: const Text('Open Picker'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    // Verify dialog appears with action buttons and calendar
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('AppDatePicker.pickDateRange opens range dialog on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => AppDatePicker.pickDateRange(
                  context: context,
                  initialRange: DateTimeRange(
                    start: DateTime(2026, 8, 1),
                    end: DateTime(2026, 8, 15),
                  ),
                ),
                child: const Text('Open Range Picker'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Range Picker'));
    await tester.pumpAndSettle();

    // Verify dialog appears with action buttons
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
  });
}

