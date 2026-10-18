import 'package:flutter/material.dart';

/// A garment's icon and colour, shown where the catalogue has no photo.
class ItemArt {
  final IconData icon;
  final Color color;
  const ItemArt(this.icon, this.color);
}

/// Stand-in for the live app's product photography. Known garments get a
/// hand-picked icon; anything else falls back to a stable pick derived from
/// the name, so a given item always looks the same.
ItemArt itemArtFor(String name) {
  const known = <String, ItemArt>{
    'shirt': ItemArt(Icons.dry_cleaning_rounded, Color(0xFF3B82F6)),
    't-shirt': ItemArt(Icons.checkroom_rounded, Color(0xFFF97316)),
    'kurta': ItemArt(Icons.strikethrough_s_rounded, Color(0xFF06B6D4)),
    'pant':
        ItemArt(Icons.airline_seat_legroom_extra_rounded, Color(0xFFD97706)),
    'jeans': ItemArt(Icons.checkroom_outlined, Color(0xFF2563EB)),
    'shorts': ItemArt(Icons.dry_cleaning_outlined, Color(0xFF10B981)),
    'saree': ItemArt(Icons.woman_rounded, Color(0xFFEC4899)),
    'blazer': ItemArt(Icons.business_center_rounded, Color(0xFF64748B)),
    'curtain': ItemArt(Icons.curtains_rounded, Color(0xFF2563EB)),
    'blanket': ItemArt(Icons.bed_rounded, Color(0xFF0EA5E9)),
    'carpet': ItemArt(Icons.texture_rounded, Color(0xFFA16207)),
    'shoe': ItemArt(Icons.ice_skating_rounded, Color(0xFF14B8A6)),
  };

  final lower = name.toLowerCase();
  for (final entry in known.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }

  const fallbackIcons = [
    Icons.checkroom_rounded,
    Icons.dry_cleaning_rounded,
    Icons.local_laundry_service_rounded,
    Icons.woman_rounded,
    Icons.business_center_rounded,
  ];
  const fallbackColors = [
    Color(0xFF3B82F6),
    Color(0xFFF97316),
    Color(0xFF10B981),
    Color(0xFFEC4899),
    Color(0xFF2563EB),
    Color(0xFF06B6D4),
  ];
  final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
  return ItemArt(
    fallbackIcons[hash % fallbackIcons.length],
    fallbackColors[hash % fallbackColors.length],
  );
}
