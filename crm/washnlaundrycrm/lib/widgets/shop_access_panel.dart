import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_service.dart';

/// Settings → Shop access: who can sign in to this shop, hand it to another
/// member, or close it. Closing archives the shop (data is kept; only support
/// can purge it), so it is reversible by support but not from this screen.
class ShopAccessPanel extends StatefulWidget {
  const ShopAccessPanel({super.key});

  @override
  State<ShopAccessPanel> createState() => _ShopAccessPanelState();
}

class _ShopAccessPanelState extends State<ShopAccessPanel> {
  List<Map<String, dynamic>> _members = const [];
  bool _loading = true;
  String? _error;

  int? get _shopId {
    final id = context.read<AppProvider>().shop?['id'];
    return id is int ? id : int.tryParse('$id');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          error ? const Color(0xFFDC2626) : const Color(0xFF10B981),
    ));
  }

  Future<void> _load() async {
    final id = _shopId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'No shop selected.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await ApiService.fetchShopMembers(id);
      if (mounted) setState(() => _members = members);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load members: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transfer() async {
    final id = _shopId;
    if (id == null) return;
    final candidates = _members
        .where((m) => m['role'] != 'OWNER' && m['is_active'] == true)
        .map((m) => m['email'] as String)
        .toList();
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _TransferDialog(candidates: candidates),
    );
    if (email == null) return;
    try {
      await ApiService.transferShopOwnership(id, email);
      _toast('Ownership transferred to $email. You are now staff.');
      if (!mounted) return;
      await context.read<AppProvider>().refresh();
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    }
  }

  Future<void> _close() async {
    final provider = context.read<AppProvider>();
    final shop = provider.shop;
    final id = _shopId;
    if (shop == null || id == null) return;
    final slug = '${shop['slug'] ?? ''}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _CloseShopDialog(name: '${shop['name']}', slug: slug),
    );
    if (confirmed != true) return;
    try {
      await ApiService.archiveShop(id);
      final remaining = await ApiService.fetchShops();
      provider.setAvailableShops(remaining);
      if (remaining.isNotEmpty) {
        _toast('Shop closed. Switched to ${remaining.first['name']}.');
        await provider.switchShop('${remaining.first['slug'] ?? remaining.first['id']}');
      } else {
        _toast('Shop closed. You have no other shops.');
        await provider.refresh();
      }
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<AppProvider>().shop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Shop access',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24))),
        const SizedBox(height: 6),
        Text(
          'People who can sign in to ${shop?['name'] ?? 'this shop'}. Add or '
          'remove staff from the Staff screen; owners are managed here.',
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 16),
        _membersTable(),
        const SizedBox(height: 28),
        const Text('Transfer ownership',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24))),
        const SizedBox(height: 6),
        const Text(
          'Hand this shop to another member. They become the owner and you '
          'become staff.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('transfer-ownership'),
          onPressed: _loading ? null : _transfer,
          child: const Text('Transfer ownership…'),
        ),
        const SizedBox(height: 28),
        const Text('Close this shop',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB91C1C))),
        const SizedBox(height: 6),
        const Text(
          'Closing stops the shop from serving orders, customers and sign-ins. '
          'Its data is kept; contact support to reopen or permanently delete it.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('close-shop'),
          onPressed: shop == null ? null : _close,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB91C1C),
            side: const BorderSide(color: Color(0xFFFCA5A5)),
          ),
          child: const Text('Close shop…'),
        ),
      ],
    );
  }

  Widget _membersTable() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Row(children: [
        Expanded(
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ]);
    }
    if (_members.isEmpty) {
      return const Text('No members yet.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)));
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E0D8)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        for (var i = 0; i < _members.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: Color(0xFFE4E0D8)),
          ListTile(
            dense: true,
            title: Text('${_members[i]['email']}',
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(
                _members[i]['is_active'] == true ? 'Active' : 'Inactive',
                style: const TextStyle(fontSize: 11)),
            trailing: Text(
              _roleLabel('${_members[i]['role']}'),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155)),
            ),
          ),
        ],
      ]),
    );
  }

  static String _roleLabel(String role) =>
      role.isEmpty ? role : role[0] + role.substring(1).toLowerCase();
}

class _TransferDialog extends StatefulWidget {
  final List<String> candidates;
  const _TransferDialog({required this.candidates});

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer ownership'),
      content: widget.candidates.isEmpty
          ? const Text('There is no other active member to hand the shop to. '
              'Add them as staff with a sign-in email first.')
          : DropdownButtonFormField<String>(
              initialValue: _selected,
              hint: const Text('Choose a member'),
              items: [
                for (final c in widget.candidates)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _selected = v),
            ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed:
              _selected == null ? null : () => Navigator.pop(context, _selected),
          child: const Text('Transfer'),
        ),
      ],
    );
  }
}

class _CloseShopDialog extends StatefulWidget {
  final String name;
  final String slug;
  const _CloseShopDialog({required this.name, required this.slug});

  @override
  State<_CloseShopDialog> createState() => _CloseShopDialogState();
}

class _CloseShopDialogState extends State<_CloseShopDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _controller.text.trim() == widget.slug;
    return AlertDialog(
      title: Text('Close ${widget.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Everyone is signed out of this shop and it stops '
              'serving requests. Type the shop code to confirm:'),
          const SizedBox(height: 8),
          Text(widget.slug,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C)),
          child: const Text('Close shop'),
        ),
      ],
    );
  }
}
