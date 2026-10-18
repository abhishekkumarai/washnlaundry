import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'address_editor.dart';
import 'portal_shell.dart';

/// The customer's details for this shop (name, mobile; email is the sign-in)
/// and their saved pickup addresses.
class PortalProfileScreen extends StatefulWidget {
  const PortalProfileScreen({super.key});

  @override
  State<PortalProfileScreen> createState() => _PortalProfileScreenState();
}

class _PortalProfileScreenState extends State<PortalProfileScreen> {
  late final AuthProvider _auth = context.read<AuthProvider>();
  late final Map<String, dynamic> _me =
      Map<String, dynamic>.from((_auth.me?['customer'] as Map?) ?? const {});
  late final _name = TextEditingController(text: '${_me['name'] ?? ''}');
  late final _phone = TextEditingController(text: '${_me['phone'] ?? ''}');
  List<Map<String, dynamic>>? _addresses;
  bool _saving = false;
  String? _error;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final list = await ApiService.fetchMyAddresses();
      if (mounted) setState(() => _addresses = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _saved = null;
    });
    final err = await _auth.saveCustomerProfile({
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = err;
      _saved = err == null ? 'Saved.' : null;
    });
  }

  Future<void> _edit([Map<String, dynamic>? address]) async {
    final saved = await showAddressEditor(context, address: address);
    if (saved != null) _loadAddresses();
  }

  Future<void> _delete(Map<String, dynamic> address) async {
    try {
      await ApiService.deleteMyAddress(address['id'] as int);
      _loadAddresses();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = _addresses;
    return PortalShell(
      index: 2,
      title: 'Profile',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        PortalPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Your details', style: AppTypography.sectionTitle),
            const SizedBox(height: 12),
            TextField(
                controller: _name,
                decoration:
                    const InputDecoration(labelText: 'Full name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Mobile number', prefixText: '+91 ', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Text('Email: ${_auth.userEmail ?? ''} (your sign-in)',
                style: const TextStyle(color: AppColors.muted)),
            portalError(_error),
            if (_saved != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_saved!, style: const TextStyle(color: AppColors.success)),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save details')),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Text('Pickup addresses', style: AppTypography.title)),
          TextButton.icon(
              onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add')),
        ]),
        const SizedBox(height: 6),
        if (addresses == null)
          const Center(child: CircularProgressIndicator())
        else if (addresses.isEmpty)
          const Text('No saved addresses yet.', style: TextStyle(color: AppColors.muted))
        else
          for (final a in addresses) ...[
            PortalPanel(
              padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        '${const {
                              'HOME': 'Home',
                              'WORK': 'Work',
                              'OTHER': 'Other'
                            }[a['label']] ?? 'Address'}'
                        '${a['is_default'] == true ? ' · default' : ''}',
                        style: AppTypography.sectionTitle),
                    const SizedBox(height: 2),
                    Text(
                        [a['address'], a['landmark'], a['area'], a['pin_code']]
                            .where((v) => v != null && '$v'.isNotEmpty)
                            .join(', '),
                        style: const TextStyle(color: AppColors.muted)),
                    if (a['latitude'] != null)
                      const Text('Map pin set',
                          style: TextStyle(fontSize: 12, color: AppColors.success)),
                  ]),
                ),
                IconButton(
                    tooltip: 'Edit',
                    onPressed: () => _edit(a),
                    icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _delete(a),
                    icon: const Icon(Icons.delete_outline)),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 24),
        OutlinedButton(onPressed: _auth.signOut, child: const Text('Sign out')),
      ]),
    );
  }
}
