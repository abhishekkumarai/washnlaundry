import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/top_header.dart';
import '../widgets/quick_scan_card.dart';
import '../widgets/kpi_cards_row.dart';
import '../widgets/revenue_chart_card.dart';
import '../widgets/order_pipeline_card.dart';
import '../widgets/new_order_dialog.dart';
import '../widgets/receipt_dialog.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),

          Expanded(
            child: Column(
              children: [
                TopHeader(
                  onNewOrderPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const NewOrderDialog(),
                    );
                  },
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const QuickScanCard(),
                        const SizedBox(height: 20),
                        const KpiCardsRow(),
                        const SizedBox(height: 20),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth > 900;
                            if (isDesktop) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Expanded(flex: 7, child: RevenueChartCard()),
                                  SizedBox(width: 20),
                                  Expanded(flex: 5, child: OrderPipelineCard()),
                                ],
                              );
                            }
                            return Column(
                              children: const [
                                RevenueChartCard(),
                                SizedBox(height: 20),
                                OrderPipelineCard(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Recent Customer Orders',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => const NewOrderDialog(),
                                      );
                                    },
                                    child: const Text('+ New Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (provider.filteredOrders.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Center(child: Text('No orders found matching search criteria', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: provider.filteredOrders.length,
                                  itemBuilder: (context, index) {
                                    final order = provider.filteredOrders[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEEF2FF),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text('#${order.orderNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(order.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                  Text(order.customerPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text('₹${order.totalAmount.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                              const SizedBox(width: 12),
                                              IconButton(
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => ReceiptDialog(order: order),
                                                  );
                                                },
                                                icon: const Icon(Icons.receipt_outlined, color: Color(0xFF1A4FD6), size: 20),
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
}
