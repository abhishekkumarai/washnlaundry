import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../widgets/app_shell.dart';

/// `/orders/:id/tags` — the real app's "Print Tags" flow (Order Placed →
/// Generate Tags modal → Tag Preview modal, each stacked on the last) built
/// as its own two-step *route* instead. Captured live on 2026-09-17 by
/// placing a real 2-item order and stepping through it — see the Jira issue
/// this screen closes out for the walkthrough. Cancel/Back pop to the order
/// detail page rather than closing a dialog, since there is no dialog here.
///
/// [onBack] is injected rather than calling `context.go` directly — same
/// shape as [OrderDetailScreen]'s `onBack`, so a widget test can pump this
/// screen standalone without a real `GoRouter` in the tree.
class TagGenerationScreen extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onBack;

  const TagGenerationScreen({super.key, required this.order, required this.onBack});

  @override
  State<TagGenerationScreen> createState() => _TagGenerationScreenState();
}

class _TagFormat {
  static const qr = 'QR';
  static const barcode = 'BARCODE';
}

class _TagType {
  static const service = 'SERVICE';
  static const item = 'ITEM';
}

/// One physical label to print. [index]/[total] is "this tag" out of however
/// many the chosen [_TagType] produces — 1-of-N for Service Tags (one per
/// distinct service), or 1-of-(every garment) for Item Tags.
class _TagEntry {
  final String label;
  final int index;
  final int total;

  const _TagEntry({required this.label, required this.index, required this.total});
}

class _TagGenerationScreenState extends State<TagGenerationScreen> {
  static const _stepConfigure = 0;
  static const _stepPreview = 1;

  int _step = _stepConfigure;
  String _format = _TagFormat.qr;
  String _tagType = _TagType.service;

  OrderModel get _order => widget.order;

  /// Service label -> total garments in the order under that service. A
  /// service with no `serviceType` recorded falls back to "Service" rather
  /// than an empty chip.
  Map<String, int> get _serviceCounts {
    final counts = <String, int>{};
    for (final item in _order.items) {
      final label = item.serviceType.trim().isEmpty ? 'Service' : item.serviceType;
      counts[label] = (counts[label] ?? 0) + item.quantity;
    }
    return counts;
  }

  List<_TagEntry> get _tags {
    if (_tagType == _TagType.item) {
      final total = _order.items.fold<int>(0, (sum, it) => sum + it.quantity);
      final entries = <_TagEntry>[];
      var i = 0;
      for (final item in _order.items) {
        final label = item.serviceType.trim().isEmpty ? item.itemTitle : item.serviceType;
        for (var q = 0; q < item.quantity; q++) {
          i++;
          entries.add(_TagEntry(label: label, index: i, total: total));
        }
      }
      return entries;
    }

    final services = _serviceCounts.keys.toList();
    return [
      for (var i = 0; i < services.length; i++)
        _TagEntry(label: services[i], index: i + 1, total: services.length),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: AppShell(
        body: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _step == _stepConfigure ? _configureStep() : _previewStep(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _step == _stepPreview
                ? () => setState(() => _step = _stepConfigure)
                : widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Text('Generate Tags',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const Spacer(),
          _stepPill('1', 'Configure', _step == _stepConfigure),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: Color(0xFFCBD5E1)),
          _stepPill('2', 'Preview', _step == _stepPreview),
        ],
      ),
    );
  }

  Widget _stepPill(String number, String label, bool active) {
    final colour = active ? const Color(0xFF1A4FD6) : const Color(0xFF94A3B8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: active ? colour : const Color(0xFFF1F5F9),
          child: Text(number,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : const Color(0xFF64748B))),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: colour)),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _configureStep() {
    final counts = _serviceCounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _sectionLabel('Format'),
        Row(
          children: [
            Expanded(
              child: _optionCard(
                icon: Icons.qr_code_rounded,
                title: 'QR code',
                selected: _format == _TagFormat.qr,
                onTap: () => setState(() => _format = _TagFormat.qr),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _optionCard(
                icon: Icons.view_week_rounded,
                title: 'Barcode',
                selected: _format == _TagFormat.barcode,
                onTap: () => setState(() => _format = _TagFormat.barcode),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('Tag type'),
        Row(
          children: [
            Expanded(
              child: _optionCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Service Tags',
                subtitle:
                    '${_serviceCounts.length} tag${_serviceCounts.length == 1 ? '' : 's'} · one per service',
                selected: _tagType == _TagType.service,
                onTap: () => setState(() => _tagType = _TagType.service),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _optionCard(
                icon: Icons.sell_outlined,
                title: 'Item Tags',
                subtitle:
                    '${_order.items.fold<int>(0, (s, it) => s + it.quantity)} tags (one per garment)',
                selected: _tagType == _TagType.item,
                onTap: () => setState(() => _tagType = _TagType.item),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SERVICES IN THIS ORDER',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.4)),
              const SizedBox(height: 8),
              for (final entry in counts.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF0F172A))),
                      Text('×${entry.value}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A4FD6))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Labels are exported as a PDF at 50mm × 60mm (one tag per page) — '
          'print at exact size from your label printer app.',
          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _infoRow('Order', '#${_order.orderNumber}'),
              _infoRow('Customer', _order.customerName),
              _infoRow('Items',
                  '${_order.items.fold<int>(0, (s, it) => s + it.quantity)}'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(() => _step = _stepPreview),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Generate Preview'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _previewStep() {
    final shopName = (context.watch<AppProvider>().shop?['name'] as String?)
            ?.trim() ??
        '';
    final tags = _tags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (_format == _TagFormat.barcode)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'Barcode format is not available in this demo — showing QR '
              'code tags instead.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final tag in tags) _tagCard(tag, shopName),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('${tags.length} tag${tags.length == 1 ? '' : 's'} · 50mm × 60mm each',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = _stepConfigure),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _toast('PDF export is not available in this demo.'),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download PDF'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _toast('Sent to the printer.'),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Print'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _tagCard(_TagEntry tag, String shopName) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0F172A)),
      ),
      child: Column(
        children: [
          if (shopName.isNotEmpty)
            Text(shopName,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          QrImageView(
            data: 'https://app.laundrybill.com/track/${_order.orderNumber}',
            version: QrVersions.auto,
            size: 100,
          ),
          const SizedBox(height: 6),
          Text(tag.label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          Text('${tag.index}/${tag.total}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text('#${_order.orderNumber}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          Text(_order.customerName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569))),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
            ),
          ],
        ),
      );

  Widget _optionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF4FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? const Color(0xFF1A4FD6)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: selected
                    ? const Color(0xFF1A4FD6)
                    : const Color(0xFF64748B)),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? const Color(0xFF1A4FD6)
                        : const Color(0xFF0F172A))),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
