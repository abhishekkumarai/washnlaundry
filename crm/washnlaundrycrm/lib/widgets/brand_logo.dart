import 'package:flutter/material.dart';

/// The WashNLaundry logo — the same mark as the marketing site and the
/// browser-tab icon. Shared by the sidebar and the login screen so the app
/// carries one mark, not a stand-in icon.
///
/// The full badge has a ring of small text, which turns to mush when it is
/// squeezed into a sidebar-sized space. Below [fullBadgeFrom] it shows just
/// the shirt inside the circle (the same crop as the tab icon), which stays
/// legible; at or above it, the full badge.
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, required this.size});

  /// Smallest size at which the badge's ring text is still readable.
  static const fullBadgeFrom = 64.0;

  @override
  Widget build(BuildContext context) {
    final full = size >= fullBadgeFrom;
    return Image.asset(
      full ? 'assets/images/logo.png' : 'assets/images/logo_mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'WashNLaundry',
      // The logo is a bundled asset, so this only matters if it is ever
      // missing from a build: show the old stand-in rather than a broken box.
      errorBuilder: (_, __, ___) => Icon(Icons.dry_cleaning_rounded,
          size: size * 0.7, color: const Color(0xFF182C4F)),
    );
  }
}
