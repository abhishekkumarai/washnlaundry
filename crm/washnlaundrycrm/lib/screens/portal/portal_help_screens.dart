import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/portal_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'portal_shell.dart';
import 'portal_ticket.dart';

const _sectionLabel = portalFieldLabel;

/// Questions every laundry gets; the answers hold for any shop on the portal.
const _faq = [
  (
    'How are prices decided?',
    'Each laundry sets its own prices per piece. The final bill is confirmed after pickup, '
        'when your items are counted.'
  ),
  (
    'Can I change my pickup slot?',
    'Call or WhatsApp the laundry before the slot starts and they will move it for you.'
  ),
  (
    'When do I pay?',
    'When your clothes come back. Pay the laundry in cash or UPI on delivery.'
  ),
  (
    'What if something is damaged or lost?',
    'Report it from the order (Need help with this order?) or with Report an issue below. '
        'The laundry gets it by email and replies to you.'
  ),
  (
    'How do I cancel an order?',
    'Contact the laundry before the pickup. Online cancelling is not available yet.'
  ),
];

/// A phone number as wa.me wants it: digits only, India's 91 in front of a
/// 10-digit mobile.
String _waNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length == 10 ? '91$digits' : digits;
}

/// `/help`: contact the laundry (call, WhatsApp, email), report a problem with
/// an order, and the FAQ. Wide screens: FAQ on the left, contact and report on
/// the right.
class PortalHelpScreen extends StatelessWidget {
  const PortalHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final portal = context.watch<PortalProvider>();
    final shop = portal.shop ?? const {};
    final phone = '${shop['phone'] ?? ''}'.trim();
    final whatsapp = '${shop['whatsapp'] ?? ''}'.trim().isNotEmpty
        ? '${shop['whatsapp']}'.trim()
        : phone;
    final email = '${shop['email'] ?? ''}'.trim();
    final wide = MediaQuery.sizeOf(context).width >= PortalShell.wide;

    final contact = PortalPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Contact ${portal.shopName}', style: AppTypography.sectionTitle),
        const SizedBox(height: 12),
        if (phone.isEmpty && email.isEmpty)
          const Text('This laundry has not added contact details yet.',
              style: TextStyle(color: AppColors.muted))
        else if (wide)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (phone.isNotEmpty)
              _ContactButton(
                  icon: Icons.call_outlined,
                  label: phone,
                  onTap: () => launchUrl(Uri(scheme: 'tel', path: phone))),
            if (whatsapp.isNotEmpty)
              _ContactButton(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  onTap: () => launchUrl(Uri.parse('https://wa.me/${_waNumber(whatsapp)}'))),
            if (email.isNotEmpty)
              _ContactButton(
                  icon: Icons.mail_outline,
                  label: email,
                  onTap: () => launchUrl(Uri(scheme: 'mailto', path: email))),
          ])
        else
          Row(children: [
            if (phone.isNotEmpty)
              Expanded(
                child: _ContactTile(
                    icon: Icons.call_outlined,
                    label: 'Call',
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: phone))),
              ),
            if (whatsapp.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _ContactTile(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    onTap: () => launchUrl(Uri.parse('https://wa.me/${_waNumber(whatsapp)}'))),
              ),
            ],
            if (email.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _ContactTile(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    onTap: () => launchUrl(Uri(scheme: 'mailto', path: email))),
              ),
            ],
          ]),
      ]),
    );

    final report = Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go('/help/report'),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.report_outlined, size: 22, color: AppColors.primary),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Report an issue',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                SizedBox(height: 2),
                Text('Missing item, damage, delay or billing',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ]),
            ),
            Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      ),
    );

    // A Material, not a coloured box, so the rows' ink shows.
    final faq = Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < _faq.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: i == 0,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedAlignment: Alignment.centerLeft,
              iconColor: AppColors.muted,
              collapsedIconColor: AppColors.muted,
              title: Text(_faq[i].$1,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
              children: [
                Text(_faq[i].$2,
                    style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ]),
    );

    return PortalShell(
      index: PortalSection.help,
      title: 'Help',
      maxWidth: 1120,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('QUESTIONS', style: _sectionLabel),
                const SizedBox(height: 10),
                faq,
              ]),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 340,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 24),
                contact,
                const SizedBox(height: 16),
                report,
              ]),
            ),
          ])
        else ...[
          contact,
          const SizedBox(height: 24),
          const Text('SOMETHING WRONG WITH AN ORDER?', style: _sectionLabel),
          const SizedBox(height: 10),
          report,
          const SizedBox(height: 24),
          const Text('QUESTIONS', style: _sectionLabel),
          const SizedBox(height: 10),
          faq,
        ],
      ]),
    );
  }
}

/// A contact action on a phone: icon over a short label, in a row of three.
class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      );
}

/// A contact action on wide screens: icon and the number / address, stacked.
class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: AppColors.primary),
          label: Align(
              alignment: Alignment.centerLeft,
              child: Text(label, overflow: TextOverflow.ellipsis)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            alignment: Alignment.centerLeft,
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
}

/// What a customer can report, as the API names them.
const _issueKinds = [
  ('MISSING', Icons.inventory_2_outlined, 'Missing item'),
  ('DAMAGED', Icons.content_cut, 'Damaged item'),
  ('LATE', Icons.schedule, 'Late pickup or delivery'),
  ('BILLING', Icons.receipt_outlined, 'Billing'),
  ('STAIN', Icons.water_drop_outlined, 'Stain not removed'),
  ('OTHER', Icons.help_outline, 'Something else'),
];

