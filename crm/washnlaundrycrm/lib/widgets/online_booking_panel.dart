import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Settings → Online booking (KAN-222): switch the customer portal on for this
/// shop, share its booking link / QR, and approve customers who signed up
/// online with a phone number the shop already had.
class OnlineBookingPanel extends StatefulWidget {
  const OnlineBookingPanel({super.key});

  /// The customer portal's address for a shop.
  static String bookingLink(String slug) => 'https://customer.washnlaundry.com/s/$slug';

  @override
  State<OnlineBookingPanel> createState() => _OnlineBookingPanelState();
}

class _OnlineBookingPanelState extends State<OnlineBookingPanel> {
  List<Map<String, dynamic>>? _requests;
  String? _error;
  bool _toggling = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final r = await ApiService.fetchLinkRequests();
      if (mounted) setState(() => _requests = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggle(bool on) async {
    setState(() => _toggling = true);
    final provider = context.read<AppProvider>();
    final ok = await provider.saveShop({'accepts_online_customers': on});
    if (!mounted) return;
    setState(() => _toggling = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save: ${provider.error ?? 'unknown error'}'),
          backgroundColor: AppColors.danger));
    }
  }

  Future<void> _resolve(Map<String, dynamic> r, bool approve) async {
    final id = r['id'] as int;
    setState(() => _busy.add(id));
    try {
      await ApiService.resolveLinkRequest(id, approve: approve);
      if (mounted) setState(() => _requests?.removeWhere((x) => x['id'] == id));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<AppProvider>().shop;
    final on = shop?['accepts_online_customers'] == true;
    final slug = shop?['slug'] as String?;
    final link = slug == null ? null : OnlineBookingPanel.bookingLink(slug);
    final requests = _requests;

    Widget box(List<Widget> children) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        );

    // A Column: Settings already wraps each tab in a scroll view.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      box([
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: on,
          onChanged: _toggling || shop == null ? null : _toggle,
          title: const Text('Take bookings online', style: AppTypography.sectionTitle),
          subtitle: const Text(
              'Customers find your shop at customer.washnlaundry.com, sign in with Google '
              'or an emailed code, and book home pickups at your prices. New bookings '
              'appear in Orders and are emailed to the shop email.',
              style: TextStyle(color: AppColors.muted, height: 1.4)),
        ),
      ]),
      if (on && link != null) ...[
        const SizedBox(height: 16),
        box([
          const Text('Your booking link', style: AppTypography.sectionTitle),
          const SizedBox(height: 4),
          const Text('Share it on WhatsApp, or print the QR at the counter.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 24, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
              child: QrImageView(data: link, size: 140, padding: EdgeInsets.zero),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(link, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Link copied')));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy link'),
              ),
            ]),
          ]),
        ]),
      ],
      const SizedBox(height: 16),
      box([
        const Text('Online sign-ups to confirm', style: AppTypography.sectionTitle),
        const SizedBox(height: 4),
        const Text(
            'Someone signed up with a mobile number you already have. Approve only if '
            'the email is really that customer\'s: they then see that customer\'s orders.',
            style: TextStyle(color: AppColors.muted, height: 1.4)),
        const SizedBox(height: 12),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        if (requests == null && _error == null)
          const Center(child: CircularProgressIndicator())
        else if (requests != null && requests.isEmpty)
          const Text('Nothing waiting.', style: TextStyle(color: AppColors.muted))
        else
          for (final r in requests ?? const <Map<String, dynamic>>[])
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderSubtle))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['email']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('wants to be ${r['customer_name']} (${r['customer_phone']})',
                        style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
                TextButton(
                  onPressed: _busy.contains(r['id']) ? null : () => _resolve(r, false),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _busy.contains(r['id']) ? null : () => _resolve(r, true),
                  child: const Text('Approve'),
                ),
              ]),
            ),
      ]),
    ]);
  }
}
