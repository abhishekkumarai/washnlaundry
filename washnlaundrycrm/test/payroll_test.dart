import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/payroll_screen.dart';
import 'package:washnlaundrycrm/widgets/top_header.dart';

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

      // Scoped to the dialog: the page behind it now also has a search
      // `TextField` (Payroll's own search box), so an unscoped `.first`
      // would grab that one instead.
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)).first,
          '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Record Payment'));
      await tester.pump();

      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    });

    testWidgets('the record payment dialog rejects an amount over what is outstanding',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Record Payment').first);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)).first,
          '5601');
      await tester.tap(find.widgetWithText(FilledButton, 'Record Payment'));
      await tester.pump();

      expect(find.text('Cannot exceed the ₹5600 outstanding.'), findsOneWidget);
    });

    testWidgets('the dialog prefills with what is outstanding', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Record Payment').first);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField)).first);
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

    testWidgets(
        'the header "New Payroll" button opens a staff picker, not the New '
        'Order screen', (tester) async {
      // The header used to be a shared TopHeader hardcoded to "New Order",
      // which on this screen dropped the user into the New Order POS instead
      // of doing anything payroll-related.
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      // "New Order" still legitimately appears as a sidebar nav item at this
      // width — scope the check to the header itself, whose button used to
      // be a shared, hardcoded "New Order".
      final header = find.byType(TopHeader);
      expect(find.descendant(of: header, matching: find.text('New Order')),
          findsNothing);
      expect(find.descendant(of: header, matching: find.text('New Payroll')),
          findsOneWidget);

      await tester.tap(find.descendant(of: header, matching: find.text('New Payroll')));
      await tester.pumpAndSettle();

      expect(find.text('New Payroll — ${_currentMonthLabel()}'), findsOneWidget);
      // Both names also still show in the row list behind the dialog.
      expect(find.text('Ramesh Kumar'), findsWidgets);
      expect(find.text('Sunil Paswan'), findsWidgets);

      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Sunil Paswan')));
      await tester.pumpAndSettle();

      // Sunil is fully PAID, so the record-payment dialog opens prefilled
      // with nothing outstanding.
      expect(find.text('Pay Sunil Paswan'), findsOneWidget);
      final field = tester.widget<TextField>(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField)).first);
      expect(field.controller!.text, '0');
    });

    testWidgets('"New Payroll" with no payroll yet says so instead of opening '
        'an empty dialog', (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(payroll: const PayrollSummaryModel());
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.text('New Payroll'));
      await tester.pump();

      expect(
          find.text('No staff payroll for this month yet. Mark attendance first.'),
          findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('search filters rows by staff name or role', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Sunil Paswan'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'ramesh');
      await tester.pump();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Sunil Paswan'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'steam press');
      await tester.pump();

      expect(find.text('Ramesh Kumar'), findsNothing);
      expect(find.text('Sunil Paswan'), findsOneWidget);
    });

    testWidgets('a search matching nobody says so, not "no payroll"',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump();

      expect(find.text('No staff match "zzzz".'), findsOneWidget);
      expect(find.text('No payroll for this month.'), findsNothing);
    });

    group('responsive layout', () {
      Future<void> pumpAt(WidgetTester tester, double width) async {
        tester.view
          ..physicalSize = Size(width, 1400)
          ..devicePixelRatio = 1.0;
        final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
        await tester.pumpWidget(host(provider, const PayrollScreen()));
        await tester.pump();
      }

      testWidgets('shows History/Record Payment as text buttons at wide width',
          (tester) async {
        await pumpAt(tester, 1900);

        expect(find.widgetWithText(TextButton, 'History'), findsWidgets);
        expect(find.widgetWithText(TextButton, 'Record Payment'), findsWidgets);
      });

      testWidgets('stacks records into cards with full-width action buttons '
          'at phone width', (tester) async {
        await pumpAt(tester, 390);

        expect(find.widgetWithText(TextButton, 'History'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'History'), findsWidgets);
        expect(find.widgetWithText(FilledButton, 'Record Payment'),
            findsWidgets);
        expect(find.text('Ramesh Kumar'), findsOneWidget);
      });
    });

    testWidgets('the help icon explains how figures are calculated',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.byTooltip('How Payroll is calculated'));
      await tester.pumpAndSettle();

      expect(find.text('How Payroll is calculated'), findsOneWidget);
      expect(find.text('Net pay'), findsWidgets);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('How Payroll is calculated'), findsNothing);
    });

    testWidgets('Add advance opens a dialog and rejects a zero amount',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(payroll: summary, staff: staffRoster);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add advance'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Add advance —'), findsOneWidget);

      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)).first,
          '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Save advance'));
      await tester.pump();

      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    });

    testWidgets('Pay all pending is disabled once nothing is outstanding',
        (tester) async {
      const settled = PayrollSummaryModel(
        entries: [
          PayrollEntryModel(
            staffId: '2',
            staffName: 'Sunil Paswan',
            role: 'Steam Press Master',
            totalSalary: 14100,
            netPay: 14100,
            paidAmount: 14100,
            status: 'PAID',
          ),
        ],
        totalPayroll: 14100,
        paid: 14100,
        staffCount: 1,
      );
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: settled);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      final button =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pay all pending'));
      expect(button.onPressed, isNull);
    });

    testWidgets('Pay all pending asks for confirmation before paying',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(payroll: summary);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Pay all pending'));
      await tester.pumpAndSettle();

      expect(find.text('Pay all pending?'), findsOneWidget);
      expect(find.textContaining('1 staff member'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Pay all pending?'), findsNothing);
    });

    testWidgets('the salary slip shows the attendance breakdown and net pay',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(payroll: summary, staff: staffRoster);
      await tester.pumpWidget(host(provider, const PayrollScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.description_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Ramesh Kumar — Salary Slip'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      // Net pay row — Ramesh's summary fixture has no advance, so net pay
      // equals the gross total_salary of 15600.
      expect(find.text('₹15600'), findsWidgets);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Ramesh Kumar — Salary Slip'), findsNothing);
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
