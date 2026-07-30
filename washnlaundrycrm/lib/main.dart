import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/new_order_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/services_screen.dart';
import 'screens/staff_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/payroll_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const WashNLaundryCrmApp(),
    ),
  );
}

class WashNLaundryCrmApp extends StatelessWidget {
  const WashNLaundryCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WashNLaundry CRM - Professional Laundry & Dry Cleaning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A4FD6),
          primary: const Color(0xFF1A4FD6),
          surface: const Color(0xFFF8FAFC),
        ),
        textTheme: GoogleFonts.ibmPlexSansTextTheme(
          Theme.of(context).textTheme,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: Consumer<AppProvider>(
        builder: (context, provider, _) {
          switch (provider.currentNavIndex) {
            case 0:  return const DashboardScreen();
            case 1:  return const NewOrderScreen();
            case 2:  return const OrdersScreen();
            case 3:  return const CustomersScreen();
            case 4:  return const ServicesScreen();
            case 5:  return const StaffScreen();
            case 6:  return const AttendanceScreen();
            case 7:  return const PayrollScreen();
            case 8:  return const ExpensesScreen();
            case 9:  return const ReportsScreen();
            // 10 = Apps   (disabled — no screen)
            case 11: return const ScanScreen();
            // 12 = Subscription (disabled — no screen)
            case 13: return const SettingsScreen();
            default: return const DashboardScreen();
          }
        },
      ),
    );
  }
}
