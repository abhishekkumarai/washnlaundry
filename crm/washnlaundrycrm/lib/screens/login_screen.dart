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
///
/// Card layout below mirrors the real `app.laundrybill.com/login`, minus its
/// "Continue with Apple" button. Email / Password and the Sign In / Create
/// Account tabs are real (api/password_auth.py): creating an account emails a
/// confirmation link, and "Forgot password?" emails a reset link. Google
/// sign-in works alongside. "Sign in with mobile number instead" is layout
/// parity only. Demo Mode stays available (see `_allowDemo`).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _brandBlue = Color(0xFF1A4FD6);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _disabled = Color(0xFFCBD5E1);

  int _authTab = 0; // 0: Sign In, 1: Create Account
  bool _obscurePassword = true;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _formError;
  String? _formNotice;

  /// Demo Mode (a one-tap owner session with no checks) is part of the product
  /// and stays on in every build. A build can hide it with
  /// --dart-define=ALLOW_DEMO=false.
  static const _allowDemo = bool.fromEnvironment('ALLOW_DEMO', defaultValue: true);
  static bool get _showDemo => _allowDemo;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _formError = 'Enter your email and password.';
        _formNotice = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
      _formNotice = null;
    });
    final signUp = _authTab == 1;
    final err = signUp
        ? await auth.signUpWithPassword(email, password, '')
        : await auth.signInWithPassword(email, password);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _formError = err;
      if (signUp && err == null) {
        _formNotice = 'Check your inbox: we sent a link to confirm $email. '
            'Open it to finish creating your account.';
        _passwordCtrl.clear();
      }
    });
  }

  Future<void> _forgotPassword(AuthProvider auth) async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Send reset link')),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    final err = await auth.requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _formError = err;
      _formNotice = err == null
          ? 'If $email has an account, we sent a link to reset the password.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
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
                    border: Border.all(color: _border),
                  ),
                  child: _body(auth),
                ),
                const SizedBox(height: 16),
                const Text(
                  'By signing in, you agree to our Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AuthProvider auth) {
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
        if (_formError != null)
          _banner(_formError!, const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
        if (_formNotice != null)
          _banner(_formNotice!, const Color(0xFFECFDF5), const Color(0xFF047857)),
        // The web GIS button renders itself against `_clientId` and gets
        // stuck on "Getting ready" forever if that's empty — there's no
        // config it can fall back to, so skip it (and the now-pointless "OR"
        // divider) rather than show a permanently broken button.
        if (AuthProvider.isConfigured) ...[
          googleSignInButton(onPressed: auth.authenticate),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: Divider(color: _border)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child:
                    Text('OR', style: TextStyle(fontSize: 12, color: _muted)),
              ),
              Expanded(child: Divider(color: _border)),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _authTabSwitch(),
        const SizedBox(height: 16),
        _fieldLabel('Email'),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: _fieldDecoration(
              hint: 'you@example.com', icon: Icons.mail_outline_rounded),
        ),
        const SizedBox(height: 14),
        _fieldLabel('Password'),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          onSubmitted: (_) => _submit(auth),
          decoration: _fieldDecoration(
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: _muted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => _forgotPassword(auth),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Forgot password?',
                style: TextStyle(
                    fontSize: 12,
                    color: _brandBlue,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _busy ? null : () => _submit(auth),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _busy
                  ? 'Please wait…'
                  : (_authTab == 0 ? 'Sign In' : 'Create Account'),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Disabled, not wired — kept visible to match the real login page's
        // layout, but there is no mobile-OTP flow behind it yet.
        const Text(
          'Sign in with mobile number instead',
          style: TextStyle(
              fontSize: 12, color: _disabled, fontWeight: FontWeight.w600),
        ),
        if (_showDemo) ...[
        const SizedBox(height: 20),
        Row(
          children: const [
            Expanded(child: Divider(color: _border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('OR', style: TextStyle(fontSize: 12, color: _muted)),
            ),
            Expanded(child: Divider(color: _border)),
          ],
        ),
        const SizedBox(height: 16),
        // Not part of the real page — the fastest way into this clone
        // without typing anything, since neither Google nor the
        // Email/Password form authenticates against a real account here.
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: auth.signInAsDemo,
            icon: const Icon(Icons.play_circle_outline_rounded,
                size: 18, color: _brandBlue),
            label: const Text(
              'Try Demo Mode',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _brandBlue),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        ],
      ],
    );
  }

  Widget _banner(String text, Color bg, Color fg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 16),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 12, color: fg)),
      );

  Widget _fieldLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569))),
      );

  InputDecoration _fieldDecoration(
      {required String hint, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: _muted),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _brandBlue)),
    );
  }

  /// Sign In / Create Account — cosmetic only. Both tabs render the same
  /// Email/Password fields; only the primary button's label changes,
  /// matching the real page's structure without a real signup backend.
  Widget _authTabSwitch() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: _authTabButton(0, 'Sign In')),
          Expanded(child: _authTabButton(1, 'Create Account')),
        ],
      ),
    );
  }

  Widget _authTabButton(int idx, String label) {
    final isSel = _authTab == idx;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _authTab = idx),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSel
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSel ? _ink : _muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandMark() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _brandBlue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.dry_cleaning_rounded,
            color: Colors.white, size: 32),
      );

  Widget _wordmark() => RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'WashN',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5),
            ),
            TextSpan(
              text: 'Laundry',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _brandBlue,
                  letterSpacing: -0.5),
            ),
          ],
        ),
      );
}
