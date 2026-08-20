import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class OrderPipelineCard extends StatelessWidget {
  const OrderPipelineCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    final stages = [
      {'label': 'Received', 'count': provider.pipelineReceived, 'color': const Color(0xFF64748B)},
      {'label': 'Processing', 'count': provider.pipelineProcessing, 'color': const Color(0xFF1A4FD6)},
      {'label': 'Ready', 'count': provider.pipelineReady, 'color': const Color(0xFF10B981)},
      {'label': 'Out for delivery', 'count': provider.pipelineOutForDelivery, 'color': const Color(0xFF0284C7)},
    ];

    // The headline is the pipeline's own total, not "orders today" — an order
    // placed yesterday and still processing belongs in this count.
    final inPipeline =
        stages.fold<int>(0, (sum, s) => sum + (s['count'] as int));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Order pipeline',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Live across stages',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Text(
                '$inPipeline',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stages List
          Column(
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
                            color: (st['count'] as int) > 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${st['count']}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: (st['count'] as int) > 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
