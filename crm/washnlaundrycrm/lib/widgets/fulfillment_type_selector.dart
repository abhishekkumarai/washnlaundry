import 'package:flutter/material.dart';
import '../models/order_model.dart';

/// The order-type cards, shared by New Order's checkout review and the Edit
/// Order dialog so both offer the same choices.
///
/// [DeliveryType.selectable] decides which of [_tiles] are offered; this file
/// only holds how each one looks. Existing orders of a type that is no longer
/// selectable (Home delivery) still load and show everywhere else.
class FulfillmentTypeSelector extends StatelessWidget {
  static const _tiles = [
    (DeliveryType.storePickup, 'Shop pickup', "You'll pick up",
        Icons.storefront_outlined),
    (DeliveryType.homePickup, 'Home pickup', "We'll pick up",
        Icons.local_shipping_outlined),
    (DeliveryType.homeDelivery, 'Home delivery', "We'll deliver",
        Icons.home_outlined),
  ];

  static final options = [
    for (final t in _tiles)
      if (DeliveryType.selectable.contains(t.$1)) t,
  ];

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _brand = Color(0xFF1A4FD6);

  final String value;
  final ValueChanged<String> onChanged;

  /// Narrows [options] to these types (e.g. a self-service customer can only
  /// book a pickup). Null shows them all.
  final Set<String>? only;

  const FulfillmentTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.only,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final t in options)
        if (only == null || only!.contains(t.$1)) t,
    ];
    // An order saved with a type that is no longer offered (Home delivery,
    // Online) must still show as selected when edited, not as a blank choice
    // that looks like it is about to be changed.
    if (!options.any((t) => t.$1 == value)) {
      tiles.add((value, DeliveryType.label(value), 'Current',
          Icons.home_outlined));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, t) in tiles.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _tile(t.$1, t.$2, t.$3, t.$4)),
        ],
      ],
    );
  }

  Widget _tile(String type, String label, String subtitle, IconData icon) {
    final isSel = value == type;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: isSel ? _brand : _line, width: isSel ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: isSel ? _brand : _muted),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSel ? _brand : _ink)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _muted)),
          ],
        ),
      ),
    );
  }
}
