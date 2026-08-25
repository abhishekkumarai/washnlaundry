import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/payroll_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(1900, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  const summary = PayrollSummaryModel(
    entries: [
      PayrollEntryModel(
        staffId: '1',
        staffName: 'Ramesh Kumar',
        role: 'Head Washer',
        monthlyWage: 16900,
        daysWorked: 24,
        totalSalary: 15600,
        paidAmount: 10000,
        pendingAmount: 5600,
        status: 'PARTIAL',
      ),
      PayrollEntryModel(
        staffId: '2',
        staffName: 'Sunil Paswan',
        role: 'Steam Press Master',
        monthlyWage: 15600,
        daysWorked: 23.5,
        totalSalary: 14100,
        paidAmount: 14100,
        status: 'PAID',
      ),
    ],
    totalPayroll: 29700,
    paid: 24100,
    pending: 5600,
    staffCount: 2,
  );

  group('PayrollScreen', () {
    testWidgets('rows come from the provider, not a literal', (tester) async {
      // The screen used to hardcode three staff, one of whom ('Vikram Singh')
      // did not exist in the shop at all.
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Sunil Paswan'), findsOneWidget);
      expect(find.text('Vikram Singh'), findsNothing);
    });

    testWidgets('the KPI cards use the server totals', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      expect(find.text('₹29700'), findsOneWidget);
      expect(find.text('₹24100'), findsOneWidget);
      expect(find.text('₹5600'), findsWidgets); // pending card + Ramesh's due
      expect(find.text('2'), findsOneWidget); // staff count
    });

    testWidgets('a half day is not rounded away', (tester) async {
      // 23.5 days is real — HALF_DAY is a status the register offers and the
      // backend pays at half rate.
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      expect(find.text('Days worked: 23.5'), findsOneWidget);
      // A whole number should not gain a misleading ".0".
      expect(find.text('Days worked: 24'), findsOneWidget);
    });

    testWidgets('status badges reflect the server verdict', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      expect(find.text('PARTIAL'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
    });

    testWidgets('a settled row cannot be paid again', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      final buttons = tester
          .widgetList<TextButton>(find.widgetWithText(TextButton, 'Record Payment'))
          .toList();
      expect(buttons.length, 2);
      expect(buttons[0].onPressed, isNotNull); // PARTIAL — still owed
      expect(buttons[1].onPressed, isNull); // PAID — nothing outstanding
    });

    testWidgets('a month with no payroll says so', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(payroll: const PayrollSummaryModel());
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      expect(find.text('No payroll for this month.'), findsOneWidget);
      expect(find.text('₹0'), findsWidgets);
    });

    testWidgets('the month label defaults to the current month, not July 2026',
        (tester) async {
      const monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      final now = DateTime.now();
      final expected = '${monthNames[now.month - 1]} ${now.year}';

      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('the record payment dialog rejects a zero amount', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Record Payment').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Record Payment'));
      await tester.pump();

      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    });

    testWidgets('the dialog prefills with what is outstanding', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Record Payment').first);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, '5600');
    });

    testWidgets('History opens a dialog scoped to that staff member', (tester) async {
      // Salary payments used to be write-only — recordable, never shown back.
      // The dialog's content is a real `/salary-payments/` fetch with no mock
      // seam in this suite (same gap noted elsewhere for order/customer
      // creation) — it rejects almost immediately in a test environment with
      // no server to reach, so this checks the dialog opens scoped to the
      // right staff member and survives that failure, not what a successful
      // fetch would render.
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'History').first);
      await tester.pumpAndSettle();

      expect(find.text('Ramesh Kumar — Payment History'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Ramesh Kumar — Payment History'), findsNothing);
    });
  });

  group('PayrollSummaryModel', () {
    test('parses the endpoint payload', () {
      final model = PayrollSummaryModel.fromJson({
        'month': '2026-07-01',
        'entries': [
          {
            'staff': 3,
            'staff_name': 'Geeta Devi',
            'role': 'Dry Cleaning',
            'monthly_wage': 18200,
            'days_worked': 20.5,
            'total_salary': 14350,
            'paid_amount': 0,
            'pending_amount': 14350,
            'status': 'UNPAID',
          },
        ],
        'totals': {
          'total_payroll': 14350,
          'paid': 0,
          'pending': 14350,
          'staff_count': 1,
        },
      });

      expect(model.month, DateTime(2026, 7, 1));
      expect(model.entries.single.staffId, '3');
      expect(model.entries.single.daysWorked, 20.5);
      expect(model.totalPayroll, 14350);
      expect(model.staffCount, 1);
    });

    test('an empty payload does not throw', () {
      final model = PayrollSummaryModel.fromJson({});
      expect(model.entries, isEmpty);
      expect(model.totalPayroll, 0);
      expect(model.month, isNull);
    });

    test('daysWorkedLabel drops a pointless .0 but keeps a real half', () {
      expect(const PayrollEntryModel(staffId: '1', staffName: 'A', daysWorked: 24).daysWorkedLabel, '24');
      expect(const PayrollEntryModel(staffId: '1', staffName: 'A', daysWorked: 23.5).daysWorkedLabel, '23.5');
    });
  });

  group('SalaryPaymentModel', () {
    test('parses a /salary-payments/ row', () {
      final model = SalaryPaymentModel.fromJson({
        'id': 7,
        'staff': 1,
        'staff_name': 'Ramesh Kumar',
        'month': '2026-07-01',
        'amount': 10000,
        'paid_on': '2026-07-15T10:30:00Z',
        'method': 'UPI',
        'note': 'Advance for the month',
      });

      expect(model.id, '7');
      expect(model.staffId, '1');
      expect(model.month, DateTime(2026, 7, 1));
      expect(model.amount, 10000);
      expect(model.method, 'UPI');
      expect(model.note, 'Advance for the month');
    });
  });

  group('AppProvider payroll', () {
    test('monthKey is the YYYY-MM the endpoint expects', () {
      expect(AppProvider.monthKey(DateTime(2026, 8)), '2026-08');
      expect(AppProvider.monthKey(DateTime(2026, 12)), '2026-12');
    });
  });
}
