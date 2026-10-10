import 'package:flutter/material.dart';

/// Single source of truth for the contact details shown under Help & Support
/// (sidebar dialog) and on the 404 / 5xx error screens.
class SupportInfo {
  static const email = 'support@washnlaundry.com';
  static const phone = '+91 80 4567 8900';
  static const hours = 'Mon – Sat, 9:00 AM – 8:00 PM';
}

/// "Still stuck? Contact support" block for error screens.
class SupportContactCard extends StatelessWidget {
  const SupportContactCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text('$label: ',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF141A24))),
              Flexible(
                child: SelectableText(value,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
              ),
            ],
          ),
        );

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Still not working? Contact support',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24)),
          ),
          row(Icons.email_outlined, 'Email', SupportInfo.email),
          row(Icons.phone_outlined, 'Phone', SupportInfo.phone),
          row(Icons.schedule_outlined, 'Hours', SupportInfo.hours),
        ],
      ),
    );
  }
}
