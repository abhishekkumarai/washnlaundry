import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/google_signin_button.dart';

/// `/login` in the live app. Unauthenticated, so — unlike every other
/// screen — this one is reached *before* `AppProvider`'s shop/order data
/// has any bearing on what's shown.
///
/// The real app renders this first and swaps to `/dashboard` once
/// `onAuthStateChanged` fires (CLAUDE.md's capture notes: "Auth restore is
/// slow (~20-30s)"). [AuthProvider.initializing] is this screen's version of
/// that wait — it covers `attemptLightweightAuthentication`, which silently
/// restores a still-live Google session so a page reload doesn't force
/// today's-already-signed-in owner back through the button.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const _brandBlue = Color(0xFF1A4FD6);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _brandMark(),
                const SizedBox(height: 20),
                _wordmark(),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to manage your shop',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _body(auth),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AuthProvider auth) {
    // `main.dart` never routes here unless AuthProvider.isConfigured, so
    // that state doesn't need handling in this screen.
    if (auth.initializing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (auth.error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              auth.error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ),
        ],
        googleSignInButton(onPressed: auth.authenticate),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('or', style: TextStyle(fontSize: 12, color: _muted)),
            ),
            Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: auth.signInAsDemo,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 18, color: _brandBlue),
            label: const Text(
              'Try Demo Mode',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _brandBlue),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Sign in with your Google account or explore instantly via Demo Mode.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }

  Widget _brandMark() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _brandBlue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.dry_cleaning_rounded, color: Colors.white, size: 32),
      );

  Widget _wordmark() => RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'WashN',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5),
            ),
            TextSpan(
              text: 'Laundry',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _brandBlue, letterSpacing: -0.5),
            ),
          ],
        ),
      );
}
