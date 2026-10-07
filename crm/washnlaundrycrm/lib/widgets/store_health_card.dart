import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/navigation.dart';
import 'panel_card.dart';

/// "Store Health — Operational performance · last 30 days": a 0–100 score with
/// the four metrics behind it.
class StoreHealthCard extends StatelessWidget {
  final bool collapsible;

  const StoreHealthCard({super.key, this.collapsible = false});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<AppProvider>().stats['store_health']
            as Map<String, dynamic>? ??
        const {};

    final score = (health['score'] as num?)?.toInt() ?? 0;
    final verdict = health['verdict'] as String? ?? '—';
    final onSchedule = (health['active_on_schedule'] as num?)?.toInt() ?? 0;

    final scoreColor = score >= 80
        ? const Color(0xFF10B981)
        : score >= 60
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    return PanelCard(
      title: 'Store Health',
      subtitle: 'Operational performance · last 30 days',
      collapsible: collapsible,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 7,
                        backgroundColor: const Color(0xFFF1EFEA),
                        valueColor: AlwaysStoppedAnimation(scoreColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        const Text(
                          'SCORE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdict,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _metric('On-Time Delivery',
                        formatPercent(health['on_time_delivery'])),
                    _metric('On-Time Pickup',
                        formatPercent(health['on_time_pickup'])),
                    _metric('Order Flow', formatPercent(health['order_flow'])),
                    _metric('Collection Rate',
                        formatPercent(health['collection_rate'])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1EFEA)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$onSchedule active orders on schedule',
                style:
                    const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              GestureDetector(
                onTap: () => context.goSection(9),
                child: const Row(
                  children: [
                    Text(
                      'View reports',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF182C4F),
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward,
                        size: 12, color: Color(0xFF182C4F)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF141A24),
            ),
          ),
        ],
      ),
    );
  }
}
