import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/geolocation.dart';
import 'portal_shell.dart';

/// Opens the add/edit address sheet; resolves to the saved address, or null.
Future<Map<String, dynamic>?> showAddressEditor(BuildContext context,
        {Map<String, dynamic>? address}) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: AddressEditor(address: address),
      ),
    );

/// One saved pickup address: label, address text, pincode and a map pin
/// (tap the map, or "Use my current location"). Saved to `/api/customer/addresses/`.
class AddressEditor extends StatefulWidget {
  const AddressEditor({super.key, this.address});

  final Map<String, dynamic>? address;

  @override
  State<AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<AddressEditor> {
  /// Bengaluru: where the map opens before a pin is set.
  static const _fallbackCenter = LatLng(12.9716, 77.5946);

  late final _address = TextEditingController(text: '${widget.address?['address'] ?? ''}');
  late final _landmark = TextEditingController(text: '${widget.address?['landmark'] ?? ''}');
  late final _area = TextEditingController(text: '${widget.address?['area'] ?? ''}');
  late final _pin = TextEditingController(text: '${widget.address?['pin_code'] ?? ''}');
  late String _label = '${widget.address?['label'] ?? 'HOME'}';
  late bool _default = widget.address?['is_default'] == true;
  LatLng? _point;
  final _map = MapController();
  bool _busy = false;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final lat = widget.address?['latitude'], lng = widget.address?['longitude'];
    if (lat is num && lng is num) _point = LatLng(lat.toDouble(), lng.toDouble());
  }

  @override
  void dispose() {
    for (final c in [_address, _landmark, _area, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final pos = await currentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos == null) {
        _error = 'Could not get your location. Allow location access, or tap the map.';
      } else {
        _point = LatLng(pos.$1, pos.$2);
        _map.move(_point!, 17);
      }
    });
  }

  Future<void> _save() async {
    if (_address.text.trim().isEmpty) {
      setState(() => _error = 'Enter the address.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_pin.text.trim())) {
      setState(() => _error = 'Enter a 6-digit pincode.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ApiService.saveMyAddress({
        'label': _label,
        'address': _address.text.trim(),
        'landmark': _landmark.text.trim(),
        'area': _area.text.trim(),
        'pin_code': _pin.text.trim(),
        'latitude': _point?.latitude,
        'longitude': _point?.longitude,
        'is_default': _default,
      }, id: widget.address?['id'] as int?);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  InputDecoration _field(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.address == null ? 'Add an address' : 'Edit address',
              style: AppTypography.title),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'HOME', label: Text('Home')),
              ButtonSegment(value: 'WORK', label: Text('Work')),
              ButtonSegment(value: 'OTHER', label: Text('Other')),
            ],
            selected: {_label},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _label = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _address,
              minLines: 2,
              maxLines: 3,
              decoration: _field('House / flat, street')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _area, decoration: _field('Area'))),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: _field('Pincode').copyWith(counterText: '')),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _landmark, decoration: _field('Landmark (optional)')),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(
                child: Text('Pin the exact spot for the pickup agent',
                    style: AppTypography.sectionTitle)),
            TextButton.icon(
              onPressed: _locating ? null : _locate,
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(_locating ? 'Locating…' : 'Use my location'),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 220,
              decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _point ?? _fallbackCenter,
                  initialZoom: _point == null ? 11 : 17,
                  onTap: (_, p) => setState(() => _point = p),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.washnlaundry.crm',
                  ),
                  if (_point != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _point!,
                        width: 36,
                        height: 36,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on, size: 36, color: AppColors.danger),
                      ),
                    ]),
                  RichAttributionWidget(attributions: [
                    TextSourceAttribution('OpenStreetMap contributors',
                        onTap: () =>
                            launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'))),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                _point == null
                    ? 'Tap the map to drop a pin (optional).'
                    : 'Pin set. Tap elsewhere to move it.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          CheckboxListTile(
            value: _default,
            onChanged: (v) => setState(() => _default = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Use this address by default'),
          ),
          portalError(_error),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(_busy ? 'Saving…' : 'Save address'),
          ),
        ]),
      ),
    );
  }
}
