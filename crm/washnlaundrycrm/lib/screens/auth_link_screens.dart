import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

const _brandBlue = Color(0xFF1A4FD6);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

Widget _frame(Widget child) => Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    );

/// `/verify?token=…`: the link in the confirmation email. Confirms the address,
/// signs the user in, and lets the role-based router take it from there.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  final String? token;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  String? _error;
  bool _done = false;

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
    final err = await context.read<AuthProvider>().confirmEmail(token);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() => _done = true);
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _frame(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFDC2626))),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to sign in')),
        ],
      ));
    }
    return _frame(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_done) const CircularProgressIndicator(strokeWidth: 2.5),
        const SizedBox(height: 16),
        const Text('Confirming your email…', style: TextStyle(color: _muted)),
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
    final err = await context
        .read<AuthProvider>()
        .resetPassword(widget.token ?? '', _password.text);
    if (!mounted) return;
    if (err == null) {
      context.go('/');
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
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
