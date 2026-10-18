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
            const SizedBox(height: 14),
            const Text('FULL NAME', style: portalFieldLabel),
            const SizedBox(height: 6),
            TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: portalField('Your name', icon: Icons.person_outline)),
            const SizedBox(height: 14),
            const Text('MOBILE NUMBER', style: portalFieldLabel),
            const SizedBox(height: 6),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration:
                    portalField('10-digit mobile', icon: Icons.phone_outlined, prefix: '+91 ')),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Signed in as '),
                TextSpan(
                    text: _auth.userEmail ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
              ]),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
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
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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
      ]),
    );
  }
}
