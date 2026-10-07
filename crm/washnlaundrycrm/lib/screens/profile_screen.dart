import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';

/// The page behind the avatar at the bottom of the sidebar.
///
/// A signed-in customer sees and edits their own details (name, address,
/// landmark, preference); phone and email are shown but locked, because orders
/// and sign-in are matched on them. Owner and staff see their account info.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _brand = Color(0xFF182C4F);
  static const _ink = Color(0xFF141A24);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE4E0D8);

  final _name = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _preference = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  String? _error;
  bool _saved = false;

  Map<String, dynamic>? _customer(AuthProvider auth) =>
      (auth.me?['customer'] as Map?)?.cast<String, dynamic>();

  /// Fills the form once the customer record is available.
  void _fillFrom(Map<String, dynamic> c) {
    _name.text = '${c['name'] ?? ''}';
    _address.text = '${c['address'] ?? ''}';
    _landmark.text = '${c['landmark'] ?? ''}';
    _preference.text = '${c['preference'] ?? ''}';
    _loaded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _landmark.dispose();
    _preference.dispose();
    super.dispose();
  }

  Future<void> _save(AuthProvider auth) async {
    if (_name.text.trim().isEmpty) {
      setState(() {
        _error = 'Name cannot be empty.';
        _saved = false;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    final err = await auth.saveCustomerProfile({
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'landmark': _landmark.text.trim(),
      'preference': _preference.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = err;
      _saved = err == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final customer = auth.role == 'customer' ? _customer(auth) : null;
    if (customer != null && !_loaded) _fillFrom(customer);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: Column(
          children: [
            Container(
              height: 64,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: const Text('Profile',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: customer != null
                        ? _customerForm(auth, customer)
                        : _accountCard(auth),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: child,
      );

  Widget _avatarHeader(String name, String email) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFFEFF6FF),
          child: Text(initials,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _brand)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
              if (email.isNotEmpty)
                Text(email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _muted)),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _decoration(String hint,
          {IconData? icon, bool locked = false}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: _muted),
        suffixIcon: locked
            ? const Icon(Icons.lock_outline_rounded,
                size: 16, color: Color(0xFF94A3B8))
            : null,
        filled: true,
        fillColor: locked ? const Color(0xFFF1EFEA) : Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _brand, width: 1.5)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
      );

  Widget _readOnly(String label, String value, IconData icon, {String? note}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextFormField(
            key: ValueKey('$label-$value'),
            initialValue: value,
            readOnly: true,
            style: const TextStyle(fontSize: 14, color: _muted),
            decoration: _decoration('', icon: icon, locked: true),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(note,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ),
        ],
      );

  Widget _field(String label, TextEditingController c, String hint,
          {IconData? icon, int lines = 1}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            controller: c,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 2,
            onChanged: (_) {
              if (_saved) setState(() => _saved = false);
            },
            style: const TextStyle(fontSize: 14, color: _ink),
            decoration: _decoration(hint, icon: icon),
          ),
        ],
      );

  Widget _customerForm(AuthProvider auth, Map<String, dynamic> c) {
    const gap = SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
            child: _avatarHeader('${c['name'] ?? ''}', '${c['email'] ?? ''}')),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Contact',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
              gap,
              _field('Full name', _name, 'Your name',
                  icon: Icons.person_outline_rounded),
              gap,
              _readOnly(
                  'Phone number', '${c['phone'] ?? ''}', Icons.phone_outlined,
                  note:
                      'Your orders are matched on this number, so it cannot be changed here.'),
              gap,
              _readOnly(
                  'Email', '${c['email'] ?? ''}', Icons.mail_outline_rounded,
                  note: 'This is the email you sign in with.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pickup details',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
              gap,
              _field('Address', _address, 'House / flat, street, area',
                  icon: Icons.home_outlined, lines: 2),
              gap,
              _field('Landmark', _landmark, 'e.g. Opposite the city mall',
                  icon: Icons.place_outlined),
              gap,
              _field('Preference', _preference,
                  'e.g. Light starch, fold shirts, fragrance-free',
                  icon: Icons.tune_rounded, lines: 2),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton(
              onPressed: _saving ? null : () => _save(auth),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(_saving ? 'Saving…' : 'Save changes'),
            ),
            const SizedBox(width: 16),
            if (_saved)
              const Text('Saved',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A))),
            if (_error != null)
              Flexible(
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFDC2626))),
              ),
          ],
        ),
      ],
    );
  }

  /// Owner and staff: who they're signed in as, read-only.
  Widget _accountCard(AuthProvider auth) {
    final shop = context.watch<AppProvider>().shop;
    final shopName = (shop?['name'] as String?)?.trim() ?? '';
    final ownerName = (shop?['owner_name'] as String?)?.trim() ?? '';
    final name =
        ownerName.isNotEmpty ? ownerName : (auth.userName ?? 'Account');
    final role = switch (auth.role) {
      'owner' => 'Owner',
      'staff' => 'Staff',
      _ => 'Account',
    };
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatarHeader(name, auth.userEmail ?? ''),
          const SizedBox(height: 20),
          _readOnly('Role', role, Icons.badge_outlined),
          if (shopName.isNotEmpty) ...[
            const SizedBox(height: 16),
            _readOnly('Shop', shopName, Icons.storefront_outlined),
          ],
        ],
      ),
    );
  }
}
