import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_navigation.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();

  final List<Map<String, dynamic>> _staff = [
    {'name': 'Ramesh Kumar',  'role': 'Head Washer',          'status': 'PRESENT'},
    {'name': 'Sunil Paswan',  'role': 'Steam Press Master',   'status': 'PRESENT'},
    {'name': 'Geeta Devi',    'role': 'Dry Cleaning Specialist','status': 'PRESENT'},
    {'name': 'Mohan Das',     'role': 'Delivery Driver',      'status': 'HALF_DAY'},
    {'name': 'Lakshman Rao',  'role': 'Manager',              'status': 'PRESENT'},
    {'name': 'Anita Sharma',  'role': 'Ironing Specialist',   'status': 'ABSENT'},
  ];

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A4FD6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Text('Attendance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      Text(DateFormat('MMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      const Spacer(),

                      // Calendar Date Picker Button
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(context),
                        icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF1A4FD6)),
                        label: Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1A4FD6)),
                          backgroundColor: const Color(0xFFEEF2FF),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Daily Attendance Register', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                Text('Mark staff presence for $formattedDate', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Attendance saved successfully'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                              label: const Text('Save Register', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A4FD6),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _staff.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final s = _staff[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFEEF2FF),
                                  child: Text(s['name'][0], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6))),
                                ),
                                title: Text(s['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                subtitle: Text(s['role'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                trailing: Wrap(
                                  spacing: 6,
                                  children: ['PRESENT', 'HALF_DAY', 'ABSENT'].map((status) {
                                    final isSel = s['status'] == status;
                                    return ChoiceChip(
                                      label: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF475569))),
                                      selected: isSel,
                                      selectedColor: status == 'PRESENT'
                                          ? const Color(0xFF10B981)
                                          : status == 'HALF_DAY'
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFFEF4444),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      onSelected: (val) {
                                        if (val) setState(() => s['status'] = status);
                                      },
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
