import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import 'portal_shell.dart';

/// IBM Plex Mono for order numbers, prices, times and pincodes (tabular figures),
/// the one place the portal leaves IBM Plex Sans (crm/docs/customer-portal-flow.md).
TextStyle portalMono({double size = 14, FontWeight weight = FontWeight.w500, Color? color}) =>
    GoogleFonts.ibmPlexMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// An order drawn as a laundry claim ticket: a punched hole, a stub with the
/// order number and its status, a dashed perforation, then [body]. Used by Order
/// placed, Orders → Current and the order page header.
class PortalTicket extends StatelessWidget {
  const PortalTicket({
    super.key,
    required this.orderNumber,
    required this.status,
    required this.body,
    this.caption,
    this.large = false,
    this.onTap,
  });

  final String orderNumber;

  /// An order status (`PLACED`...), shown as a pill.
  final String status;

  /// A muted line under the number, e.g. "Booked Mon 20 Oct, 7:42 PM".
  final String? caption;
  final Widget body;

  /// The order-placed and order-page size: a bigger number.
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stub = Padding(
      padding: const EdgeInsets.fromLTRB(36, 16, 16, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ORDER', style: portalFieldLabel),
            const SizedBox(height: 2),
            Text(orderNumber,
                style: portalMono(size: large ? 26 : 19, weight: FontWeight.w600)
                    .copyWith(letterSpacing: 1.2)),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        PortalStatusPill(status: status),
      ]),
    );
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          stub,
          const _Perforation(),
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), child: body),
        ]),
        // The punched hole a claim tag hangs from.
        Positioned(
          left: 14,
          top: 18,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ]),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: card),
    );
  }
}

/// The dashed line between a ticket's stub and its body.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 1,
        child: LayoutBuilder(builder: (context, box) {
          const dash = 6.0, gap = 4.0;
          final count = ((box.maxWidth - 32) / (dash + gap)).floor().clamp(0, 400);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (var i = 0; i < count; i++)
                Container(
                  width: dash,
                  height: 1,
                  margin: const EdgeInsets.only(right: gap),
                  color: AppColors.border,
                ),
            ]),
          );
        }),
      );
}

/// An order status as a small pill: navy while it moves, green when delivered,
/// red when cancelled.
class PortalStatusPill extends StatelessWidget {
  const PortalStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'DELIVERED' => (const Color(0xFFE7F7F0), const Color(0xFF047857)),
      'CANCELLED' => (const Color(0xFFFDECEC), AppColors.danger),
      'OUT_FOR_DELIVERY' => (AppColors.accentSoft, AppColors.accent),
      _ => (AppColors.primary, AppColors.onPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(portalStatusLabels[status] ?? status,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// The five steps a customer sees (the shop's Processing and Ironing are both
/// "Cleaning"): Booked · Cleaning · Ready · Out for delivery · Delivered.
const portalSteps = ['Booked', 'Cleaning', 'Ready', 'Out for delivery', 'Delivered'];

/// How far along [status] is in [portalSteps] (0-4), or -1 when cancelled.
int portalStepIndex(String status) => switch (status) {
      'PLACED' => 0,
      'PROCESSING' || 'IRONING' => 1,
      'READY' => 2,
      'OUT_FOR_DELIVERY' => 3,
      'DELIVERED' => 4,
      _ => -1,
    };

/// Five dots on a line, done ones navy, with their labels under them.
class PortalStatusLine extends StatelessWidget {
  const PortalStatusLine({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final at = portalStepIndex(status);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < portalSteps.length; i++)
        Expanded(
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: Container(
                      height: 2,
                      color: i == 0
                          ? Colors.transparent
                          : i <= at
                              ? AppColors.primary
                              : AppColors.border)),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= at ? AppColors.primary : AppColors.card,
                  border: Border.all(
                      color: i <= at ? AppColors.primary : AppColors.border, width: 2),
                ),
              ),
              Expanded(
                  child: Container(
                      height: 2,
                      color: i == portalSteps.length - 1
                          ? Colors.transparent
                          : i < at
                              ? AppColors.primary
                              : AppColors.border)),
            ]),
            const SizedBox(height: 6),
            Text(portalSteps[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: i == at ? FontWeight.w600 : FontWeight.w400,
                    color: i <= at ? AppColors.ink : AppColors.muted)),
          ]),
        ),
    ]);
  }
}
