import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/customer_detail_screen.dart';
import 'package:washnlaundrycrm/screens/customers_screen.dart';

Widget host(AppProvider provider, Widget child) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

OrderModel order({
  required String id,
  required String number,
  String customerId = '',
  String phone = '',
  String name = 'Someone',
  double total = 500,
  String status = OrderStatus.delivered,
  DateTime? createdAt,
  int itemCount = 2,
}) {
  return OrderModel(
    id: id,
    orderNumber: number,
    customerId: customerId,
    customerName: name,
    customerPhone: phone,
    status: status,
    paymentStatus: PaymentStatus.paid,
    paymentMethod: 'CASH',
    totalAmount: total,
    paidAmount: total,
    dueAmount: 0,
    express: false,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(hours: 3)),
    items: List.generate(
      itemCount,
      (i) => const OrderItemModel(
        itemTitle: 'Shirt',
        serviceType: 'Ironing',
        status: OrderStatus.delivered,
        quantity: 1,
        unit: 'PIECE',
        unitPrice: 15,
        totalPrice: 15,
      ),
    ),
  );
}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.physicalSize = const Size(1600, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  final roster = [
    CustomerModel(
      id: 'c1',
      name: 'Ramesh Kumar',
      phone: '9711223344',
      email: 'ramesh@example.com',
      area: 'HBR Layout',
      totalOrders: 3,
      totalSpent: 1500,
      avgOrderValue: 500,
      createdAt: DateTime(2026, 7, 4),
    ),
    const CustomerModel(
      id: 'c2',
      name: 'Geeta Devi',
      phone: '9922334455',
      email: 'geeta@example.com',
      area: 'Indiranagar',
    ),
  ];

  group('CustomersScreen', () {
    testWidgets('renders the roster from the provider, not a literal',
        (tester) async {
      // The screen used to hardcode a single fake customer called "Me".
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Geeta Devi'), findsOneWidget);
      expect(find.text('HBR Layout'), findsOneWidget);
      expect(find.text('Me'), findsNothing);
      expect(find.text('2 Total'), findsOneWidget);
    });

    testWidgets('KPI cards count total, active and new', (tester) async {
      // Only Ramesh has orders, so Active is 1 — not the headcount.
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);

      final active = tester.widget<Text>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Active'),
            matching: find.byType(Column),
          ).first,
          matching: find.byType(Text),
        ).last,
      );
      expect(active.data, '1');
    });

    testWidgets('search matches name, phone and email', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'geeta@example');
      await tester.pump();
      expect(find.text('Geeta Devi'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsNothing);

      await tester.enterText(find.byType(TextField).first, '9711223344');
      await tester.pump();
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Geeta Devi'), findsNothing);
    });

    testWidgets('the KPI cards act as filter tabs', (tester) async {
      // They used to be read-only counters — tapping one did nothing.
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Geeta Devi'), findsOneWidget);

      await tester.tap(find.text('Active'));
      await tester.pump();

      // Only Ramesh has ever placed an order.
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Geeta Devi'), findsNothing);
      expect(find.text('Active customers'), findsOneWidget);

      await tester.tap(find.text('New'));
      await tester.pump();

      // Ramesh joined in July; nobody in this roster joined this month.
      expect(find.text('No new customers this month.'), findsOneWidget);

      await tester.tap(find.text('Total'));
      await tester.pump();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Geeta Devi'), findsOneWidget);
      expect(find.text('All customers'), findsOneWidget);
    });

    testWidgets('a search matching nobody says so', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump();

      expect(find.text('No customer matches "zzzz".'), findsOneWidget);
    });

    testWidgets('an empty roster invites adding one', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: []);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      expect(find.text('No customers yet. Add one to get started.'), findsOneWidget);
    });

    testWidgets('tapping a row opens that customer\'s detail screen',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.tap(find.text('Ramesh Kumar'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerDetailScreen), findsOneWidget);
      expect(find.text('Back to Customers'), findsOneWidget);
    });

    testWidgets('the row menu offers Edit and Delete, not just a chevron',
        (tester) async {
      // Customers could only ever be added — this is that gap closing.
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Edit opens pre-filled with the customer\'s own details',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Customer'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Ramesh Kumar'), findsOneWidget);
      expect(find.widgetWithText(TextField, '9711223344'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'ramesh@example.com'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'HBR Layout'), findsOneWidget);
    });

    testWidgets('Edit rejects clearing the required fields', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Ramesh Kumar'), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pump();

      expect(find.text('Name and phone are both required.'), findsOneWidget);
    });

    testWidgets('Delete asks for confirmation naming the customer, and Cancel leaves the roster alone',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Customer'), findsOneWidget);
      expect(find.textContaining('Ramesh Kumar'), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Customer'), findsNothing);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
    });
  });

  group('CustomersScreen responsive layout', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view
        ..physicalSize = Size(width, 1200)
        ..devicePixelRatio = 1.0;
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();
    }

    testWidgets('shows the table header at wide width', (tester) async {
      await pumpAt(tester, 1400);

      expect(find.text('CUSTOMER'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('shows cards instead of the table at phone width',
        (tester) async {
      await pumpAt(tester, 390);

      expect(find.text('CUSTOMER'), findsNothing);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Lifetime'), findsWidgets);
    });

    testWidgets('Add collapses to an icon-only button at phone width',
        (tester) async {
      await pumpAt(tester, 390);

      expect(find.text('Add'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  group('CustomerDetailScreen', () {
    testWidgets('shows the lifetime KPIs and member-since', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(
        provider,
        CustomerDetailScreen(customer: roster.first, onBack: () {}),
      ));
      await tester.pump();

      expect(find.text('Lifetime value'), findsOneWidget);
      expect(find.text('₹1500'), findsOneWidget);
      expect(find.text('Avg order value'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.text('Member since Jul 2026'), findsOneWidget);
    });

    testWidgets('order history lists only this customer\'s orders',
        (tester) async {
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(customers: roster, orders: [
          order(id: 'o1', number: 'WA3P-00001', customerId: 'c1', phone: '9711223344'),
          order(id: 'o2', number: 'WA3P-00002', customerId: 'c2', phone: '9922334455'),
        ]);
      await tester.pumpWidget(host(
        provider,
        CustomerDetailScreen(customer: roster.first, onBack: () {}),
      ));
      await tester.pump();

      expect(find.text('#WA3P-00001'), findsOneWidget);
      expect(find.text('#WA3P-00002'), findsNothing);
    });

    testWidgets('a counter order with no customer FK still matches on phone',
        (tester) async {
      // New Order can bill a walk-in before a customer record exists; those
      // rows carry the phone but no FK.
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(customers: roster, orders: [
          order(id: 'o3', number: 'WA3P-00009', phone: '9711223344'),
        ]);
      await tester.pumpWidget(host(
        provider,
        CustomerDetailScreen(customer: roster.first, onBack: () {}),
      ));
      await tester.pump();

      expect(find.text('#WA3P-00009'), findsOneWidget);
    });

    testWidgets('no orders yields an empty history, not a blank table',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(
        provider,
        CustomerDetailScreen(customer: roster.last, onBack: () {}),
      ));
      await tester.pump();

      expect(find.text('No orders yet for this customer.'), findsOneWidget);
    });

    testWidgets('missing contact fields read as Not provided', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(
        provider,
        CustomerDetailScreen(customer: roster.last, onBack: () {}),
      ));
      await tester.pump();

      // Geeta has no address on file.
      expect(find.text('Not provided'), findsWidgets);
    });

    testWidgets('back returns to the list', (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.tap(find.text('Ramesh Kumar'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDetailScreen), findsOneWidget);

      await tester.tap(find.text('Back to Customers'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDetailScreen), findsNothing);
      expect(find.text('All customers'), findsOneWidget);
    });
  });

  group('CustomerDetailScreen responsive layout', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view
        ..physicalSize = Size(width, 1400)
        ..devicePixelRatio = 1.0;
      final provider = AppProvider(autoLoad: false)
        ..seedForTest(customers: roster, orders: [
          order(id: 'o1', number: 'WA3P-00001', customerId: 'c1'),
        ]);
      await tester.pumpWidget(host(
        provider,
        CustomerDetailScreen(
            customer: roster.first, onBack: () {}, onNewOrder: () {}),
      ));
      await tester.pump();
    }

    testWidgets('shows the breadcrumb and labeled New Order at wide width',
        (tester) async {
      await pumpAt(tester, 1400);

      expect(find.text('Back to Customers'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New Order'), findsOneWidget);
      expect(find.text('ORDER'), findsOneWidget);
    });

    testWidgets(
        'drops the breadcrumb and collapses New Order to an icon at phone width',
        (tester) async {
      await pumpAt(tester, 390);

      expect(find.text('Back to Customers'), findsNothing);
      expect(find.text('New Order'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsWidgets);
      expect(find.text('ORDER'), findsNothing);
      expect(find.text('#WA3P-00001'), findsOneWidget);
    });
  });

  group('CustomersScreen Export', () {
    testWidgets(
        'was a placeholder snackbar — now exports the filtered rows as CSV',
        (tester) async {
      // `flutter test` runs on the VM, not web, so `downloadCsv` resolves to
      // the non-web stub and reports it couldn't trigger a real download —
      // this pins that the button is wired up (builds the CSV, calls the
      // download hook) rather than always showing "Export is not available
      // yet."
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Export'));
      await tester.pump();

      expect(find.text('Export is not available yet.'), findsNothing);
      expect(find.text('Export is only available in the web app.'), findsOneWidget);
    });

    testWidgets('a search matching nobody says so instead of exporting nothing',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Export'));
      await tester.pump();

      expect(find.text('No customers to export.'), findsOneWidget);
    });
  });

  group('CustomersScreen Import', () {
    testWidgets('opens the Import Customers dialog with a file picker step',
        (tester) async {
      final provider = AppProvider(autoLoad: false)..seedForTest(customers: roster);
      await tester.pumpWidget(host(provider, const CustomersScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Import'));
      await tester.pumpAndSettle();

      expect(find.text('Import Customers'), findsOneWidget);
      expect(find.text('Choose File'), findsOneWidget);
      // Only reached once a file has been picked and previewed.
      expect(find.text('Match each field to a column from your file.'),
          findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Import Customers'), findsNothing);
    });
  });
}
