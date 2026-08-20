import 'package:flutter/material.dart';

import '../utils/money.dart';

/// Shared chrome for the dashboard panels: white surface, hairline border,
/// optional title/subtitle row with a trailing action.
class PanelCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PanelCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Renders a percentage, or an em dash when the metric has no data yet.
/// "—" and "0%" mean very different things on this dashboard.
String formatPercent(dynamic value) =>
    value == null ? '—' : '${(value as num).toStringAsFixed(value % 1 == 0 ? 0 : 1)}%';

/// Formats an amount in the shop's currency, grouped ("₹4,850") to match
/// Reports — the symbol used to be a bare '₹' here and in a dozen other
/// widgets; it now comes from the shop record via [Money].
String formatRupees(dynamic value) => Money.grouped(value as num?);

/// Avatar initials for a person or shop name — "AK" for "AK", "RK" for
/// "Ramesh Kumar", "?" when the shop hasn't loaded yet. Shared so the sidebar,
/// the header and Settings can't drift apart.
String initialsFor(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    // A single word gives up to two letters: "AK" stays "AK".
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

/// A small labelled statistic used across the side panels.
class StatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String? caption;
  final String value;
  final Color valueColor;

  const StatRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    this.caption,
    required this.value,
    this.valueColor = const Color(0xFF0F172A),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: iconBackground.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
