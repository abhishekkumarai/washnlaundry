import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/portal_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'portal_addresses_screen.dart';
import 'portal_shell.dart';

/// `/profile`, the Profile tab: who the customer is (name and mobile, editable;
/// email is the sign-in), their addresses (a summary linking to `/addresses`),
/// the laundry they book with (Change), and Sign out. It replaces the old
/// account overview (`/account` redirects here).
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
  bool _saving = false;
  String? _error;
  String? _saved;
  List<Map<String, dynamic>>? _addresses;

  @override
  void initState() {
    super.initState();
    ApiService.fetchMyAddresses().then((list) {
      if (mounted) setState(() => _addresses = list);
    }, onError: (_) {
      if (mounted) setState(() => _addresses = const []);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final portal = context.watch<PortalProvider>();
    final name = _name.text.trim().isNotEmpty ? _name.text.trim() : (auth.userName ?? '');
    final email = auth.userEmail ?? '';
    final addresses = _addresses;
    final def = addresses?.where((a) => a['is_default'] == true).firstOrNull ??
        addresses?.firstOrNull;
    final shop = portal.shop ?? const {};
    final shopPlace = portalShopPlace(shop);

    return PortalShell(
      index: PortalSection.profile,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 24, 16, 32), children: [
        Row(children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.mutedFill,
            child: Text(portalInitial(name, email),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Your profile' : name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: AppColors.ink)),
              if (email.isNotEmpty)
                Text(email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        const Text('YOUR DETAILS', style: portalFieldLabel),
        const SizedBox(height: 8),
        PortalPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Signed in as '),
                TextSpan(
                    text: email,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save details')),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('ADDRESSES', style: portalFieldLabel),
        const SizedBox(height: 8),
        _Row(
          title: addresses == null
              ? 'Addresses'
              : addresses.isEmpty
                  ? 'No saved addresses'
                  : '${addresses.length} saved address${addresses.length == 1 ? '' : 'es'}',
          detail: def == null
              ? 'Add one here or while booking a pickup.'
              : 'Default: ${portalAddressLabel(def)} · ${portalAddressLine(def)}',
          onTap: () => context.go('/addresses'),
        ),
        const SizedBox(height: 24),
        const Text('LAUNDRY', style: portalFieldLabel),
        const SizedBox(height: 8),
        _Row(
          title: portal.shopName,
          detail: shopPlace.isEmpty ? 'The laundry you book with' : shopPlace,
          action: 'Change',
          onTap: () => context.go('/find'),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: auth.signOut,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// A tappable row in a white card: title, a muted line, and a chevron or a
/// blue [action] word.
class _Row extends StatelessWidget {
  const _Row({required this.title, required this.detail, required this.onTap, this.action});

  final String title;
  final String detail;
  final String? action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              action == null
                  ? const Icon(Icons.chevron_right, color: AppColors.muted)
                  : Text(action!,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent)),
            ]),
          ),
        ),
      );
}
