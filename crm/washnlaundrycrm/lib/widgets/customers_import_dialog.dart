import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// The Customers "Import" flow: pick a CSV/XLSX file, confirm which of its
/// columns map to which `Customer` field (server-suggested, editable), then
/// commit. Rows missing a name/phone or duplicating a phone number are
/// dropped server-side rather than failing the whole import — the final
/// step just reports how many.
class ImportCustomersDialog extends StatefulWidget {
  const ImportCustomersDialog();

  @override
  State<ImportCustomersDialog> createState() => ImportCustomersDialogState();
}

class ImportCustomersDialogState extends State<ImportCustomersDialog> {
  // (field, label, required) — mirrors backend/api/customer_import.py's
  // TARGET_FIELDS/REQUIRED_FIELDS. Only name/phone are actually required by
  // the Customer model; everything else already has a blank/zero default.
  static const _fields = [
    ('name', 'Name', true),
    ('phone', 'Phone', true),
    ('email', 'Email', false),
    ('address', 'Address', false),
    ('area', 'Area', false),
    ('notes', 'Notes', false),
  ];

  Uint8List? _bytes;
  String? _filename;
  List<String> _columns = const [];
  List<List<String>> _sampleRows = const [];
  int _rowCount = 0;
  final Map<String, String?> _mapping = {};
  bool _overwriteDuplicates = false;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  bool get _hasPreview => _columns.isNotEmpty;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }

    setState(() {
      _bytes = bytes;
      _filename = file.name;
      _loading = true;
    });
    try {
      final preview = await ApiService.importCustomersPreview(bytes, file.name);
      final suggested =
          (preview['suggested_mapping'] as Map).cast<String, dynamic>();
      setState(() {
        _columns = (preview['columns'] as List).cast<String>();
        _sampleRows = (preview['sample_rows'] as List)
            .map((row) => (row as List).map((c) => c.toString()).toList())
            .toList();
        _rowCount = preview['row_count'] as int;
        for (final f in _fields) {
          _mapping[f.$1] = suggested[f.$1] as String?;
        }
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _commit() async {
    if (_mapping['name'] == null || _mapping['phone'] == null) {
      setState(() =>
          _error = 'Map both a Name column and a Phone column to continue.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final mapping = {
      for (final entry in _mapping.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    try {
      final result = await ApiService.importCustomersCommit(
        _bytes!,
        _filename!,
        mapping,
        overwriteDuplicates: _overwriteDuplicates,
      );
      setState(() {
        _loading = false;
        _result = result;
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Import Customers',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF141A24))),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(child: _content()),
      ),
      actions: _actions(),
    );
  }

  Widget _content() {
    if (_result != null) return _resultStep();
    if (_hasPreview) return _mappingStep();
    return _pickStep();
  }

  Widget _pickStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Upload a CSV or Excel (.xlsx) file with your customers. Only '
          'Name and Phone are required — everything else is optional.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickFile,
          icon: const Icon(Icons.upload_file_rounded, size: 16),
          label: Text(_loading ? 'Reading file…' : 'Choose File'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFE4E0D8)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
        ],
      ],
    );
  }

  Widget _mappingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$_filename — $_rowCount row${_rowCount == 1 ? '' : 's'} found.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        if (_sampleRows.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 28,
              dataRowMaxHeight: 28,
              columnSpacing: 16,
              columns: [
                for (final c in _columns)
                  DataColumn(
                      label: Text(c,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold))),
              ],
              rows: [
                for (final row in _sampleRows)
                  DataRow(cells: [
                    for (var i = 0; i < _columns.length; i++)
                      DataCell(Text(i < row.length ? row[i] : '',
                          style: const TextStyle(fontSize: 11))),
                  ]),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Text('Match each field to a column from your file.',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155))),
        const SizedBox(height: 8),
        for (final f in _fields) _mappingRow(f.$1, f.$2, f.$3),
        const SizedBox(height: 4),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () =>
              setState(() => _overwriteDuplicates = !_overwriteDuplicates),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _overwriteDuplicates,
                  onChanged: (v) =>
                      setState(() => _overwriteDuplicates = v ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Update existing customers with a matching phone '
                      'number instead of skipping them (their phone number '
                      'itself is never changed).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
        ],
      ],
    );
  }

  Widget _mappingRow(String field, String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text('$label${required ? ' *' : ''}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF141A24))),
          ),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _mapping[field],
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Not mapped —')),
                for (final c in _columns)
                  DropdownMenuItem<String?>(
                      value: c,
                      child: Text(c, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _mapping[field] = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultStep() {
    final r = _result!;
    final created = r['created'] as int;
    final updated = r['updated'] as int? ?? 0;
    final skippedMissing = r['skipped_missing'] as int;
    final skippedDuplicate = r['skipped_duplicate'] as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$created customer${created == 1 ? '' : 's'} imported.',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24))),
        if (updated > 0) ...[
          const SizedBox(height: 8),
          Text('$updated existing customer${updated == 1 ? '' : 's'} updated.',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
        ],
        if (skippedMissing > 0) ...[
          const SizedBox(height: 8),
          Text(
              '$skippedMissing row${skippedMissing == 1 ? '' : 's'} skipped — missing name or phone.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
        if (skippedDuplicate > 0) ...[
          const SizedBox(height: 8),
          Text(
              '$skippedDuplicate row${skippedDuplicate == 1 ? '' : 's'} skipped — duplicate phone number.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ],
    );
  }

  List<Widget> _actions() {
    if (_result != null) {
      return [
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              (_result!['created'] as int) > 0 ||
                  ((_result!['updated'] as int?) ?? 0) > 0),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF182C4F),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Done'),
        ),
      ];
    }
    return [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
      ),
      if (_hasPreview)
        FilledButton(
          onPressed: _loading ? null : _commit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF182C4F),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(_loading ? 'Importing…' : 'Import'),
        ),
    ];
  }
}
