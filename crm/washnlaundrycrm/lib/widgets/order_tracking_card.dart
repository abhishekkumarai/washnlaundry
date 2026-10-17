import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';

/// Live rider tracking for a customer's home pickup / delivery order.
///
/// Polls `GET /customer/orders/<number>/track/` and draws the shop, the
/// customer's address and the rider on OpenStreetMap tiles. Renders nothing
/// until a rider task exists, and stops polling once the task is finished.
class OrderTrackingCard extends StatefulWidget {
  const OrderTrackingCard({
    super.key,
    required this.orderNumber,
    this.fetch,
    this.pollInterval = const Duration(seconds: 5),
    this.showTiles = true,
  });

  final String orderNumber;

  /// Test seam; defaults to [ApiService.fetchOrderTrack].
  final Future<Map<String, dynamic>> Function(String orderNumber)? fetch;
  final Duration pollInterval;

  /// Tests turn this off so no network tiles are requested.
  final bool showTiles;

  @override
  State<OrderTrackingCard> createState() => _OrderTrackingCardState();
}

class _OrderTrackingCardState extends State<OrderTrackingCard> {
  Map<String, dynamic>? _track;
  Timer? _timer;
  bool _failed = false;

  static const _statusLabels = {
    'ASSIGNED': 'Rider assigned',
    'EN_ROUTE': 'On the way',
    'COMPLETED': 'Completed',
  };

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(widget.pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final t =
          await (widget.fetch ?? ApiService.fetchOrderTrack)(widget.orderNumber);
      if (!mounted) return;
      setState(() {
        _track = t;
        _failed = false;
      });
      final status = t['status'];
      if (t['tracking'] == true &&
          (status == 'COMPLETED' || status == 'CANCELLED')) {
        _timer?.cancel();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  LatLng? _point(Object? m) {
    if (m is! Map) return null;
    final lat = m['lat'], lng = m['lng'];
    return lat is num && lng is num
        ? LatLng(lat.toDouble(), lng.toDouble())
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = _track;
    if (t == null || t['tracking'] != true) return const SizedBox.shrink();
    final pickup = _point(t['pickup']),
        drop = _point(t['drop']),
        rider = _point(t['location']);
    if (pickup == null || drop == null) return const SizedBox.shrink();

    final isPickup = t['kind'] == 'PICKUP';
    final active = t['status'] != 'COMPLETED';
    final riderInfo = t['rider'] as Map?;
    final otp = t['otp'] as String?;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: const Key('order-tracking-card'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(isPickup ? 'Pickup tracking' : 'Delivery tracking',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Chip(label: Text(_statusLabels[t['status']] ?? '${t['status']}')),
            ]),
            if (riderInfo != null)
              Text('Rider: ${riderInfo['name']}',
                  style: Theme.of(context).textTheme.bodyMedium),
            if (_failed)
              Text('Reconnecting…', style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.coordinates(
                      coordinates: [pickup, drop],
                      padding: const EdgeInsets.all(48),
                    ),
                  ),
                  children: [
                    if (widget.showTiles)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.washnlaundry.crm',
                      ),
                    MarkerLayer(markers: [
                      Marker(
                          point: pickup,
                          child: Icon(Icons.store, color: scheme.primary)),
                      Marker(
                          point: drop,
                          child: Icon(Icons.home, color: scheme.tertiary)),
                      if (rider != null && active)
                        Marker(
                          point: rider,
                          child: const Icon(Icons.two_wheeler,
                              key: Key('rider-marker'),
                              color: Color(0xFFD97706),
                              size: 30),
                        ),
                    ]),
                    if (widget.showTiles)
                      const SimpleAttributionWidget(
                          source: Text('© OpenStreetMap contributors')),
                  ],
                ),
              ),
            ),
            if (otp != null && otp.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                  'Share this code with the rider to confirm ${isPickup ? 'pickup' : 'delivery'}:',
                  style: Theme.of(context).textTheme.bodySmall),
              Text(otp,
                  key: const Key('tracking-otp'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(letterSpacing: 6)),
            ],
          ],
        ),
      ),
    );
  }
}
