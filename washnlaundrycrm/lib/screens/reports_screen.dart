import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_navigation.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedPeriod = 0; // 0: This Month, 1: Last Month, 2: Custom
  DateTimeRange _customDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A4FD6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodText = _selectedPeriod == 0
        ? 'July 2026'
        : _selectedPeriod == 1
            ? 'June 2026'
            : '${DateFormat('dd MMM').format(_customDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_customDateRange.end)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Financial Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text(periodText, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                      const Spacer(),

                      // Period Selector Buttons
                      _buildPeriodButton(0, 'This Month'),
                      const SizedBox(width: 8),
                      _buildPeriodButton(1, 'Last Month'),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _pickCustomDateRange(context),
                        icon: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF475569)),
                        label: Text(
                          _selectedPeriod == 2 ? periodText : 'Custom',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedPeriod == 2 ? const Color(0xFF1A4FD6) : const Color(0xFF334155),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _selectedPeriod == 2 ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
                          backgroundColor: _selectedPeriod == 2 ? const Color(0xFFEEF2FF) : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Action Buttons
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.print_outlined, size: 15, color: Color(0xFF475569)),
                        label: const Text('Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download_rounded, size: 15, color: Colors.white),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A4FD6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row of 6 Financial Summary Cards
                        Row(
                          children: [
                            Expanded(child: _buildMetricCard('Revenue', '₹4,850', '▲ 12% vs last month', Icons.trending_up_rounded, const Color(0xFF1A4FD6), const Color(0xFFEEF2FF))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMetricCard('Collected', '₹3,900', '80% of billed', Icons.payments_outlined, const Color(0xFF10B981), const Color(0xFFECFDF5))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMetricCard('Outstanding', '₹950', 'to collect', Icons.hourglass_empty_rounded, const Color(0xFFF59E0B), const Color(0xFFFEF3C7))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMetricCard('Expenses', '₹1,200', 'incl. supplies', Icons.receipt_long_outlined, const Color(0xFFEF4444), const Color(0xFFFEF2F2))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMetricCard('Net Profit', '₹3,650', '75% margin', Icons.account_balance_wallet_outlined, const Color(0xFF10B981), const Color(0xFFECFDF5))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMetricCard('Orders', '15', 'avg ₹323', Icons.shopping_bag_outlined, const Color(0xFFA855F7), const Color(0xFFF3E8FF))),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Middle Section: Revenue vs Expenses Chart & Net Profit Margin Card
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Revenue vs Expenses Bar Chart Box
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(Icons.show_chart_rounded, size: 18, color: Color(0xFF1A4FD6)),
                                        ),
                                        const SizedBox(width: 12),
                                        const Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Revenue vs Expenses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                            Text('Last 8 months', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                          ],
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF1A4FD6), borderRadius: BorderRadius.circular(2))),
                                            const SizedBox(width: 4),
                                            const Text('Revenue', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                            const SizedBox(width: 14),
                                            Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(2))),
                                            const SizedBox(width: 4),
                                            const Text('Expenses', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 30),

                                    // Bar Chart Visual Frame
                                    SizedBox(
                                      height: 180,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _buildBarPair('Dec', 0.25, 0.15),
                                          _buildBarPair('Jan', 0.35, 0.20),
                                          _buildBarPair('Feb', 0.40, 0.25),
                                          _buildBarPair('Mar', 0.50, 0.30),
                                          _buildBarPair('Apr', 0.60, 0.35),
                                          _buildBarPair('May', 0.70, 0.40),
                                          _buildBarPair('Jun', 0.85, 0.45),
                                          _buildBarPair('Jul', 1.00, 0.30),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Net Profit Gauge Container
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 290,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Net Profit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    const Spacer(),
                                    Center(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 140,
                                            height: 140,
                                            child: CircularProgressIndicator(
                                              value: 0.75,
                                              strokeWidth: 14,
                                              backgroundColor: const Color(0xFFF1F5F9),
                                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                            ),
                                          ),
                                          const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('75%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                                              Text('margin', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    const Center(
                                      child: Column(
                                        children: [
                                          Text('₹3,650', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                          Text('▲ 15% vs last month', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Bottom Section: Orders breakdown & Payments mix
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Orders Breakdown
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(Icons.list_alt_rounded, size: 18, color: Color(0xFF1A4FD6)),
                                        ),
                                        const SizedBox(width: 12),
                                        const Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Orders breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                            Text('15 orders in this period', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('BY STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                              const SizedBox(height: 10),
                                              _buildStatusRow('Delivered', '6', const Color(0xFF10B981)),
                                              _buildStatusRow('Washing', '3', const Color(0xFF1A4FD6)),
                                              _buildStatusRow('Ready', '3', const Color(0xFF0284C7)),
                                              _buildStatusRow('Pending', '2', const Color(0xFFF59E0B)),
                                              _buildStatusRow('Overdue', '1', const Color(0xFFEF4444)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('BY TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                              const SizedBox(height: 10),
                                              _buildStatusRow('Home delivery', '10', const Color(0xFF1A4FD6)),
                                              _buildStatusRow('Store pickup', '5', const Color(0xFFA855F7)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('BY SERVICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                              const SizedBox(height: 10),
                                              _buildStatusRow('Ironing', '7', const Color(0xFF1A4FD6)),
                                              _buildStatusRow('Wash & Iron', '4', const Color(0xFFD97706)),
                                              _buildStatusRow('Dry Cleaning', '3', const Color(0xFF7C3AED)),
                                              _buildStatusRow('Wash & Fold', '1', const Color(0xFF0284C7)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Payments Mix
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(Icons.credit_card_rounded, size: 18, color: Color(0xFF1A4FD6)),
                                        ),
                                        const SizedBox(width: 12),
                                        const Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Payments mix', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                            Text('Collected by method', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _buildPaymentMethodRow('UPI / QR Code', '₹2,650', '68%', const Color(0xFF1A4FD6)),
                                    const SizedBox(height: 12),
                                    _buildPaymentMethodRow('Cash', '₹920', '24%', const Color(0xFF10B981)),
                                    const SizedBox(height: 12),
                                    _buildPaymentMethodRow('Card / POS', '₹330', '8%', const Color(0xFFA855F7)),
                                  ],
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildPeriodButton(int idx, String title) {
    final isSel = _selectedPeriod == idx;
    return OutlinedButton(
      onPressed: () => setState(() => _selectedPeriod = idx),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
        backgroundColor: isSel ? const Color(0xFFEEF2FF) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
          color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, String sub, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBarPair(String month, double revRatio, double expRatio) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 12,
              height: 120 * revRatio,
              decoration: const BoxDecoration(
                color: Color(0xFF1A4FD6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              height: 120 * expRatio,
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(month, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildStatusRow(String label, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
          Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(String method, String amount, String pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(method, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
            Text('$amount ($pct)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: double.parse(pct.replaceAll('%', '')) / 100,
          backgroundColor: const Color(0xFFF1F5F9),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
