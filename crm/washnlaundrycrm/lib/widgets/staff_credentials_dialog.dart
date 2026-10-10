import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

/// Owner-only: give a staff member email + password sign-in to this shop (they
/// then see the staff views for it), reset that password, or revoke access.
///
/// Pops `true` when anything changed, so the caller can refresh the roster.
class StaffCredentialsDialog extends StatefulWidget {
  final String staffId;
  final String staffName;
  final String initialEmail;
  final bool hasAppLogin;

  /// 'staff' (default) or 'customers' - which record the sign-in belongs to.
  final String entity;

  const StaffCredentialsDialog({
    super.key,
    required this.staffId,
    required this.staffName,
    required this.initialEmail,
    required this.hasAppLogin,
    this.entity = 'staff',
  });

  /// A random 12-character password without look-alike characters.
  static String generatePassword([int length = 12]) {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = math.Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  @override
  State<StaffCredentialsDialog> createState() => _StaffCredentialsDialogState();
}

class _StaffCredentialsDialogState extends State<StaffCredentialsDialog> {
  bool get _isCustomer => widget.entity == 'customers';

  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await ApiService.setStaffCredentials(widget.staffId, email, password);
      if (!mounted) return;
      setState(() {
        _result = result;
        _changed = true;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke sign-in?'),
        content: Text(_isCustomer
            ? '${widget.staffName} will no longer be able to sign in with a password. Their customer record and orders are kept.'
            : '${widget.staffName} will no longer be able to open this shop. Their staff record is kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Revoke')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.revokeCredentials(widget.entity, widget.staffId);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _copyRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
            width: 76,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
        Expanded(
            child: SelectableText(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600))),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy_rounded, size: 16),
          onPressed: () => Clipboard.setData(ClipboardData(text: value)),
        ),
      ],
    );
  }

  Widget _resultView() {
    final r = _result!;
    final passwordSet = r['password_set'] == true;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          passwordSet
              ? '${widget.staffName} can now sign in to this shop. Share these details with them privately; the password is not shown again.'
              : '${widget.staffName} now has access to this shop. That email already has an account, so its existing password is unchanged.',
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        const SizedBox(height: 12),
        _copyRow('Email', r['email'] as String? ?? _email.text.trim()),
        if (passwordSet) _copyRow('Password', _password.text),
        if (r['password_login_enabled'] == false) ...[
          const SizedBox(height: 10),
          const Text(
            'Password sign-in is switched off on this server (it needs a private SECRET_KEY). They can still sign in with Google using this email.',
            style:
                TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _formView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.hasAppLogin
              ? 'Update the sign-in for ${widget.staffName}. Saving sets a new password.'
              : (_isCustomer
                  ? 'Give ${widget.staffName} an email and password to sign in to their customer page for this shop (their orders and rate card).'
                  : 'Give ${widget.staffName} an email and password. They will only see the views allowed for staff in this shop.'),
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
              labelText: 'Sign-in email', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Password (min 8 characters)',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _obscure ? 'Show' : 'Hide',
                  icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                IconButton(
                  tooltip: 'Generate a password',
                  icon: const Icon(Icons.autorenew_rounded, size: 18),
                  onPressed: () => setState(() {
                    _password.text = StaffCredentialsDialog.generatePassword();
                    _obscure = false;
                  }),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _result != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.hasAppLogin || done
          ? (_isCustomer ? 'Customer sign-in' : 'Staff sign-in')
          : (_isCustomer ? 'Enable customer sign-in' : 'Enable staff sign-in')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(child: done ? _resultView() : _formView()),
      ),
      actions: done
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
            ]
          : [
              if (widget.hasAppLogin)
                TextButton(
                  onPressed: _busy ? null : _revoke,
                  child: Text(_isCustomer ? 'Remove sign-in' : 'Revoke access',
                      style: TextStyle(color: Color(0xFFDC2626))),
                ),
              TextButton(
                onPressed:
                    _busy ? null : () => Navigator.pop(context, _changed),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(widget.hasAppLogin
                        ? 'Save password'
                        : 'Enable sign-in'),
              ),
            ],
    );
  }
}
