import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'address_editor.dart';
import 'portal_shell.dart';

const _addressLabels = {'HOME': 'Home', 'WORK': 'Work', 'OTHER': 'Other'};

/// `/addresses`: the customer's saved pickup & delivery addresses for this shop.
class PortalAddressesScreen extends StatefulWidget {
  const PortalAddressesScreen({super.key});

  @override
  State<PortalAddressesScreen> createState() => _PortalAddressesScreenState();
}

class _PortalAddressesScreenState extends State<PortalAddressesScreen> {
  List<Map<String, dynamic>>? _addresses;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.fetchMyAddresses();
      if (mounted) setState(() => _addresses = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit([Map<String, dynamic>? address]) async {
    final saved = await showAddressEditor(context, address: address);
    if (saved != null) _load();
  }

  Future<void> _delete(Map<String, dynamic> address) async {
    try {
      await ApiService.deleteMyAddress(address['id'] as int);
      _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = _addresses;
    return PortalShell(
      index: PortalSection.addresses,
      title: 'Addresses',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(
            child: Text('Where we pick up and deliver.',
                style: TextStyle(fontSize: 14, color: AppColors.muted)),
          ),
          TextButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add address')),
        ]),
        portalError(_error),
        const SizedBox(height: 8),
        if (addresses == null && _error == null)
          const Center(child: CircularProgressIndicator())
        else if (addresses != null && addresses.isEmpty)
          const PortalPanel(
            child: Text('No saved addresses yet. Add one, or save it while booking a pickup.',
                style: TextStyle(color: AppColors.muted)),
          )
        else if (addresses != null)
          for (final a in addresses) ...[
            PortalPanel(
              padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        '${_addressLabels[a['label']] ?? 'Address'}'
                        '${a['is_default'] == true ? ' · default' : ''}',
                        style: AppTypography.sectionTitle),
                    const SizedBox(height: 2),
                    Text(portalAddressLine(a), style: const TextStyle(color: AppColors.muted)),
                    if (a['latitude'] != null)
                      const Text('Map pin set',
                          style: TextStyle(fontSize: 12, color: AppColors.success)),
                  ]),
                ),
                IconButton(
                    tooltip: 'Edit', onPressed: () => _edit(a), icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _delete(a),
                    icon: const Icon(Icons.delete_outline)),
              ]),
            ),
            const SizedBox(height: 8),
          ],
      ]),
    );
  }
}

/// One saved address as a single line: street, landmark, area, pincode.
String portalAddressLine(Map<String, dynamic> a) => [a['address'], a['landmark'], a['area'], a['pin_code']]
    .where((v) => v != null && '$v'.isNotEmpty)
    .join(', ');

/// "Home", "Work"... for a saved address's label.
String portalAddressLabel(Map<String, dynamic> a) => _addressLabels[a['label']] ?? 'Address';
