import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';

const _brandBlue = Color(0xFF182C4F);
const _ink = Color(0xFF141A24);
const _muted = Color(0xFF64748B);

/// Brand header + a white card, the same look as the login page, so the pages an email link
/// opens do not feel like a different product.
Widget _frame(Widget child) => Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 72),
                  const SizedBox(height: 12),
                  RichText(
                    text: const TextSpan(children: [
                      TextSpan(
                          text: 'WashN',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -0.5)),
                      TextSpan(
                          text: 'Laundry',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _brandBlue,
                              letterSpacing: -0.5)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E0D8)),
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

/// `/verify?token=…`: the link in the confirmation email. Confirms the address,
/// shows a short "confirmed" step, signs the user in, and lets the role-based router
/// take it from there. A bad or expired link offers a fresh email.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  final String? token;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  String? _error;
  int? _status;
  bool _confirmed = false;
  bool _resending = false;
  String? _resendNote;

  /// Invalid or expired (not "already used" or "incomplete"): a new link can be sent.
  bool get _canResend => _status == 400 && (widget.token ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'This confirmation link is incomplete.');
      return;
    }
    // Grab the router first: signing in rebuilds this page, so `mounted` may be false
    // by the time the call returns, and the redirect must still happen.
    final router = GoRouter.of(context);
    final auth = context.read<AuthProvider>();
    final err = await auth.confirmEmail(token);
    if (err == null) {
      if (mounted) setState(() => _confirmed = true);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      router.go('/');
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = err;
      _status = auth.lastConfirmStatus;
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _resendNote = null;
    });
    String note;
    try {
      final res = await ApiService.resendVerification(widget.token ?? '');
      note = res['already_confirmed'] == true
          ? 'This email is already confirmed. Sign in with your password.'
          : 'We sent a new confirmation link. Check your inbox.';
    } on ApiException catch (e) {
      note = e.message;
    }
    if (!mounted) return;
    setState(() {
      _resending = false;
      _resendNote = note;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed) {
      return _frame(const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 44, color: Color(0xFF16A34A)),
          SizedBox(height: 12),
          Text('Email confirmed',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
          SizedBox(height: 6),
          Text('Signing you in…', style: TextStyle(color: _muted)),
        ],
      ));
    }
    if (_error != null) {
      return _frame(Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Once a new link has been requested, the note replaces the red error.
          Text(_resendNote ?? _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _resendNote == null ? const Color(0xFFDC2626) : _ink)),
          const SizedBox(height: 16),
          if (_canResend)
            FilledButton(
              onPressed: _resending ? null : _resend,
              style: FilledButton.styleFrom(backgroundColor: _brandBlue),
              child: Text(_resending ? 'Sending…' : 'Resend confirmation email'),
            ),
          const SizedBox(height: 8),
          _canResend
              ? TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to sign in'))
              : FilledButton(
                  onPressed: () => context.go('/login'),
                  style: FilledButton.styleFrom(backgroundColor: _brandBlue),
                  child: const Text('Back to sign in')),
        ],
      ));
    }
    return _frame(const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(strokeWidth: 2.5),
        SizedBox(height: 16),
        Text('Confirming your email…', style: TextStyle(color: _muted)),
      ],
    ));
  }
}

/// `/reset?token=…`: the link in the password-reset email.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String? token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    final err = await context
        .read<AuthProvider>()
        .resetPassword(widget.token ?? '', _password.text);
    if (err == null) {
      router.go('/');
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _frame(Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose a new password',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: 'New password', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
              labelText: 'Confirm password', border: OutlineInputBorder()),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFFDC2626))),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: _brandBlue),
            child: Text(_busy ? 'Saving…' : 'Set password and sign in'),
          ),
        ),
      ],
    ));
  }
}
