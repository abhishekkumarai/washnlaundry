import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/top_header.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = [
      {'title': 'Commercial Detergent & Liquid Soap (50L)', 'category': 'Supplies', 'amount': 3500, 'date': '2026-07-28'},
      {'title': 'Monthly Shop Rent (July)', 'category': 'Rent', 'amount': 28000, 'date': '2026-07-01'},
      {'title': 'Steam Iron Boiler Repair', 'category': 'Maintenance', 'amount': 2400, 'date': '2026-07-15'},
      {'title': 'Electricity Bill (Commercial)', 'category': 'Utilities', 'amount': 9450, 'date': '2026-07-20'},
    ];

    double total = expenses.fold(0.0, (sum, e) => sum + (e['amount'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                TopHeader(onNewOrderPressed: () => context.read<AppProvider>().setNavIndex(1)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Expenses Log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                Text('Log shop operational expenses, rent, detergents, & repairs', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Text('Total Expenses: ₹${total.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ListView.separated(
                              itemCount: expenses.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final ex = expenses[idx];
                                return ListTile(
                                  title: Text(ex['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  subtitle: Text('${ex['category']} • ${ex['date']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  trailing: Text('₹${ex['amount']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
