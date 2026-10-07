import 'package:flutter/material.dart';

/// The WashNLaundry badge — the same logo as the marketing site and the
/// browser-tab icon. Shared by the sidebar and the login screen so the app
/// carries one mark, not a stand-in icon.
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
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
