import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import 'support_info.dart';

/// Settings → Help & support: ways to reach support, the details support will
/// ask for (shop ID, sign-in email), and answers to common questions. The
/// answers describe what the app does today; keep them in step with it.
class HelpSupportPanel extends StatelessWidget {
  const HelpSupportPanel({super.key});

  static const _ink = Color(0xFF141A24);
  static const _muted = Color(0xFF64748B);
  static const _brandBlue = Color(0xFF182C4F);
  static const _border = Color(0xFFE2E8F0);

  /// (question, answer) pairs shown as expandable rows.
  static const faqs = [
    (
      'How do I create an order?',
      'Open New Order, choose the customer (or add a new one), add items for each '
          'service, then check everything on the Review step and save. You can '
          'attach photos and videos on the Review step.',
    ),
    (
      'How do I give a staff member their own sign-in?',
      'On Staff, open the person and give them a sign-in email and password. Staff '
          'can use New Order, Orders, Customers and Scan. Money, payroll, reports and '
          'settings stay with the owner.',
    ),
    (
      'How is payroll worked out?',
      'From the Attendance register and each person\'s salary: present days are paid, '
          'a half day counts as half, and leave is unpaid. Record what you pay with '
          'Pay salary. A month can be paid in instalments.',
    ),
    (
      'What is the difference between Expenses and Credits?',
      'Expenses are money going out. Credits are money coming in outside an order, '
          'such as advances, delivery fees or owner top-ups. Credit categories are '
          'managed in Settings → Credit categories.',
    ),
    (
      'How do I back up or move my data?',
      'Settings → Backup, Data Import & Export. Download everything as an Excel or '
          'JSON backup, or one section as a CSV file. A section can be imported back '
          'from its own export; rows that already exist are skipped. Only your own '
          'shop\'s data is ever included.',
    ),
    (
      'How do I print garment tags?',
      'Use Scan → Generate Tags and pick the order, or choose Print Tags after '
          'saving a new order.',
    ),
    (
      'I forgot my password.',
      'On the sign-in page, tap "Forgot password?" and enter your email. The reset '
          'link in the email works for 1 hour.',
    ),
    (
      'Where are Social Suite and Chat?',
      'Social Suite (Facebook, Instagram and WhatsApp) and the AI support Chat are '
          'switched off by default. Contact support to have either turned on for your shop.',
    ),
  ];

  Future<void> _open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that here. The details are shown on this page.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<AppProvider>().shop;
    final email = context.watch<AuthProvider?>()?.userEmail;
    final shopName = shop?['name'] as String?;
    final shopId = (shop?['slug'] ?? shop?['id'])?.toString();
    final subject = Uri.encodeComponent(
        'Support request${shopId != null ? ' - $shopId' : ''}');
    final waText = Uri.encodeComponent(
        'Hi WashNLaundry support${shopName != null ? ', this is $shopName' : ''}. ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Help & support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
        const SizedBox(height: 4),
        const Text(
          'Reach the WashNLaundry team, or find a quick answer below.',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 24),
        _section(
          title: 'Contact support',
          subtitle: SupportInfo.hours,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _contactTile(
                key: const ValueKey('help-call'),
                icon: Icons.phone_outlined,
                label: 'Call',
                value: SupportInfo.phone,
                onTap: () => _open(context, Uri.parse('tel:${SupportInfo.phoneTel}')),
              ),
              _contactTile(
                key: const ValueKey('help-whatsapp'),
                icon: Icons.chat_outlined,
                label: 'WhatsApp',
                value: SupportInfo.phone,
                onTap: () => _open(context,
                    Uri.parse('https://wa.me/${SupportInfo.whatsapp}?text=$waText')),
              ),
              _contactTile(
                key: const ValueKey('help-email'),
                icon: Icons.email_outlined,
                label: 'Email',
                value: SupportInfo.email,
                onTap: () => _open(
                    context, Uri.parse('mailto:${SupportInfo.email}?subject=$subject')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Details to share with support',
          subtitle: 'These help us find your shop quickly.',
          child: Column(
            children: [
              _detailRow(context, 'Shop', shopName ?? '—'),
              _detailRow(context, 'Shop ID', shopId ?? '—', copyable: shopId != null),
              _detailRow(context, 'Signed in as', email ?? '—', copyable: email != null),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Common questions',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
        const SizedBox(height: 8),
        // Material (not a decorated Container) so the question rows' ink shows.
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < faqs.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: _border),
                Theme(
                  // No ExpansionTile divider lines; the list draws its own.
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    iconColor: _brandBlue,
                    collapsedIconColor: _muted,
                    title: Text(faqs[i].$1,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                    children: [
                      Text(faqs[i].$2,
                          style: const TextStyle(fontSize: 13, color: _muted, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _section({required String title, String? subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _contactTile({
    required Key key,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return ConstrainedBox(
      key: key,
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _brandBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                      const SizedBox(height: 2),
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value,
      {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
          ),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
          ),
          if (copyable)
            IconButton(
              tooltip: 'Copy $label',
              icon: const Icon(Icons.copy_rounded, size: 16, color: _muted),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$label copied')));
              },
            ),
        ],
      ),
    );
  }
}
