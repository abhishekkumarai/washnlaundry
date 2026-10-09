import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';

class ShopOnboardingDialog extends StatefulWidget {
  const ShopOnboardingDialog({super.key});

  @override
  State<ShopOnboardingDialog> createState() => _ShopOnboardingDialogState();
}

class _ShopOnboardingDialogState extends State<ShopOnboardingDialog> {
  static const _brandBlue = Color(0xFF182C4F);
  static const _ink = Color(0xFF141A24);
  static const _muted = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final res = await ApiService.provisionShop({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : '+91 98765 43210',
        'city': _cityController.text.trim(),
      });

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final app = context.read<AppProvider>();

      final newSlug = res['slug'] as String? ?? res['id']?.toString() ?? '';
      app.setActiveTenant(newSlug);
      final currentList = List<Map<String, dynamic>>.from(app.availableShops);
      if (!currentList.any((s) => (s['slug'] ?? s['id']?.toString()) == newSlug)) {
        currentList.insert(0, res);
        app.setAvailableShops(currentList);
      }
      await auth.refreshRole();
      await app.loadDataFromBackend();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Failed to create shop: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandLogo(size: 48)),
                const SizedBox(height: 20),
                const Text(
                  'Set up your store',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome to WashNLaundry! Before getting started, enter the name of your laundry or dry-cleaning business.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Shop / Store Name *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'e.g. Royal Cleaners, Sparkle Dry Clean',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your shop name';
                    if (v.trim().length < 2) return 'Shop name must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'City / Location (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Mumbai, Bengaluru, Delhi',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Store Contact Phone (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    hintText: '+91 98765 43210',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Create Store & Launch CRM',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
