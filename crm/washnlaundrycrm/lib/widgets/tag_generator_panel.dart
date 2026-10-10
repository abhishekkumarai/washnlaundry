import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../utils/tag_code.dart';

/// The "Generate Tags" content for a single, already-chosen order — the
/// real app's Order Placed → Generate Tags modal → Tag Preview modal, each
/// stacked on the last, rebuilt as a two-step *panel* instead. Lives inside
/// the Scan screen's "Generate Tags" tab (an order picker sits above this
/// once an order is chosen) rather than as its own route, so there is only
/// one sidebar destination for "scan a tag or generate one" — see
/// `ScanScreen`.
///
/// [onChangeOrder] returns to that picker; it does not leave the tab.
class TagGeneratorPanel extends StatefulWidget {
  final OrderModel order;
  final VoidCallback? onChangeOrder;
  final VoidCallback? onBackToOrders;

  const TagGeneratorPanel({
    super.key,
    required this.order,
    this.onChangeOrder,
    this.onBackToOrders,
  });

  @override
  State<TagGeneratorPanel> createState() => _TagGeneratorPanelState();
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

class _TagGeneratorPanelState extends State<TagGeneratorPanel> {
  static const _stepConfigure = 0;
  static const _stepPreview = 1;
  static const _stepComplete = 2;

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
  void didUpdateWidget(covariant TagGeneratorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different order picked from the list resets to the first step —
    // otherwise picking a new order while sitting on the preview step would
    // silently keep showing the previous order's generated tags.
    if (oldWidget.order.id != widget.order.id) {
      _step = _stepConfigure;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 16),
        if (_step == _stepConfigure)
          _configureStep()
        else if (_step == _stepPreview)
          _previewStep()
        else
          _completeStep(),
      ],
    );
  }

  Widget _header() {
    final pills = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepPill('1', 'Configure', _step == _stepConfigure, _step > _stepConfigure),
        const Icon(Icons.chevron_right_rounded,
            size: 16, color: Color(0xFFD9D5CB)),
        _stepPill('2', 'Preview', _step == _stepPreview, _step > _stepPreview),
        const Icon(Icons.chevron_right_rounded,
            size: 16, color: Color(0xFFD9D5CB)),
        _stepPill('3', 'Complete', _step == _stepComplete, false),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 540;
        final orderBadge = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EFEA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('#${_order.orderNumber} · ${_order.customerName}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF141A24))),
            ),
            if (widget.onChangeOrder != null)
              TextButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                onPressed: widget.onChangeOrder,
                label: const Text('Change order'),
              ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              orderBadge,
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: pills,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: orderBadge),
            const SizedBox(width: 12),
            pills,
          ],
        );
      },
    );
  }

  Widget _stepPill(String number, String label, bool active, bool done) {
    final colour = active
        ? const Color(0xFF182C4F)
        : (done ? const Color(0xFF16A34A) : const Color(0xFF94A3B8));
    return InkWell(
      onTap: done
          ? () {
              if (number == '1') setState(() => _step = _stepConfigure);
              if (number == '2') setState(() => _step = _stepPreview);
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: done
                  ? const Color(0xFFDCFCE7)
                  : (active ? colour : const Color(0xFFF1EFEA)),
              child: done
                  ? const Icon(Icons.check, size: 12, color: Color(0xFF16A34A))
                  : Text(number,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.white : const Color(0xFF64748B))),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: colour)),
          ],
        ),
      ),
    );
  }

  Widget _configureStep() {
    final counts = _serviceCounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            border: Border.all(color: const Color(0xFFE4E0D8)),
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
                              fontSize: 13, color: Color(0xFF141A24))),
                      Text('×${entry.value}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF182C4F))),
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
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
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
                  side: const BorderSide(color: Color(0xFFE4E0D8)),
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
                  side: const BorderSide(color: Color(0xFFE4E0D8)),
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
                  backgroundColor: const Color(0xFF182C4F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => setState(() => _step = _stepComplete),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Complete'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _completeStep() {
    final tags = _tags;
    final totalGarments =
        _order.items.fold<int>(0, (sum, it) => sum + it.quantity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E0D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tags Ready & Generated',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF141A24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All ${tags.length} labels for order #${_order.orderNumber} have been generated and prepared for thermal printing.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E0D8)),
            ),
            child: Column(
              children: [
                _summaryRow('Order Number', '#${_order.orderNumber}'),
                const Divider(height: 16, color: Color(0xFFE4E0D8)),
                _summaryRow('Customer', '${_order.customerName} (${_order.customerPhone})'),
                const Divider(height: 16, color: Color(0xFFE4E0D8)),
                _summaryRow(
                    'Tagging Mode',
                    _tagType == _TagType.service
                        ? 'Service Tags (${tags.length} labels)'
                        : 'Item Tags ($totalGarments labels)'),
                const Divider(height: 16, color: Color(0xFFE4E0D8)),
                _summaryRow('Label Format',
                    _format == _TagFormat.qr ? 'QR Code (50×60mm)' : 'Barcode'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _step = _stepPreview),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Back to Preview'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Color(0xFFD9D5CB)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _toast('Sent to the printer.'),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Print Again'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Color(0xFF182C4F)),
                    foregroundColor: const Color(0xFF182C4F),
                  ),
                ),
              ),
              if (widget.onBackToOrders != null || widget.onChangeOrder != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onBackToOrders ?? widget.onChangeOrder,
                    icon: const Icon(Icons.list_alt_rounded, size: 16),
                    label: const Text('Back to Orders'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF182C4F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24))),
      ],
    );
  }

  /// The scannable code for [tag]: Code 128 barcode or QR, both carrying the
  /// same `<order number>-<garment no.>` text the Scan screen understands.
  Widget _codeFor(_TagEntry tag) {
    final data = TagCode.encode(_order.orderNumber, tag.index);
    if (_format == _TagFormat.barcode) {
      return BarcodeWidget(
        key: ValueKey('tag-barcode-$data'),
        barcode: Barcode.code128(),
        data: data,
        width: 126,
        height: 56,
        drawText: false,
        errorBuilder: (context, error) => Text('Cannot encode "$data"',
            style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C))),
      );
    }
    return QrImageView(
      key: ValueKey('tag-qr-$data'),
      data: data,
      version: QrVersions.auto,
      size: 100,
    );
  }

  Widget _tagCard(_TagEntry tag, String shopName) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF141A24)),
      ),
      child: Column(
        children: [
          if (shopName.isNotEmpty)
            Text(shopName,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          _codeFor(tag),
          const SizedBox(height: 6),
          Text(tag.label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
          Text('${tag.index}/${tag.total}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(TagCode.encode(_order.orderNumber, tag.index),
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
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? const Color(0xFF182C4F)
                  : const Color(0xFFE4E0D8)),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: selected
                    ? const Color(0xFF182C4F)
                    : const Color(0xFF64748B)),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? const Color(0xFF182C4F)
                        : const Color(0xFF141A24))),
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
