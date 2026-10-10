import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/csv_download.dart';
import 'customers_import_dialog.dart';
import 'services_import_export_panel.dart';

/// Settings → Backup & Data Export panel.
/// Allows shop owners and staff to:
/// 1. Download a complete multi-tab Excel (.xlsx) backup workbook or JSON archive of all CRM data.
/// 2. Selectively export individual sections (Staff, Orders, Attendance, Payroll, Customers, Expenses, Credits, Services)
///    in CSV or JSON formats.
class BackupExportPanel extends StatefulWidget {
  const BackupExportPanel({super.key});

  @override
  State<BackupExportPanel> createState() => _BackupExportPanelState();
}

class _BackupExportPanelState extends State<BackupExportPanel> {
  bool _exportingFullXlsx = false;
  bool _exportingFullJson = false;
  final Set<String> _exportingSections = {};

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _exportFullBackupXlsx() async {
    setState(() => _exportingFullXlsx = true);
    try {
      final bytes = await ApiService.exportBackupXlsx();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'crm_full_backup_$timestamp.xlsx';
      final ok = downloadBytes(
        filename,
        bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!ok) {
        _toast('Excel export is only supported in web browser.', error: true);
      } else {
        _toast('Full CRM backup Excel workbook (.xlsx) downloaded successfully.');
      }
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('Failed to download Excel backup: $e', error: true);
    } finally {
      if (mounted) setState(() => _exportingFullXlsx = false);
    }
  }

  Future<void> _exportFullBackupJson() async {
    setState(() => _exportingFullJson = true);
    try {
      final data = await ApiService.exportBackupJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'crm_full_backup_$timestamp.json';
      final ok = downloadString(filename, jsonStr, mimeType: 'application/json;charset=utf-8;');
      if (!ok) {
        _toast('JSON export is only supported in web browser.', error: true);
      } else {
        _toast('Full CRM backup archive (.json) downloaded successfully.');
      }
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('Failed to download JSON backup: $e', error: true);
    } finally {
      if (mounted) setState(() => _exportingFullJson = false);
    }
  }

  Future<void> _exportSectionCsv(String key, String title) async {
    final lockKey = '$key-csv';
    setState(() => _exportingSections.add(lockKey));
    try {
      final csvData = await ApiService.exportSectionCsv(key);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = '${key}_export_$timestamp.csv';
      final ok = downloadCsv(filename, csvData);
      if (!ok) {
        _toast('CSV export is only supported in web browser.', error: true);
      } else {
        _toast('$title exported as CSV successfully.');
      }
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('Failed to export $title: $e', error: true);
    } finally {
      if (mounted) setState(() => _exportingSections.remove(lockKey));
    }
  }

  Future<void> _exportSectionJson(String key, String title) async {
    final lockKey = '$key-json';
    setState(() => _exportingSections.add(lockKey));
    try {
      final data = await ApiService.exportSectionJson(key);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = '${key}_export_$timestamp.json';
      final ok = downloadString(filename, jsonStr, mimeType: 'application/json;charset=utf-8;');
      if (!ok) {
        _toast('JSON export is only supported in web browser.', error: true);
      } else {
        _toast('$title exported as JSON successfully.');
      }
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('Failed to export $title: $e', error: true);
    } finally {
      if (mounted) setState(() => _exportingSections.remove(lockKey));
    }
  }

