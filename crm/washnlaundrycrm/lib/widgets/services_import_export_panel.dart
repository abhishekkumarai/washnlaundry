import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/csv_download.dart';

/// Settings → Services export/import: Allows owners/staff to export the services
/// and garment items catalogue as CSV/JSON, and bulk-import or update services
/// from CSV or Excel (.xlsx) files with column mapping.
class ServicesImportExportPanel extends StatefulWidget {
  const ServicesImportExportPanel({super.key});

  @override
  State<ServicesImportExportPanel> createState() => _ServicesImportExportPanelState();
}

class _ServicesImportExportPanelState extends State<ServicesImportExportPanel> {
  bool _exportingExcel = false;

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _exportExcel() async {
    setState(() => _exportingExcel = true);
    try {
      final bytes = await ApiService.exportServicesXlsx();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'services_catalogue_$timestamp.xlsx';
      final ok = downloadBytes(
        filename,
        bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!ok) {
        _toast('Excel export is only available in the web browser.', error: true);
      } else {
        _toast('Services Excel workbook (.xlsx) exported successfully.');
      }
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('Failed to export Excel: $e', error: true);
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  Future<void> _showImportDialog() async {
    final didImport = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ImportServicesDialog(),
    );
    if (didImport == true && mounted) {
      _toast('Services catalogue refreshed with imported data.');
      await context.read<AppProvider>().loadDataFromBackend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categoriesCount = provider.categories.length;
    final garmentsCount = provider.garments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Services export/import',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF141A24),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Export your complete services and garment pricing catalogue as an Excel (.xlsx) workbook where each service is its own tab, or import multi-tab Excel files to configure services in bulk.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        // Catalog Status Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Color(0xFF1E3A8A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Active Catalogue',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$categoriesCount categories (tabs) · $garmentsCount garment items registered',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Section 1: Export Services as Excel
        const Text(
          'Export Services to Excel (.xlsx)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Generates a formatted Excel workbook with separate tabs for every service category (e.g. Dry Cleaning, Ironing, Shoe Laundry), containing each item name, price, unit, and details in clean spreadsheet tables.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _exportingExcel ? null : _exportExcel,
          icon: _exportingExcel
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_exportingExcel ? 'Generating Excel Workbook…' : 'Export Excel Workbook (.xlsx)'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Divider(color: Color(0xFFE4E0D8)),
        ),

        // Section 2: Import Services from Excel
        const Text(
          'Import Services from Excel (.xlsx)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload an Excel (.xlsx) file where each sheet tab represents a service name, or a sheet with item tables. Missing categories are created automatically and existing prices are updated.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _showImportDialog,
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: const Text('Import Excel File (.xlsx)'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF182C4F),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

/// Modal dialog for file selection, column mapping confirmation, and execution.
class _ImportServicesDialog extends StatefulWidget {
  const _ImportServicesDialog();

  @override
  State<_ImportServicesDialog> createState() => _ImportServicesDialogState();
}

class _ImportServicesDialogState extends State<_ImportServicesDialog> {
  // Required fields: Category, Name, Price. Optional: Unit, Icon, Image URL, Is Active, Display Order.
  static const _fields = [
    ('category', 'Category', true),
    ('name', 'Item Name', true),
    ('price', 'Price / Rate', true),
    ('unit', 'Pricing Unit', false),
    ('icon', 'Item Icon', false),
    ('image_url', 'Image URL', false),
    ('is_active', 'Active Status', false),
    ('display_order', 'Sort Order', false),
  ];

  Uint8List? _bytes;
  String? _filename;
  List<String> _columns = [];
  List<List<String>> _sampleRows = [];
  int _rowCount = 0;
  final Map<String, String?> _mapping = {};
  bool _overwriteDuplicates = true;

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  bool get _hasPreview => _columns.isNotEmpty;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
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
      final preview = await ApiService.importServicesPreview(bytes, file.name);
      final suggested = (preview['suggested_mapping'] as Map?)?.cast<String, dynamic>() ?? {};
      setState(() {
        _columns = ((preview['columns'] as List?) ?? []).map((e) => e.toString()).toList();
        _sampleRows = ((preview['sample_rows'] as List?) ?? [])
            .map((row) => ((row as List?) ?? []).map((c) => c?.toString() ?? '').toList())
            .toList();
        _rowCount = preview['row_count'] as int? ?? 0;
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
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error parsing preview: $e';
      });
    }
  }

  Future<void> _commit() async {
    if (_mapping['category'] == null || _mapping['name'] == null || _mapping['price'] == null) {
      setState(() => _error = 'Please map Category, Item Name, and Price columns to continue.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final mapping = <String, String>{};
    for (final entry in _mapping.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        mapping[entry.key] = entry.value!;
      }
    }

    try {
      final result = await ApiService.importServicesCommit(
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
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to import services: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Import Services Catalogue',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF141A24),
        ),
      ),
      content: SizedBox(
        width: 520,
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
          'Upload an Excel (.xlsx) file containing your services. '
          'Each worksheet tab can represent a Service Category with an item table, '
          'or include a Category column.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickFile,
          icon: const Icon(Icons.upload_file_rounded, size: 16),
          label: Text(_loading ? 'Reading file…' : 'Choose Excel File (.xlsx)'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFE4E0D8)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
          ),
        ],
      ],
    );
  }

  Widget _mappingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$_filename — $_rowCount row${_rowCount == 1 ? '' : 's'} identified.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
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
                    label: Text(
                      c,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
              rows: [
                for (final row in _sampleRows)
                  DataRow(
                    cells: [
                      for (var i = 0; i < _columns.length; i++)
                        DataCell(
                          Text(
                            i < row.length ? row[i] : '',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Match catalogue fields to your spreadsheet columns:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 10),
        for (final f in _fields) _mappingRow(f.$1, f.$2, f.$3),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _overwriteDuplicates = !_overwriteDuplicates),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _overwriteDuplicates,
                  onChanged: (v) => setState(() => _overwriteDuplicates = v ?? true),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Update existing items if the same item already exists in that category (updates price and details).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
          ),
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
            width: 120,
            child: Text(
              '$label${required ? ' *' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF141A24)),
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _mapping[field],
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Not mapped —', style: TextStyle(fontSize: 12)),
                ),
                for (final c in _columns)
                  DropdownMenuItem<String?>(
                    value: c,
                    child: Text(c, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ),
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
    final categoriesCreated = r['categories_created'] as int? ?? 0;
    final itemsCreated = r['items_created'] as int? ?? 0;
    final itemsUpdated = r['items_updated'] as int? ?? 0;
    final skippedMissing = r['skipped_missing'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
        const SizedBox(height: 12),
        const Text(
          'Import Complete',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF141A24),
          ),
        ),
        const SizedBox(height: 10),
        if (categoriesCreated > 0)
          Text(
            '• $categoriesCreated new categories created.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
        Text(
          '• $itemsCreated garment items added.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        if (itemsUpdated > 0)
          Text(
            '• $itemsUpdated existing garment items updated.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
        if (skippedMissing > 0)
          Text(
            '• $skippedMissing rows skipped (missing category, name, or price).',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
      ],
    );
  }

  List<Widget> _actions() {
    if (_result != null) {
      return [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF182C4F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(_loading ? 'Importing…' : 'Import Services'),
        ),
    ];
  }
}
