import 'package:flutter/material.dart';
import '../widgets/sidebar_navigation.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  int _selectedTab = 0; // 0: Roster, 1: App Logins
  String _searchQuery = '';
  bool _showInactive = false;

  final List<Map<String, dynamic>> _staffMembers = [
    {
      'id': 1,
      'name': 'Ramesh Kumar',
      'role': 'Head Washer',
      'phone': '+91 97112 23344',
      'wage': 650.0,
      'status': 'ACTIVE',
      'isDriver': false,
      'hasAppLogin': true,
    },
    {
      'id': 2,
      'name': 'Sunil Paswan',
      'role': 'Steam Press Master',
      'phone': '+91 98114 45566',
      'wage': 600.0,
      'status': 'ACTIVE',
      'isDriver': false,
      'hasAppLogin': false,
    },
    {
      'id': 3,
      'name': 'Geeta Devi',
      'role': 'Dry Cleaning Specialist',
      'phone': '+91 99223 34455',
      'wage': 700.0,
      'status': 'ACTIVE',
      'isDriver': false,
      'hasAppLogin': false,
    },
    {
      'id': 4,
      'name': 'Mohan Das',
      'role': 'Delivery Driver',
      'phone': '+91 99334 41122',
      'wage': 580.0,
      'status': 'ACTIVE',
      'isDriver': true,
      'hasAppLogin': true,
    },
    {
      'id': 5,
      'name': 'Lakshman Rao',
      'role': 'Manager',
      'phone': '+91 99445 56677',
      'wage': 900.0,
      'status': 'ACTIVE',
      'isDriver': false,
      'hasAppLogin': true,
    },
    {
      'id': 6,
      'name': 'Anita Sharma',
      'role': 'Ironing Specialist',
      'phone': '+91 99556 67788',
      'wage': 620.0,
      'status': 'ACTIVE',
      'isDriver': false,
      'hasAppLogin': false,
    },
  ];

  List<Map<String, dynamic>> get _filteredStaff {
    return _staffMembers.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s['role'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s['phone'].toString().contains(_searchQuery);
      final matchesInactive = _showInactive || s['status'] == 'ACTIVE';
      return matchesSearch && matchesInactive;
    }).toList();
  }

  void _showAddStaffModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Washer');
    final wageCtrl = TextEditingController(text: '600');
    bool isDeliveryAgent = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Add Staff Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Full Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Ramesh Kumar',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Phone Number *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+91 98765 43210',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Role / Designation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: roleCtrl,
                              decoration: InputDecoration(
                                hintText: 'Head Washer / Ironer',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Daily Wage (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: wageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '600',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Checkbox(
                        value: isDeliveryAgent,
                        activeColor: const Color(0xFF1A4FD6),
                        onChanged: (v) => setModalState(() => isDeliveryAgent = v ?? false),
                      ),
                      const Text('Mark as Delivery Agent / Driver', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _staffMembers.add({
                    'id': _staffMembers.length + 1,
                    'name': nameCtrl.text.trim(),
                    'role': roleCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'wage': double.tryParse(wageCtrl.text) ?? 600.0,
                    'status': 'ACTIVE',
                    'isDriver': isDeliveryAgent,
                    'hasAppLogin': false,
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added staff member "${nameCtrl.text.trim()}"'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _staffMembers.where((s) => s['status'] == 'ACTIVE').length;
    final inactiveCount = _staffMembers.length - activeCount;
    final appLoginsCount = _staffMembers.where((s) => s['hasAppLogin'] == true).length;
    final driverCount = _staffMembers.where((s) => s['isDriver'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                // Header Bar
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Text('Staff', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      Text('${_staffMembers.length} members', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      const Spacer(),

                      // Search Box
                      Container(
                        width: 220,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search staff...',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      Row(
                        children: [
                          Checkbox(
                            value: _showInactive,
                            activeColor: const Color(0xFF1A4FD6),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) => setState(() => _showInactive = v ?? false),
                          ),
                          const Text('Show Inactive', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        ],
                      ),
                      const SizedBox(width: 14),

                      ElevatedButton.icon(
                        onPressed: () => _showAddStaffModal(context),
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text('+ Add Staff', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A4FD6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sub-Tabs Bar (Roster / App Logins)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      _buildSubTab(0, 'Roster'),
                      const SizedBox(width: 8),
                      _buildSubTab(1, 'App Logins'),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top 4 KPI Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                icon: Icons.people_outline_rounded,
                                iconBg: const Color(0xFFEEF2FF),
                                iconColor: const Color(0xFF1A4FD6),
                                val: '$activeCount',
                                label: 'Active staff',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiCard(
                                icon: Icons.person_off_outlined,
                                iconBg: const Color(0xFFECFDF5),
                                iconColor: const Color(0xFF10B981),
                                val: '$inactiveCount',
                                label: 'Inactive',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiCard(
                                icon: Icons.smartphone_rounded,
                                iconBg: const Color(0xFFF3E8FF),
                                iconColor: const Color(0xFFA855F7),
                                val: '$appLoginsCount',
                                label: 'App logins · of ${_staffMembers.length} on plan',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiCard(
                                icon: Icons.location_on_outlined,
                                iconBg: const Color(0xFFE0F2FE),
                                iconColor: const Color(0xFF0284C7),
                                val: '$driverCount',
                                label: 'Delivery agents',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Staff Grid / List
                        _filteredStaff.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 60),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.people_outline_rounded, size: 36, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('No staff members found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 4),
                                    const Text('Add your first staff member to get started.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => _showAddStaffModal(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1A4FD6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    // Table Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(flex: 3, child: Text('STAFF MEMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 2, child: Text('ROLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 2, child: Text('PHONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 2, child: Text('DAILY WAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                                          SizedBox(width: 48),
                                        ],
                                      ),
                                    ),

                                    // Rows
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _filteredStaff.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final s = _filteredStaff[idx];
                                        final isActive = s['status'] == 'ACTIVE';

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                          child: Row(
                                            children: [
                                              // Member Name & Avatar
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 18,
                                                      backgroundColor: const Color(0xFFEEF2FF),
                                                      child: Text(
                                                        s['name'][0],
                                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A4FD6)),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(s['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                        if (s['isDriver'] == true)
                                                          const Text('Delivery Agent', style: TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Role
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                                  child: Text(s['role'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                                ),
                                              ),

                                              // Phone
                                              Expanded(
                                                flex: 2,
                                                child: Text(s['phone'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                              ),

                                              // Wage
                                              Expanded(
                                                flex: 2,
                                                child: Text('₹${(s['wage'] as double).toInt()} / day', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                              ),

                                              // Status Badge
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.circle, size: 6, color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                                      const SizedBox(width: 4),
                                                      Text(isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                                onPressed: () {},
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
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

  Widget _buildSubTab(int idx, String title) {
    final isSel = _selectedTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFEEF2FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
            color: isSel ? const Color(0xFF1A4FD6) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String val,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
