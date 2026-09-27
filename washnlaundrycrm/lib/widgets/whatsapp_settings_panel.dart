import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';

class WhatsAppSettingsPanel extends StatefulWidget {
  const WhatsAppSettingsPanel({Key? key}) : super(key: key);

  @override
  State<WhatsAppSettingsPanel> createState() => _WhatsAppSettingsPanelState();
}

class _WhatsAppSettingsPanelState extends State<WhatsAppSettingsPanel> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _qrData;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status = await ApiService.fetchWhatsAppStatus();
      Map<String, dynamic>? qr;
      if (status['status'] == 'qr_ready' || status['status'] == 'disconnected') {
        try {
          qr = await ApiService.fetchWhatsAppQr();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _status = status;
          _qrData = qr;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    final isDryRun = _status?['dry_run'] == true;
    final connState = _status?['status'] as String? ?? 'offline';
    final user = _status?['user'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Refresh
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'WhatsApp Integration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Automated WhatsApp billing, order status alerts, and staff payroll slips',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _loadStatus,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A4FD6),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Dry Run banner if active
        if (isDryRun)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Safe Dry-Run Mode is Active: Outbound messages are recorded safely in server logs without triggering real WhatsApp socket sends.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),

        // Connection State Card
        _buildStateCard(connState, user),
        const SizedBox(height: 24),

        // Pairing Section (if QR available)
        if (connState == 'qr_ready' || _qrData?['qr'] != null || _qrData?['qr_data_url'] != null)
          _buildPairingSection()
        else if (connState != 'connected')
          _buildOfflineHelp(),

        const SizedBox(height: 24),
        // Features list
        _buildFeaturesOverview(),
      ],
    );
  }

  Widget _buildStateCard(String state, Map<String, dynamic>? user) {
    Color bg;
    Color border;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    switch (state) {
      case 'connected':
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFFBBF7D0);
        iconColor = const Color(0xFF16A34A);
        icon = Icons.check_circle_rounded;
        title = 'Connected to WhatsApp';
        subtitle = user != null && user['id'] != null
            ? 'Store phone paired: ${user['id']}'
            : 'Multi-device bridge session active and ready.';
        break;
      case 'qr_ready':
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        iconColor = const Color(0xFFD97706);
        icon = Icons.qr_code_scanner_rounded;
        title = 'Action Required: Scan QR Code';
        subtitle = 'Link your store WhatsApp number to enable automated message delivery.';
        break;
      default:
        bg = const Color(0xFFF8FAFC);
        border = const Color(0xFFE2E8F0);
        iconColor = const Color(0xFF64748B);
        icon = Icons.cloud_off_rounded;
        title = 'Bridge Disconnected';
        subtitle = _error ?? 'WhatsApp Bridge service is currently disconnected or in standby.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingSection() {
    final qrString = _qrData?['qr'] as String?;
    final qrDataUrl = _qrData?['qr_data_url'] as String?;

    Widget qrWidget;
    if (qrDataUrl != null && qrDataUrl.startsWith('data:image')) {
      final base64String = qrDataUrl.split(',').last;
      qrWidget = Image.memory(
        base64Decode(base64String),
        width: 180,
        height: 180,
      );
    } else if (qrString != null && qrString.isNotEmpty) {
      qrWidget = QrImageView(
        data: qrString,
        version: QrVersions.auto,
        size: 180,
      );
    } else {
      qrWidget = Container(
        width: 180,
        height: 180,
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Text('Generating QR...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // QR Image Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: qrWidget,
          ),
          const SizedBox(width: 24),
          // Steps
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to Connect Your Device',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                _pairingStep('1', 'Open WhatsApp on your store phone.'),
                _pairingStep('2', 'Go to Settings (or Menu ⋮) > Linked Devices.'),
                _pairingStep('3', 'Tap "Link a Device" and scan the QR code on the left.'),
                const SizedBox(height: 14),
                const Text(
                  'Session credentials are encrypted and stored in your dedicated session volume.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pairingStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF10B981),
            child: Text(
              num,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineHelp() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'WhatsApp Microservice Status',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          SizedBox(height: 6),
          Text(
            'The Baileys bridge microservice runs as a Docker container sidecar (port 3000) or local daemon. '
            'In dry-run mode, order receipts and status updates simulate instantly so billing workflows remain active even before a physical phone is paired.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesOverview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Automated Messaging Capabilities',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          _featureRow(Icons.receipt_long_rounded, 'POS & Order Receipts',
              'Sends branded, itemized bills with totals, payments, and real-time tracking links.'),
          _featureRow(Icons.notifications_active_rounded, 'Live Status Transitions',
              'Notifies customers when clothes move between Placed, Washing, Ready, and Out for Delivery.'),
          _featureRow(Icons.payments_rounded, 'Staff Salary Slips',
              'Dispatches monthly breakdown of days worked, base wage, and net pay to employee phones.'),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF10B981)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
