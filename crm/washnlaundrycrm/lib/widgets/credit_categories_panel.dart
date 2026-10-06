import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';

/// Settings → Credit categories: the shop's own list of what a credit can be
/// filed under. Every change saves immediately, so there is no Save button.
///
/// A category already used by a credit can't be deleted (the backend's
/// `Credit.category` is PROTECT) — it can only be turned off, which hides it
/// from new credits while the old ones keep their label.
class CreditCategoriesPanel extends StatefulWidget {
  const CreditCategoriesPanel({super.key});

  @override
  State<CreditCategoriesPanel> createState() => _CreditCategoriesPanelState();
}

class _CreditCategoriesPanelState extends State<CreditCategoriesPanel> {
  final _addController = TextEditingController();
  bool _adding = false;
  String? _addError;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? const Color(0xFFDC2626) : const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _add() async {
    final name = _addController.text.trim();
    if (name.isEmpty) {
      setState(() => _addError = 'Enter a category name.');
      return;
    }
    setState(() {
      _adding = true;
      _addError = null;
    });
    final error = await context.read<AppProvider>().addCreditCategory(name);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _addError = error;
    });
    if (error == null) {
      _addController.clear();
      _toast('"$name" added');
    }
  }

  Future<void> _toggle(CreditCategoryModel category, bool active) async {
    final error = await context
        .read<AppProvider>()
        .updateCreditCategory(category.id, {'is_active': active});
    if (!mounted) return;
    if (error != null) _toast(error, error: true);
  }

  Future<void> _rename(CreditCategoryModel category) async {
    final controller = TextEditingController(text: category.name);
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Rename category'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (category.creditCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'The ${_credits(category.creditCount)} filed under it '
                    'will show the new name.',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFDC2626))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        setDialogState(() => error = 'Enter a category name.');
                        return;
                      }
                      if (name == category.name) {
                        Navigator.of(dialogContext).pop();
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      final result = await context
                          .read<AppProvider>()
                          .updateCreditCategory(category.id, {'name': name});
                      if (!dialogContext.mounted) return;
                      if (result == null) {
                        Navigator.of(dialogContext).pop();
                      } else {
                        setDialogState(() {
                          saving = false;
                          error = result;
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _delete(CreditCategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('"${category.name}" will be removed from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error =
        await context.read<AppProvider>().deleteCreditCategory(category.id);
    if (!mounted) return;
    _toast(error ?? '"${category.name}" deleted', error: error != null);
  }

  static String _credits(int n) => n == 1 ? '1 credit' : '$n credits';

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<AppProvider>().creditCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Credit categories',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
        const Text(
            'What money coming into the shop can be filed under on the '
            'Credits page. Turned-off categories stay on past credits but '
            "can't be picked for new ones.",
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 20),

        // Add row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('credit-category-add-field'),
                controller: _addController,
                style: const TextStyle(fontSize: 13),
                onSubmitted: (_) => _adding ? null : _add(),
                decoration: InputDecoration(
                  hintText: 'New category, e.g. Ironing Income',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  errorText: _addError,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _adding ? null : _add,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Add',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A4FD6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No categories yet — add the first one above.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _row(categories[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(CreditCategoryModel c) {
    final inUse = c.creditCount > 0;
    return Padding(
      key: ValueKey('credit-category-${c.id}'),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.isActive
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8))),
                Text(
                  inUse ? _credits(c.creditCount) : 'Not used yet',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Tooltip(
            message: c.isActive
                ? 'Turn off — hide from new credits'
                : 'Turn on — offer for new credits',
            child: Switch(
              value: c.isActive,
              activeTrackColor: const Color(0xFF10B981),
              onChanged: (v) => _toggle(c, v),
            ),
          ),
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: Color(0xFF64748B)),
            onPressed: () => _rename(c),
          ),
          IconButton(
            tooltip: inUse ? 'In use — turn it off instead' : 'Delete',
            icon: Icon(Icons.delete_outline,
                size: 18,
                color: inUse
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFDC2626)),
            onPressed: inUse ? null : () => _delete(c),
          ),
        ],
      ),
    );
  }
}
