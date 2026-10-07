import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'panel_card.dart';

class OrderPipelineCard extends StatelessWidget {
  final bool collapsible;

  const OrderPipelineCard({super.key, this.collapsible = false});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    final stages = [
      {
        'label': 'Received',
        'count': provider.pipelineReceived,
        'color': const Color(0xFF64748B)
      },
      {
        'label': 'Processing',
        'count': provider.pipelineProcessing,
        'color': const Color(0xFF182C4F)
      },
      {
        'label': 'Ready',
        'count': provider.pipelineReady,
        'color': const Color(0xFF10B981)
      },
      {
        'label': 'Out for delivery',
        'count': provider.pipelineOutForDelivery,
        'color': const Color(0xFF0284C7)
      },
    ];

    // The headline is the pipeline's own total, not "orders today" — an order
    // placed yesterday and still processing belongs in this count.
    final inPipeline =
        stages.fold<int>(0, (sum, s) => sum + (s['count'] as int));

    return PanelCard(
      title: 'Order pipeline',
      subtitle: 'Live across stages',
      collapsible: collapsible,
      trailing: Text(
        '$inPipeline',
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF141A24)),
      ),
      child: Column(
        children: stages.map((st) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: st['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          st['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: (st['count'] as int) > 0
                                ? const Color(0xFF141A24)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${st['count']}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: (st['count'] as int) > 0
                            ? const Color(0xFF141A24)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
    );
  }
}
