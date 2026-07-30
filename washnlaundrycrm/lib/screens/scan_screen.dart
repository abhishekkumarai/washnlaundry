import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/receipt_dialog.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  int _selectedMode = 0; // 0: Camera, 1: Manual
  final TextEditingController _orderIdController = TextEditingController();

  void _handleSearchOrder(AppProvider provider) {
    final query = _orderIdController.text.trim();
    if (query.isEmpty) return;

    final match = provider.orders.firstWhere(
      (o) => o.orderNumber.toLowerCase() == query.toLowerCase() || o.id.toLowerCase() == query.toLowerCase(),
      orElse: () => provider.orders.isNotEmpty ? provider.orders.first : provider.orders.first,
    );

    showDialog(context: context, builder: (_) => ReceiptDialog(order: match));
  }

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
                // Top Header Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF1A4FD6)),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Scan QR Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Scan any order receipt or tag', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Content View
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 520,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Segmented Mode Control (Camera / Manual)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedMode = 0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _selectedMode == 0 ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: _selectedMode == 0
                                            ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
                                            : [],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.camera_alt_outlined, size: 16, color: _selectedMode == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Camera',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: _selectedMode == 0 ? FontWeight.bold : FontWeight.w500,
                                              color: _selectedMode == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedMode = 1),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _selectedMode == 1 ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: _selectedMode == 1
                                            ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
                                            : [],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.keyboard_outlined, size: 16, color: _selectedMode == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Manual',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: _selectedMode == 1 ? FontWeight.bold : FontWeight.w500,
                                              color: _selectedMode == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Scanner Box Container
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: _selectedMode == 0
                                ? Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEEF2FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.qr_code_scanner_rounded, size: 48, color: Color(0xFF1A4FD6)),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Tap to open the camera and scan a QR code',
                                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (provider.orders.isNotEmpty) {
                                            showDialog(context: context, builder: (_) => ReceiptDialog(order: provider.orders.first));
                                          }
                                        },
                                        icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                                        label: const Text('Open scanner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1A4FD6),
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Order ID (e.g. LB-1001)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _orderIdController,
                                        decoration: InputDecoration(
                                          hintText: 'Enter order number...',
                                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _handleSearchOrder(provider),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1A4FD6),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text('Search', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'Scans a garment/basket tag or accepts a typed order ID, then opens the order.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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
