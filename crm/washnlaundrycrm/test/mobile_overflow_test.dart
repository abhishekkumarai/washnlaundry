import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/attendance_screen.dart';
import 'package:washnlaundrycrm/screens/credits_screen.dart';
import 'package:washnlaundrycrm/screens/customer_detail_screen.dart';
import 'package:washnlaundrycrm/screens/customers_screen.dart';
import 'package:washnlaundrycrm/screens/dashboard_screen.dart';
import 'package:washnlaundrycrm/screens/expenses_screen.dart';
import 'package:washnlaundrycrm/screens/new_order_screen.dart';
import 'package:washnlaundrycrm/screens/order_detail_screen.dart';
import 'package:washnlaundrycrm/screens/orders_screen.dart';
import 'package:washnlaundrycrm/screens/payroll_screen.dart';
import 'package:washnlaundrycrm/screens/reports_screen.dart';
import 'package:washnlaundrycrm/screens/scan_screen.dart';
import 'package:washnlaundrycrm/screens/services_screen.dart';
import 'package:washnlaundrycrm/screens/settings_screen.dart';
import 'package:washnlaundrycrm/screens/social_suite_screen.dart';
import 'package:washnlaundrycrm/screens/staff_screen.dart';
import 'package:washnlaundrycrm/widgets/app_shell.dart';
import 'package:washnlaundrycrm/widgets/shop_onboarding_dialog.dart';

import 'package:provider/provider.dart';
import 'package:washnlaundrycrm/providers/auth_provider.dart';
import 'support/router_test_utils.dart';

Widget host(AppProvider provider, Widget child, {AuthProvider? auth}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth ?? AuthProvider(),
    child: hostWithRouter(
      provider,
      Scaffold(
        drawer: const AppDrawer(),
        body: AppShell(body: child),
      ),
    ),
  );
}

void main() {
  final testOrder = OrderModel(
    id: 'ord-1',
    orderNumber: 'WASH-1001',
    customerName: 'Priya Sundaram',
    customerPhone: '9876543210',
    status: OrderStatus.processing,
    paymentStatus: PaymentStatus.partial,
    paymentMethod: 'CASH',
    totalAmount: 1250,
    paidAmount: 500,
    dueAmount: 750,
    express: true,
    createdAt: DateTime.now(),
    items: const [
      OrderItemModel(
        itemTitle: 'Cotton Shirt',
        serviceType: 'Wash & Iron',
        quantity: 3,
        unitPrice: 80,
        totalPrice: 240,
      ),
    ],
  );

  const testCustomer = CustomerModel(
    id: 'cust-1',
    name: 'Priya Sundaram',
    phone: '9876543210',
    email: 'priya@example.com',
    address: '123 Park Street, Patna',
    totalOrders: 5,
    totalSpent: 4200,
    dueAmount: 750,
  );

  const testStaff = StaffModel(
    id: 'st-1',
    name: 'Ramesh Kumar',
    role: 'Head Washer',
    phone: '9876543211',
    monthlyWage: 18000,
    hasAppLogin: true,
    status: 'ACTIVE',
  );

  final testExpense = ExpenseModel(
    id: 'exp-1',
    title: 'Detergent 25kg Drum',
    amount: 3200,
    category: 'Supplies',
    date: DateTime.now(),
  );

  const testGarment = GarmentItemModel(
    id: 'g-1',
    categoryId: 'cat-1',
    categoryName: 'Men',
    name: 'Cotton Shirt',
    price: 80,
  );

  const testCategory = GarmentCategoryModel(
    id: 'cat-1',
    name: 'Men',
    icon: 'man',
  );

  AppProvider createSeededProvider() {
    return AppProvider(autoLoad: false)
      ..seedForTest(
        orders: [testOrder],
        customers: [testCustomer],
        staff: [testStaff],
        expenses: [testExpense],
        garments: [testGarment],
        categories: [testCategory],
        shop: {
          'id': 1,
          'name': 'Wash & Laundry Patna',
          'phone': '9876543210',
          'address': 'Boring Road, Patna',
          'currency_symbol': '₹',
        },
        meta: const MetaModel(),
      );
  }

  const mobileSizes = [
    Size(360, 780),
    Size(375, 812),
    Size(390, 844),
  ];

  for (final size in mobileSizes) {
    group('Mobile viewport ${size.width}x${size.height}', () {
      setUp(() {
        final view = TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .implicitView!;
        view.physicalSize = size;
        view.devicePixelRatio = 1.0;
      });

      tearDown(() {
        final view = TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .implicitView!;
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      testWidgets('DashboardScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const DashboardScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('OrdersScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const OrdersScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('OrderDetailScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(
          host(provider, OrderDetailScreen(order: testOrder, onBack: () {})),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('NewOrderScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const NewOrderScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('CustomersScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const CustomersScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('CustomerDetailScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(
          host(provider, CustomerDetailScreen(customer: testCustomer, onBack: () {})),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('ServicesScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const ServicesScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('SettingsScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const SettingsScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('StaffScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const StaffScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('AttendanceScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const AttendanceScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('ExpensesScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const ExpensesScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('CreditsScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const CreditsScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('PayrollScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const PayrollScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('ReportsScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const ReportsScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('ScanScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const ScanScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('SocialSuiteScreen renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(host(provider, const SocialSuiteScreen()));
        await tester.pumpAndSettle();
      });

      testWidgets('ShopOnboardingDialog renders without overflow', (tester) async {
        final provider = createSeededProvider();
        await tester.pumpWidget(
          hostWithRouter(
            provider,
            const Scaffold(body: ShopOnboardingDialog()),
          ),
        );
        await tester.pumpAndSettle();
      });
    });
  }
}