  Future<void> _importSection(String key, String title) async {
    if (key == 'customers') {
      final imported = await showDialog<bool>(
        context: context,
        builder: (_) => const ImportCustomersDialog(),
      );
      if (imported == true && mounted) {
        await context.read<AppProvider>().refresh();
      }
      return;
    }
    if (key == 'services') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: const ServicesImportExportPanel(),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted) await context.read<AppProvider>().refresh();
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      _toast('Could not read the selected file.', error: true);
      return;
    }

    final lockKey = '$key-import';
    setState(() => _exportingSections.add(lockKey));
    try {
      final result = await ApiService.importBackupSection(key, bytes, file.name);
      if (!mounted) return;
      await _showImportResult(title, result);
      if ((result['created'] as int? ?? 0) > 0 && mounted) {
        await context.read<AppProvider>().refresh();
      }
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('Failed to import $title: $e', error: true);
    } finally {
      if (mounted) setState(() => _exportingSections.remove(lockKey));
    }
  }

  Future<void> _showImportResult(String title, Map<String, dynamic> r) {
    final errors = (r['errors'] as List? ?? const []).cast<Map>();
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title import'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r['created']} added, ${r['skipped_existing']} already existed, '
                  '${r['failed']} failed (of ${r['total']} rows)'),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Problems', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      errors.map((e) => 'Row ${e['row']}: ${e['error']}').join('\n'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _importButton(String key, String title, bool busy) {
    final importing = _exportingSections.contains('$key-import');
    return FilledButton.tonalIcon(
      onPressed: busy ? null : () => _importSection(key, title),
      icon: importing
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.upload_file_rounded, size: 14),
      label: const Text('Import', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isBusy = _exportingFullXlsx || _exportingFullJson;

    final sections = [
      (
        'staff',
        'Staff Roster',
        'Staff list, wages, contact info & active status',
        Icons.badge_outlined,
        provider.staff.length,
      ),
      (
        'orders',
        'Orders',
        'Order book, line items, customer links, delivery & payments',
        Icons.receipt_long_outlined,
        provider.orders.length,
      ),
      (
        'attendance',
        'Attendance',
        'Daily registers, check-in timestamps, status and notes',
        Icons.event_available_outlined,
        null,
      ),
      (
        'payroll',
        'Payroll & Advances',
        'Salary payouts, wage advances, dates and payment methods',
        Icons.payments_outlined,
        null,
      ),
      (
        'customers',
        'Customers',
        'Customer master records, addresses, areas & due metrics',
        Icons.people_outline_rounded,
        provider.customers.length,
      ),
      (
        'expenses',
        'Expenses',
        'Shop operating expenses, categories and payment modes',
        Icons.shopping_bag_outlined,
        provider.expenses.length,
      ),
      (
        'credits',
        'Credits',
        'Extra incoming funds, advances, delivery fees & top-ups',
        Icons.savings_outlined,
        provider.credits.length,
      ),
      (
        'services',
        'Services & Rates',
        'Price catalogue, service categories and garment rates',
        Icons.local_laundry_service_outlined,
        provider.garments.length,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Backup, Data Import & Export',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF141A24),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Download a full unified backup of all your shop data (staff roster, orders, attendance registers, payroll records, customer lists, expenses, credits, and service catalogue) as a multi-sheet Excel workbook or JSON archive, or export individual sections as CSV files. Each section can also be imported back from its own export file into the current shop; rows that already exist are skipped.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        // Section 1: Full Comprehensive Backup
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF182C4F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Full CRM Backup (All Sections)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF141A24),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Creates a complete multi-sheet Excel workbook with a dedicated tab for each section and a summary sheet, or a unified JSON archive.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: isBusy ? null : _exportFullBackupXlsx,
                    icon: _exportingFullXlsx
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.table_view_rounded, size: 18, color: Colors.white),
                    label: Text(
                      _exportingFullXlsx ? 'Generating Excel Backup…' : 'Download Complete Excel (.xlsx)',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF182C4F),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : _exportFullBackupJson,
                    icon: _exportingFullJson
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF182C4F)),
                          )
                        : const Icon(Icons.data_object_rounded, size: 18, color: Color(0xFF182C4F)),
                    label: Text(
                      _exportingFullJson ? 'Generating JSON…' : 'Download Full JSON Archive',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF182C4F)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF182C4F)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Section 2: Individual Sections Export
        const Text(
          'Individual Section Import & Export',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF141A24),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Export a module as CSV or JSON, or import a file (CSV or JSON from its export) into this shop. Import Staff before Attendance and Payroll, which match staff by name.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 750;
            return Column(
              children: sections.map((sec) {
                final key = sec.$1;
                final title = sec.$2;
                final desc = sec.$3;
                final icon = sec.$4;
                final count = sec.$5;
                final csvBusy = _exportingSections.contains('$key-csv');
                final jsonBusy = _exportingSections.contains('$key-json') ||
                    _exportingSections.contains('$key-import');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E0D8)),
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(icon, size: 20, color: const Color(0xFF182C4F)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF141A24),
                                    ),
                                  ),
                                ),
                                if (count != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$count records',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: (csvBusy || jsonBusy) ? null : () => _exportSectionCsv(key, title),
                                  icon: csvBusy
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.download_rounded, size: 14),
                                  label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: (csvBusy || jsonBusy) ? null : () => _exportSectionJson(key, title),
                                  icon: jsonBusy
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.code_rounded, size: 14),
                                  label: const Text('JSON', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                _importButton(key, title, csvBusy || jsonBusy),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, size: 20, color: const Color(0xFF182C4F)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF141A24),
                                        ),
                                      ),
                                      if (count != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$count records',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: (csvBusy || jsonBusy) ? null : () => _exportSectionCsv(key, title),
                                  icon: csvBusy
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.download_rounded, size: 14, color: Color(0xFF334155)),
                                  label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: (csvBusy || jsonBusy) ? null : () => _exportSectionJson(key, title),
                                  icon: jsonBusy
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.code_rounded, size: 14, color: Color(0xFF64748B)),
                                  label: const Text('JSON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                _importButton(key, title, csvBusy || jsonBusy),
                              ],
                            ),
                          ],
                        ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
