import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/top_header.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  DateTime _selectedMonth = DateTime(2026, 7);

  final List<Map<String, dynamic>> _staffPayroll = [
    {
      'name': 'Ramesh Kumar',
      'role': 'Head Washer & Cleaner',
      'dailyWage': 650.0,
      'daysWorked': 24,
      'totalSalary': 15600.0,
      'paidAmount': 10000.0,
      'pendingAmount': 5600.0,
      'status': 'PARTIAL',
    },
    {
      'name': 'Sunil Paswan',
      'role': 'Steam Press Master',
      'dailyWage': 600.0,
      'daysWorked': 26,
      'totalSalary': 15600.0,
      'paidAmount': 15600.0,
      'pendingAmount': 0.0,
      'status': 'PAID',
    },
    {
      'name': 'Vikram Singh',
      'role': 'Delivery Agent',
      'dailyWage': 550.0,
      'daysWorked': 22,
      'totalSalary': 12100.0,
      'paidAmount': 0.0,
      'pendingAmount': 12100.0,
      'status': 'UNPAID',
    },
  ];

  @override
  Widget build(BuildContext context) {
    double totalPayroll = _staffPayroll.fold(0.0, (sum, s) => sum + s['totalSalary']);
    double totalPaid = _staffPayroll.fold(0.0, (sum, s) => sum + s['paidAmount']);
    double totalPending = _staffPayroll.fold(0.0, (sum, s) => sum + s['pendingAmount']);

    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final currentMonthStr = '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Title & Month Selector Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Payroll', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                Text('Calculate staff wages, attendance payout, and salary records', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              ],
                            ),

                            // Month Navigation
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                                      });
                                    },
                                  ),
                                  Text(
                                    currentMonthStr,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 4 Summary KPI Cards
                        Row(
                          children: [
                            _buildSummaryCard('Total Payroll', '₹${totalPayroll.toInt()}', const Color(0xFF1A4FD6), const Color(0xFFEEF2FF)),
                            const SizedBox(width: 12),
                            _buildSummaryCard('Paid', '₹${totalPaid.toInt()}', const Color(0xFF10B981), const Color(0xFFECFDF5)),
                            const SizedBox(width: 12),
                            _buildSummaryCard('Pending Balance', '₹${totalPending.toInt()}', const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
                            const SizedBox(width: 12),
                            _buildSummaryCard('Staff Count', '${_staffPayroll.length}', const Color(0xFFA855F7), const Color(0xFFF3E8FF)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Monthly Payroll Table
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$currentMonthStr Payroll Records',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 16),

                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _staffPayroll.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final s = _staffPayroll[idx];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: const Color(0xFFEEF2FF),
                                              child: Text(
                                                s['name'][0],
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(s['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                Text('${s['role']} • ₹${s['dailyWage'].toInt()}/day', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                              ],
                                            ),
                                          ],
                                        ),

                                        Row(
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('₹${s['totalSalary'].toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                Text('Days worked: ${s['daysWorked']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                              ],
                                            ),
                                            const SizedBox(width: 20),

                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: s['status'] == 'PAID' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                s['status'],
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: s['status'] == 'PAID' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
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

  Widget _buildSummaryCard(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