/// `/help/report[?order=<no>]`: tell the laundry what went wrong with an order.
/// Saved as an OrderIssue and emailed to the shop.
class PortalReportIssueScreen extends StatefulWidget {
  const PortalReportIssueScreen({super.key, this.orderNumber});

  /// Preselected when opened from an order's page.
  final String? orderNumber;

  @override
  State<PortalReportIssueScreen> createState() => _PortalReportIssueScreenState();
}

class _PortalReportIssueScreenState extends State<PortalReportIssueScreen> {
  List<Map<String, dynamic>>? _orders;
  String? _order;
  String? _kind;
  final _message = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = widget.orderNumber;
    _message.addListener(() => setState(() {}));
    ApiService.fetchMyOrdersPage(pageSize: 20).then((page) {
      if (!mounted) return;
      setState(() {
        _orders = [
          for (final o in (page['orders'] as List? ?? const []))
            Map<String, dynamic>.from(o as Map)
        ];
        _order ??= _orders!.isEmpty ? null : '${_orders!.first['order_number']}';
      });
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : '$e');
    });
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String? get _blocker => _order == null
      ? 'Pick the order.'
      : _kind == null
          ? 'Pick what went wrong.'
          : _message.text.trim().isEmpty
              ? 'Tell the laundry what happened.'
              : null;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.reportOrderIssue(_order!, _kind!, _message.text.trim());
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  String _orderLine(Map<String, dynamic> o) {
    final services = {
      for (final i in (o['items'] as List? ?? const [])) '${(i as Map)['service_type']}'
    }.join(', ');
    final at = DateTime.tryParse('${o['created_at']}')?.toLocal();
    return [services, if (at != null) DateFormat('EEE d MMM').format(at)]
        .where((s) => s.isNotEmpty)
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final shopName = context.watch<PortalProvider>().shopName;
    final back = TextButton.icon(
      onPressed: () => context.go('/help'),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('Help'),
      style: TextButton.styleFrom(foregroundColor: AppColors.ink),
    );
    if (_sent) {
      return PortalShell(
        index: PortalSection.help,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Align(alignment: Alignment.centerLeft, child: back),
          const SizedBox(height: 8),
          PortalPanel(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success, size: 28),
              const SizedBox(height: 10),
              const Text('Report sent', style: AppTypography.title),
              const SizedBox(height: 4),
              Text('$shopName has it by email and will reply to you.',
                  style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.muted)),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: () => context.go('/orders'), child: const Text('Back to orders')),
            ]),
          ),
        ]),
      );
    }
    final orders = _orders;
    final blocker = _blocker;
    return PortalShell(
      index: PortalSection.help,
      showNav: false,
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            Align(alignment: Alignment.centerLeft, child: back),
            const SizedBox(height: 4),
            const Text('Report an issue',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('$shopName will get this by email and reply to you.',
                style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            const SizedBox(height: 20),
            const Text('ORDER', style: _sectionLabel),
            const SizedBox(height: 6),
            if (orders == null && _error == null)
              const LinearProgressIndicator(minHeight: 2)
            else if (orders != null && orders.isEmpty)
              const PortalPanel(
                child: Text('You have no orders with this laundry yet.',
                    style: TextStyle(color: AppColors.muted)),
              )
            else if (orders != null)
              DropdownButtonFormField<String>(
                initialValue: orders.any((o) => '${o['order_number']}' == _order) ? _order : null,
                isExpanded: true,
                decoration: portalField('Choose the order'),
                items: [
                  for (final o in orders)
                    DropdownMenuItem(
                      value: '${o['order_number']}',
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '${o['order_number']}  ',
                              style: portalMono(size: 14, weight: FontWeight.w600)),
                          TextSpan(text: _orderLine(o)),
                        ]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _order = v),
              ),
            const SizedBox(height: 20),
            const Text('WHAT WENT WRONG?', style: _sectionLabel),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - 8) / 2;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (kind, icon, label) in _issueKinds)
                  SizedBox(
                    width: w,
                    child: _KindTile(
                      icon: icon,
                      label: label,
                      selected: _kind == kind,
                      onTap: () => setState(() => _kind = kind),
                    ),
                  ),
              ]);
            }),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Text('TELL US MORE', style: _sectionLabel)),
              Text('${_message.text.length} / 500', style: portalMono(size: 12, color: AppColors.muted)),
            ]),
            const SizedBox(height: 6),
            TextField(
              controller: _message,
              maxLines: 5,
              maxLength: 500,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: portalField('Which item, and what happened?'),
            ),
            const SizedBox(height: 8),
            const Text('Add photos later by replying to the email.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_error != null || blocker != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error ?? blocker!,
                    style: TextStyle(
                        fontSize: 13, color: _error != null ? AppColors.danger : AppColors.muted)),
              ),
            FilledButton(
              onPressed: _busy || blocker != null ? null : _send,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(_busy ? 'Sending…' : 'Send report'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile(
      {required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 84,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                ]),
                const Spacer(),
                Text(label,
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink)),
              ]),
            ),
          ),
        ),
      );
}
