import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// Sign-up step for a Google account that is neither staff nor a customer yet.
/// Signed-in customers use the same CRM screens as everyone else (see
/// `router.dart`); this is the only customer-specific screen left.
const _ink = Color(0xFF141A24);
const _muted = Color(0xFF64748B);

/// A Google account that is neither staff nor a customer yet: collect a name
/// and phone. A new number creates the customer; a number the store already
/// has queues a link request for staff to approve.
class CustomerStartScreen extends StatefulWidget {
  const CustomerStartScreen({super.key});

  @override
  State<CustomerStartScreen> createState() => _CustomerStartScreenState();
}

class _CustomerStartScreenState extends State<CustomerStartScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _pending = auth.me?['pending_link'] == true;
    _name.text = auth.userName ?? '';
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res =
          await ApiService.customerSignup(_name.text.trim(), _phone.text.trim());
      if (res['pending'] == true) {
        _pending = true;
      } else {
        await auth.refreshRole();
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, ${auth.userEmail ?? ''}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 8),
                if (_pending) ...[
                  const Text(
                      'We have asked the store to link this email to your '
                      'existing account. Your orders will appear here once '
                      'it is approved.',
                      style: TextStyle(color: _muted)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: auth.refreshRole,
                    child: const Text('Check again'),
                  ),
                ] else ...[
                  const Text('Tell us who you are to see your orders.',
                      style: TextStyle(color: _muted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: OutlineInputBorder()),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFDC2626))),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Saving…' : 'Continue'),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                    onPressed: auth.signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
