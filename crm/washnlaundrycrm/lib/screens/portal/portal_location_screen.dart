import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/portal_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/geolocation.dart';
import 'portal_shell.dart';

/// `/location`, right after the first sign-in: where to look for laundries.
/// The browser's position (the list then comes nearest first) or a typed PIN
/// code / area. Remembered on this device; Nearby laundries has a Change link
/// back here.
class PortalLocationScreen extends StatefulWidget {
  const PortalLocationScreen({super.key});

  @override
  State<PortalLocationScreen> createState() => _PortalLocationScreenState();
}

class _PortalLocationScreenState extends State<PortalLocationScreen> {
  late final _query =
      TextEditingController(text: context.read<PortalProvider>().locationQuery ?? '');
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final here = await currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (here == null) {
      setState(() => _error =
          'Location is off for this site. Allow it in the browser, or type your PIN code.');
      return;
    }
    await context.read<PortalProvider>().setLocation(near: here);
    if (mounted) context.go('/find');
  }

  Future<void> _useQuery() async {
    final q = _query.text.trim();
    if (q.isEmpty) {
      setState(() => _error = 'Type a PIN code or area.');
      return;
    }
    await context.read<PortalProvider>().setLocation(query: q);
    if (mounted) context.go('/find');
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = context.watch<PortalProvider>().hasLocation;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PortalNavBar(
        choosingShop: true,
        leading: canGoBack
            ? IconButton(
                tooltip: 'Back to laundries',
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                onPressed: () => context.go('/find'),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Where should we pick up from?',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: AppColors.ink)),
              const SizedBox(height: 6),
              const Text("We'll show laundries that come to you.",
                  style: TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.muted)),
              const SizedBox(height: 24),
              Material(
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _locating ? null : _useMyLocation,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.near_me_outlined,
                            size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_locating ? 'Finding you…' : 'Use my current location',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                          const SizedBox(height: 2),
                          const Text('Fastest. We only use it to sort laundries by distance.',
                              style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.muted)),
                        ]),
                      ),
                      _locating
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right, color: AppColors.muted),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(children: [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR', style: portalFieldLabel),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ]),
              const SizedBox(height: 20),
              const Text('PIN CODE OR AREA', style: portalFieldLabel),
              const SizedBox(height: 6),
              TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _useQuery(),
                decoration: portalField('e.g. 560034 or Koramangala',
                        icon: Icons.location_on_outlined)
                    .copyWith(
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(6),
                    child: IconButton.filled(
                      tooltip: 'Show laundries',
                      onPressed: _useQuery,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                  ),
                ),
              ),
              portalError(_error),
              const SizedBox(height: 20),
              const Row(children: [
                Icon(Icons.lock_outline, size: 15, color: AppColors.muted),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Your location is never shared with the laundry.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
