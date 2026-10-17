import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';

/// `/setup-shop`: the first page an account with no shop of its own sees after
/// signing in (backend SELF_SERVICE_SHOPS). It names the shop and creates it via
/// `POST /api/shops/provision/`, which makes the account its owner; the account
/// only ever sees this shop's data. The router keeps the account here until it
/// has one, and sends it to the dashboard afterwards.
class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  static const _brandBlue = Color(0xFF182C4F);
  static const _ink = Color(0xFF141A24);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE4E0D8);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final app = context.read<AppProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shop = await ApiService.provisionShop({
        'name': _name.text.trim(),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      });
      // Work in the new shop from here on, then let /me confirm the owner role.
      app.setActiveTenant(shop['slug'] as String? ?? shop['id'].toString());
      app.setAvailableShops([shop]);
      await auth.refreshRole();
      if (!mounted) return;
      context.go('/dashboard');
      await app.loadDataFromBackend();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not create your shop. Please try again.');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: _muted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _brandBlue, width: 1.5)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      // Window-wide scroll view (scrollbar at the window edge), content centred.
      body: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandLogo(size: 64),
                      const SizedBox(height: 20),
                      const Text('Set up your shop',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _ink)),
                      const SizedBox(height: 6),
                      Text(
                        'Signed in as ${auth.userEmail ?? ''}. Name your laundry '
                        'to open your own dashboard. Only you can see its data.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: _muted, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFB91C1C))),
                                ),
                                const SizedBox(height: 16),
                              ],
                              _label('Shop name'),
                              TextFormField(
                                key: const ValueKey('shop-name'),
                                controller: _name,
                                autofocus: true,
                                textInputAction: TextInputAction.next,
                                decoration: _decoration(
                                    'e.g. Royal Cleaners', Icons.storefront_outlined),
                                validator: (v) => (v ?? '').trim().length < 2
                                    ? 'Enter your shop name (at least 2 characters).'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _label('City (optional)'),
                              TextFormField(
                                controller: _city,
                                textInputAction: TextInputAction.next,
                                decoration: _decoration(
                                    'e.g. Patna', Icons.location_on_outlined),
                              ),
                              const SizedBox(height: 14),
                              _label('Shop phone (optional)'),
                              TextFormField(
                                key: const ValueKey('shop-phone'),
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: _decoration(
                                    '9876543210', Icons.phone_outlined),
                                validator: (v) {
                                  final t = (v ?? '').trim();
                                  return t.isEmpty || RegExp(r'^[6-9]\d{9}$').hasMatch(t)
                                      ? null
                                      : 'Enter a valid 10-digit phone number.';
                                },
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _busy ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _brandBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Create my shop',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _busy ? null : auth.signOut,
                        child: const Text('Sign out',
                            style: TextStyle(color: _muted)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
