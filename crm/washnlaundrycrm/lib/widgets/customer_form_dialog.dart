import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';

/// Add/edit-customer dialog shared by the Customers and New Order screens.
///
/// [existing] null adds a customer; non-null edits it in place. Same dialog
/// either way — only the title, button label, and which provider call fires
/// differ. Resolves to true when the customer was saved, false/null otherwise.
Future<bool?> showCustomerFormDialog(BuildContext context,
    {CustomerModel? existing}) async {
  final isEdit = existing != null;
  final nameController = TextEditingController(text: existing?.name ?? '');
  final phoneController = TextEditingController(text: existing?.phone ?? '');
  final emailController = TextEditingController(text: existing?.email ?? '');
  final areaController = TextEditingController(text: existing?.area ?? '');
  final provider = context.read<AppProvider>();

  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      String? error;
      bool saving = false;

      return StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Edit Customer' : 'Add Customer',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
          content: SizedBox(
            width: math.min(420.0, MediaQuery.sizeOf(ctx).width - 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field('Full Name', nameController, 'e.g. Ramesh Kumar'),
                _field(
                  'Phone Number (10 digits, no ISD code)',
                  phoneController,
                  '9876543210',
                  keyboard: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                _field('Email', emailController, 'name@example.com',
                    keyboard: TextInputType.emailAddress),
                _field('Area / Locality', areaController,
                    'e.g. HBR Layout, Bengaluru'),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(error!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFDC2626))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      if (name.isEmpty || phone.isEmpty) {
                        setDialogState(() =>
                            error = 'Name and phone are both required.');
                        return;
                      }
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                        setDialogState(() => error =
                            'Mobile number must be exactly 10 digits starting with 6-9 (no ISD / country code or leading 0).');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      final payload = {
                        'name': name,
                        'phone': phone,
                        'email': emailController.text.trim(),
                        'area': areaController.text.trim(),
                      };
                      final ok = isEdit
                          ? await provider.updateCustomer(existing.id, payload)
                          : await provider.addCustomer(payload);
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.pop(ctx, true);
                      } else {
                        setDialogState(() {
                          saving = false;
                          error = provider.error ??
                              'Could not ${isEdit ? 'save' : 'add'} the customer.';
                        });
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF182C4F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                saving
                    ? 'Saving…'
                    : (isEdit ? 'Save Changes' : 'Add Customer'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _field(
  String label,
  TextEditingController controller,
  String hint, {
  TextInputType? keyboard,
  List<TextInputFormatter>? inputFormatters,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ),
  );
}
