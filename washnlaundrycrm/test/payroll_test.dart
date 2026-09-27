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

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _currentMonthLabel() {
  final now = DateTime.now();
  return '${_monthNames[now.month - 1]} ${now.year}';
}

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
        presentDays: 24,
        totalSalary: 15600,
        netPay: 15600,
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
        presentDays: 23,
        halfDays: 1,
        totalSalary: 14100,
        netPay: 14100,
        paidAmount: 14100,
        status: 'PAID',
      ),
    ],
    totalPayroll: 29700,
    paid: 24100,
    pending: 5600,
    staffCount: 2,
  );

  const staffRoster = [
    StaffModel(id: '1', name: 'Ramesh Kumar', role: 'Head Washer', phone: '9876543210'),
    StaffModel(id: '2', name: 'Sunil Paswan', role: 'Steam Press Master', phone: '9123456780'),
  ];

  group('PayrollScreen', () {
    Future<AppProvider> pump(WidgetTester tester,
        {PayrollSummaryModel data = summary}) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(payroll: data, staff: staffRoster);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();
      return provider;
    }

    testWidgets('rows come from the provider, not a literal', (tester) async {
      await pump(tester);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Sunil Paswan'), findsOneWidget);
      expect(find.text('Vikram Singh'), findsNothing);
    });

    testWidgets("the table has the live app's columns", (tester) async {
      await pump(tester);
      for (final h in [
        'Staff', 'Salary', 'Present', 'Half', 'Leave', 'Advances',
        'Deductions', 'Net pay', 'Status', 'Actions',
      ]) {
        expect(find.text(h), findsWidgets, reason: h);
      }
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Showing 1–2 of 2 staff'), findsOneWidget);
      expect(
          find.textContaining('Paid salaries appear in', findRichText: true),
          findsOneWidget);
      // The old screen's extras are gone.
      expect(find.text('New Payroll'), findsNothing);
      expect(find.text('Search staff...'), findsNothing);
    });

    testWidgets('the KPI cards use the server totals, with shares',
        (tester) async {
      await pump(tester);
      // Total payroll card, plus the Total row's Salary and Net pay cells
      // (no advances here, so net pay sums to the same figure).
      expect(find.text('₹29,700'), findsNWidgets(3));
      expect(find.text('₹24,100'), findsOneWidget);
      expect(find.text('₹5,600'), findsOneWidget);
      expect(find.text('81.1%'), findsOneWidget); // paid share
      expect(find.text('18.9%'), findsOneWidget); // pending share
      expect(find.text('active staff'), findsOneWidget);
    });

    testWidgets("status pills use the live app's words", (tester) async {
      await pump(tester);
      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Paid'), findsWidgets); // pill + Paid KPI label
      expect(find.text('PARTIAL'), findsNothing);
    });

    testWidgets('an owed row offers "Pay ₹X"; a settled one offers the '
        'payments view instead', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('payroll-pay-1')), findsOneWidget);
      expect(find.text('Pay ₹5,600'), findsOneWidget);
      expect(find.byKey(const ValueKey('payroll-pay-2')), findsNothing);
      expect(find.byTooltip('Manage payments & adjustments'), findsOneWidget);
      expect(find.byTooltip('Send on WhatsApp'), findsNWidgets(2));
    });

    testWidgets('the title sits at the top, not centred in a short page',
        (tester) async {
      await pump(tester);
      final title = find.byWidgetPredicate((w) =>
          w is Text && w.data == 'Payroll' && w.style?.fontSize == 24);
      expect(tester.getTopLeft(title).dy, lessThan(60));
    });

    testWidgets('a month with no payroll says so', (tester) async {
      await pump(tester, data: const PayrollSummaryModel());
      expect(find.text('No staff members'), findsOneWidget);
      expect(find.text('₹0'), findsWidgets);
    });

    testWidgets('the month dropdown defaults to the current month',
        (tester) async {
      await pump(tester);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('payroll-month-picker')),
              matching: find.text(_currentMonthLabel())),
          findsOneWidget);
    });

    testWidgets('Pay opens a fixed-amount settle dialog', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('payroll-pay-1')));
      await tester.pumpAndSettle();
      expect(find.text('Pay salary'), findsOneWidget);
      expect(
          find.text("Settle Ramesh Kumar's salary for ${_currentMonthLabel()}. "
              'It is marked paid.'),
          findsOneWidget);
      expect(find.text('Amount to pay'), findsOneWidget);
      for (final m in ['Cash', 'UPI', 'Bank']) {
        expect(find.text(m), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Pay salary'), findsNothing);
    });

    testWidgets('Pay all pending settles every owed row in one dialog',
        (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Pay all pending'));
      await tester.pumpAndSettle();
      expect(
          find.text('Settle 1 salaries for ${_currentMonthLabel()}. '
              'Each is marked paid.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('payroll-settle-confirm')),
          findsOneWidget);
    });

    testWidgets('Pay all pending is disabled once nothing is outstanding',
        (tester) async {
      await pump(tester,
          data: const PayrollSummaryModel(entries: [
            PayrollEntryModel(
              staffId: '2',
              staffName: 'Sunil Paswan',
              netPay: 14100,
              paidAmount: 14100,
              status: 'PAID',
            ),
          ]));
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Pay all pending'));
      expect(button.onPressed, isNull);
    });

    testWidgets('Add advance asks for a staff member, then an amount',
        (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add advance'));
      await tester.pumpAndSettle();
      expect(find.text('Select staff'), findsOneWidget);
      expect(find.text("The advance is deducted from this month's net pay."),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('payroll-advance-confirm')));
      await tester.pump();
      expect(find.text('Select a staff member.'), findsOneWidget);

      await tester.tap(find.text('Select staff'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sunil Paswan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payroll-advance-confirm')));
      await tester.pump();
      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    });

    testWidgets('clicking a name docks the salary slip beside the table',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('payroll-open-slip-1')));
      await tester.pumpAndSettle();
      expect(find.text('Salary slip'), findsOneWidget);
      expect(find.text('Ramesh Kumar · ${_currentMonthLabel()}'),
          findsOneWidget);
      expect(find.text('Gross salary'), findsOneWidget);
      expect(find.text('Manage payments & adjustments →'), findsOneWidget);
      // Docked, not a dialog: the table is still there.
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Showing 1–2 of 2 staff'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Salary slip'), findsNothing);
    });

    testWidgets('the payments view replaces the list and comes back',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Manage payments & adjustments'));
      await tester.pumpAndSettle();
      expect(find.text('Monthly · ₹15,600/Month'), findsOneWidget);
      expect(find.text('Showing 1–2 of 2 staff'), findsNothing);
      // Sunil is fully paid, so there is nothing to record.
      final record = tester.widget<FilledButton>(find.ancestor(
          of: find.text('Record payment'), matching: find.byType(FilledButton)));
      expect(record.onPressed, isNull);

      await tester.tap(find.byTooltip('Back to Payroll'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 1–2 of 2 staff'), findsOneWidget);
    });

    testWidgets('Record payment rejects zero and over-payment',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('payroll-open-slip-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage payments & adjustments →'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();

      final amount = find.widgetWithText(TextField, 'Amount');
      expect(tester.widget<TextField>(amount).controller!.text, '5600');

      await tester.enterText(amount, '0');
      await tester.tap(find.byKey(const ValueKey('payroll-record-confirm')));
      await tester.pump();
      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);

      await tester.enterText(amount, '99999');
      await tester.tap(find.byKey(const ValueKey('payroll-record-confirm')));
      await tester.pump();
      expect(find.text('Cannot exceed the ₹5,600 outstanding.'),
          findsOneWidget);
    });

    testWidgets('at phone width rows become cards and the slip is a dialog',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      await pump(tester);
      expect(find.text('Deductions'), findsNothing); // no table header
      expect(find.text('Pay ₹5,600'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('payroll-open-slip-1')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Salary slip'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

    test('parses the attendance breakdown, advances and net pay', () {
      final model = PayrollSummaryModel.fromJson({
        'entries': [
          {
            'staff': 3,
            'staff_name': 'Geeta Devi',
            'present_days': 18,
            'half_days': 2,
            'leave_days': 1,
            'total_salary': 14350,
            'advances_amount': 1000,
            'net_pay': 13350,
            'paid_amount': 0,
            'pending_amount': 13350,
            'status': 'UNPAID',
          },
        ],
      });

      final entry = model.entries.single;
      expect(entry.presentDays, 18);
      expect(entry.halfDays, 2);
      expect(entry.leaveDays, 1);
      expect(entry.advancesAmount, 1000);
      expect(entry.netPay, 13350);
    });

    test('net_pay falls back to total_salary for an older payload shape', () {
      final model = PayrollSummaryModel.fromJson({
        'entries': [
          {'staff': 1, 'staff_name': 'A', 'total_salary': 5000},
        ],
      });
      expect(model.entries.single.netPay, 5000);
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

  group('Payroll unlogged attendance and float rounding', () {
    test('unlogged attendance earns nothing but a payment can still be recorded', () {
      final model = PayrollSummaryModel.fromJson({
        'entries': [
          {
            'staff': 10,
            'staff_name': 'Tarun Unlogged',
            'role': 'Ironer',
            'monthly_wage': 12000,
            'days_worked': 0,
            'total_salary': 0,
            'net_pay': 0,
            'paid_amount': 0,
            'pending_amount': 0,
            'status': 'UNPAID',
          },
        ],
      });
      final entry = model.entries.single;
      expect(entry.daysWorked, 0);
      expect(entry.totalSalary, 0);
      expect(entry.nothingEarned, isTrue);
      expect(entry.canRecordPayment, isTrue);
    });

    test('a fully paid month with earned wages cannot take another payment', () {
      const entry = PayrollEntryModel(
        staffId: '12',
        staffName: 'Settled',
        netPay: 9000,
        paidAmount: 9000,
        pendingAmount: 0,
        status: 'PAID',
      );
      expect(entry.nothingEarned, isFalse);
      expect(entry.canRecordPayment, isFalse);
    });

    test('fractional paise remainder under 1 rupee marks status as PAID with 0 pending', () {
      final model = PayrollSummaryModel.fromJson({
        'entries': [
          {
            'staff': 11,
            'staff_name': 'Lakshman Rao',
            'role': 'Washer',
            'monthly_wage': 10000,
            'days_worked': 26,
            'total_salary': 8583.33,
            'net_pay': 8583.33,
            'paid_amount': 8583.0,
            'pending_amount': 0.0,
            'status': 'PAID',
          },
        ],
      });
      final entry = model.entries.single;
      expect(entry.pendingAmount, 0.0);
      expect(entry.status, 'PAID');
    });
  });
}
