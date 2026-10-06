import 'package:flutter/material.dart';

/// A modal error popup for a failed save/action — used in place of a
/// SnackBar, which is easy to miss and (worse, for a dialog like Add/Edit
/// Staff) used to sit behind a form that had already closed on failure,
/// discarding whatever the user had typed. Callers that show this are
/// expected to *not* pop their own dialog until the call actually succeeds,
/// so the user lands back on their still-filled-in form after dismissing it.
Future<void> showErrorDialog(
  BuildContext context, {
  String title = 'Something went wrong',
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFDC2626), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
          ),
        ],
      ),
      content: Text(message,
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A4FD6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('OK',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
