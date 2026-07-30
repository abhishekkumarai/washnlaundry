import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar_navigation.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  int _selectedTopTab = 0; // 0: Items, 1: Service Areas, 2: Pickup, 3: Delivery
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  bool _showInactive = false;

  final List<String> _serviceAreas = [];
  final TextEditingController _areaController = TextEditingController();

  // Pickup & Delivery slot state
  String? _pickupStartTime;
  String? _pickupEndTime;
  String _pickupCapacity = '';
  int _pickupBuffer = 0;

  String? _deliveryStartTime;
  String? _deliveryEndTime;
  String _deliveryCapacity = '';
  int _deliveryBuffer = 0;

  final List<Map<String, dynamic>> _pickupSlots = [
    {'time': '9:00 AM - 11:00 AM', 'enabled': true, 'capacity': 'Unlimited'},
    {'time': '11:00 AM - 1:00 PM', 'enabled': true, 'capacity': 'Unlimited'},
    {'time': '2:00 PM - 4:00 PM', 'enabled': true, 'capacity': 'Unlimited'},
    {'time': '4:00 PM - 6:00 PM', 'enabled': true, 'capacity': 'Unlimited'},
  ];

  final List<Map<String, dynamic>> _deliverySlots = [
    {'time': '9:00 AM - 11:00 AM', 'enabled': true, 'capacity': 'Unlimited'},
    {'time': '11:00 AM - 1:00 PM', 'enabled': true, 'capacity': 'Unlimited'},
    {'time': '2:00 PM - 4:00 PM', 'enabled': true, 'capacity': 'Unlimited'},
    {'time': '4:00 PM - 6:00 PM', 'enabled': true, 'capacity': 'Unlimited'},
  ];

  final List<String> _timeOptions = [
    '6:00 AM', '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM',
    '11:00 AM', '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM',
    '4:00 PM', '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM',
  ];

  // Presentation only — the catalogue itself comes from the API. Keyed by
  // category name so a new category added server-side still renders (with a
  // neutral fallback style) instead of crashing.
  static const Map<String, Map<String, dynamic>> _categoryStyles = {
    'Ironing':       {'icon': Icons.dry_cleaning_rounded,      'color': Color(0xFF1A4FD6), 'bg': Color(0xFFEEF2FF)},
    'Wash & Fold':   {'icon': Icons.local_laundry_service_rounded, 'color': Color(0xFF0284C7), 'bg': Color(0xFFE0F2FE)},
    'Wash & Iron':   {'icon': Icons.iron_rounded,              'color': Color(0xFFD97706), 'bg': Color(0xFFFEF3C7)},
    'Dry Cleaning':  {'icon': Icons.auto_awesome_rounded,      'color': Color(0xFF7C3AED), 'bg': Color(0xFFF3E8FF)},
    'Household':     {'icon': Icons.home_work_rounded,         'color': Color(0xFFA855F7), 'bg': Color(0xFFF3E8FF)},
    'Shoe Cleaning': {'icon': Icons.roller_skating_rounded,    'color': Color(0xFF10B981), 'bg': Color(0xFFECFDF5)},
    'Premium':       {'icon': Icons.workspace_premium_rounded, 'color': Color(0xFFEC4899), 'bg': Color(0xFFFCE7F3)},
  };

  static const Map<String, dynamic> _fallbackStyle = {
    'icon': Icons.label_outline_rounded,
    'color': Color(0xFF64748B),
    'bg': Color(0xFFF1F5F9),
  };

  // Product photography, matched on item name. Missing entries fall back to a
  // placeholder tile — the price and metadata still come from the API.
  static const Map<String, String> _itemImages = {
    'Shirt': 'https://images.unsplash.com/photo-1602810316493-c1e5e6a89dce?w=300&h=300&fit=crop',
    'T-Shirt': 'https://images.unsplash.com/photo-1527719327859-c6ce80353573?w=300&h=300&fit=crop',
    'Kurta': 'https://images.unsplash.com/photo-1594938291221-94f18cbb5660?w=300&h=300&fit=crop',
    'Suit (2 piece)': 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=300&h=300&fit=crop',
    'Pant': 'https://images.unsplash.com/photo-1624378439575-d8705ad7ae80?w=300&h=300&fit=crop',
    'Jeans': 'https://images.unsplash.com/photo-1542272604-787c3835535d?w=300&h=300&fit=crop',
    'Shorts': 'https://images.unsplash.com/photo-1591195853828-11db59a44f43?w=300&h=300&fit=crop',
    'Top / Kurti': 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=300&h=300&fit=crop',
    'Saree (Silk)': 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=300&h=300&fit=crop',
    'Sherwani': 'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=300&h=300&fit=crop',
    'Lehenga (Bridal)': 'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=300&h=300&fit=crop',
    'Blazer/Jacket': 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=300&h=300&fit=crop',
  };

  /// Categories in display order, as view-models. Rebuilt from the provider on
  /// every build so counts and price ranges always match the backend.
  List<Map<String, dynamic>> _categories = const [];

  /// Items of the selected category, honouring the search box.
  List<Map<String, dynamic>> _currentItems = const [];

  void _syncFromProvider(AppProvider provider) {
    _categories = provider.categories.map((c) {
      final style = _categoryStyles[c.name] ?? _fallbackStyle;
      return <String, dynamic>{
        'id': c.id,
        'title': c.name,
        'count': c.itemCount,
        'range': c.priceRangeLabel,
        'icon': style['icon'],
        'color': style['color'],
        'bg': style['bg'],
      };
    }).toList();

    if (_categories.isEmpty) {
      _currentItems = const [];
      return;
    }
    if (_selectedCategoryIndex >= _categories.length) _selectedCategoryIndex = 0;

    final categoryName = _categories[_selectedCategoryIndex]['title'] as String;
    final query = _searchQuery.toLowerCase();

    _currentItems = provider.garments
        .where((g) => g.categoryName == categoryName)
        .where((g) => query.isEmpty || g.name.toLowerCase().contains(query))
        .map((g) => <String, dynamic>{
              'id': g.id,
              'name': g.name,
              'price': g.price,
              'unit': g.unitLabel[0].toUpperCase() + g.unitLabel.substring(1),
              'unitShort': g.unitShortLabel,
              'turnaround': g.turnaroundLabel,
              'active': g.isActive,
              'img': _itemImages[g.name] ?? '',
            })
        .toList();
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncFromProvider(context.watch<AppProvider>());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SidebarNavigation(),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Text('Services', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(width: 8),
          Text(
            '${_categories.length} Items · ${_categories.fold<int>(0, (sum, c) => sum + (c['count'] as int))} items',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const Spacer(),
          if (_selectedTopTab == 0) ...[
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
            const SizedBox(width: 12),
            Container(
              width: 180,
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
                  hintText: 'Search items...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _headerButton(Icons.download_outlined, 'Download'),
            const SizedBox(width: 8),
            _headerButton(Icons.upload_outlined, 'Import'),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showAddItemModal(context),
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('+ New Service', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A4FD6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 15, color: const Color(0xFF475569)),
      label: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          _buildTab(0, Icons.checkroom_outlined, 'Items'),
          const SizedBox(width: 8),
          _buildTab(1, Icons.location_on_outlined, 'Service Areas'),
          const SizedBox(width: 8),
          _buildTab(2, Icons.access_time_rounded, 'Pickup'),
          const SizedBox(width: 8),
          _buildTab(3, Icons.local_shipping_outlined, 'Delivery'),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final sel = _selectedTopTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTopTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFEEF2FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: sel ? const Color(0xFF1A4FD6) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: sel ? const Color(0xFF1A4FD6) : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedTopTab) {
      case 0: return _buildItemsView();
      case 1: return _buildServiceAreasView();
      case 2: return _buildScheduleView(isPickup: true);
      case 3: return _buildScheduleView(isPickup: false);
      default: return _buildItemsView();
    }
  }

  // ─── TAB 1: Items ───────────────────────────────────────────────────
  Widget _buildItemsView() {
    final cat = _categories[_selectedCategoryIndex];
    final items = _currentItems;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Category sidebar
        Container(
          width: 264,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 16, bottom: 10),
                child: Text('SERVICE CATEGORIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final c = _categories[i];
                    final sel = _selectedCategoryIndex == i;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategoryIndex = i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFFEEF2FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? const Color(0xFF1A4FD6) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: c['bg'] as Color, borderRadius: BorderRadius.circular(8)),
                              child: Icon(c['icon'] as IconData, size: 18, color: c['color'] as Color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c['title'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? const Color(0xFF1A4FD6) : const Color(0xFF0F172A))),
                                  Text('${c['count']} items · ${c['range']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Right: Items grid
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header row
                _buildCategoryHeader(cat),
                const SizedBox(height: 20),

                // Items row header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items (${items.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    GestureDetector(
                      onTap: () => _showAddItemModal(context),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 15, color: Color(0xFF1A4FD6)),
                          SizedBox(width: 4),
                          Text('Add Item', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A4FD6))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Items grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: items.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == items.length) return _buildAddNewItemCard();
                    return _buildItemCard(items[i]);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryHeader(Map<String, dynamic> cat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: cat['bg'] as Color, borderRadius: BorderRadius.circular(10)),
            child: Icon(cat['icon'] as IconData, size: 22, color: cat['color'] as Color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cat['title'] as String, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                  ],
                ),
                Text('${cat['count']} items in ${cat['title']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Price range', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              Text(cat['range'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// Maps the free-text unit field ("per kg", "Per Piece") onto a PricingUnit
  /// code the API accepts. Anything unrecognised is treated as per-piece.
  String _unitCodeFrom(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('kg')) return PricingUnit.kg;
    if (value.contains('sq')) return PricingUnit.sqft;
    if (value.contains('set')) return PricingUnit.set;
    return PricingUnit.piece;
  }

  /// "2d" / "2 days" / "2" -> 2.
  int _turnaroundDaysFrom(String raw) {
    final digits = RegExp(r'\d+').firstMatch(raw)?.group(0);
    return int.tryParse(digits ?? '') ?? 1;
  }

  Widget _itemImagePlaceholder() => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(Icons.checkroom_rounded, color: Color(0xFFCBD5E1), size: 32),
        ),
      );

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with Active badge + edit button
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                    width: double.infinity,
                    // Most catalogue items have no photo — Image.network('')
                    // throws, so only build one when there's a URL.
                    child: (item['img'] as String).isEmpty
                        ? _itemImagePlaceholder()
                        : Image.network(
                            item['img'] as String,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _itemImagePlaceholder(),
                          ),
                  ),
                ),
                // Active badge top-right
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, size: 5, color: Color(0xFF10B981)),
                        SizedBox(width: 3),
                        Text('Active', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      ],
                    ),
                  ),
                ),
                // Edit button bottom-right
                Positioned(
                  bottom: 8, right: 8,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
                      child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details below
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                      child: Text(item['unit'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 2),
                    Text(item['turnaround'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('₹${(item['price'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const Text(' / pc', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewItemCard() {
    return GestureDetector(
      onTap: () => _showAddItemModal(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 28, color: Color(0xFF94A3B8)),
            SizedBox(height: 8),
            Text('Add new item', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: Service Areas ───────────────────────────────────────────
  Widget _buildServiceAreasView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF1A4FD6)),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Service Areas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Areas where you offer pickup/delivery', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Detect location button
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.near_me_rounded, size: 15, color: Color(0xFF1A4FD6)),
              label: const Text('Detect My Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A4FD6))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1A4FD6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 14),

            // Input + Add row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _areaController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Enter area name',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_areaController.text.trim().isNotEmpty) {
                      setState(() {
                        _serviceAreas.add(_areaController.text.trim());
                        _areaController.clear();
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 15, color: Colors.white),
                  label: const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
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

            // Areas list / empty state
            if (_serviceAreas.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.location_off_outlined, size: 40, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    Text('No areas added yet', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _serviceAreas.map((a) => Chip(
                  label: Text(a, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A4FD6))),
                  backgroundColor: const Color(0xFFEEF2FF),
                  deleteIcon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF1A4FD6)),
                  onDeleted: () => setState(() => _serviceAreas.remove(a)),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 3 & 4: Pickup / Delivery Schedule ───────────────────────────
  Widget _buildScheduleView({required bool isPickup}) {
    final title = isPickup ? 'Pickup Schedule' : 'Delivery Schedule';
    final subtitle = isPickup ? 'Time slots for home pickup' : 'Time slots for home delivery';
    final icon = isPickup ? Icons.access_time_rounded : Icons.local_shipping_outlined;
    final slots = isPickup ? _pickupSlots : _deliverySlots;
    final startTime = isPickup ? _pickupStartTime : _deliveryStartTime;
    final endTime = isPickup ? _pickupEndTime : _deliveryEndTime;
    final capacity = isPickup ? _pickupCapacity : _deliveryCapacity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, size: 20, color: const Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Changes save automatically.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Buffer section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Buffer (minutes) before slot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                const SizedBox(height: 10),
                SizedBox(
                  width: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: isPickup ? '$_pickupBuffer' : '$_deliveryBuffer',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => setState(() {
                        if (isPickup) _pickupBuffer = int.tryParse(v) ?? 0;
                        else _deliveryBuffer = int.tryParse(v) ?? 0;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isPickup
                    ? 'e.g. 30 = user cannot book 9–10 AM slot after 8:30 AM'
                    : 'e.g. 30 = user cannot book 9–10 AM slot after 8:30 AM',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Add time slot section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add time slot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Start time dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start time', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        _buildTimeDropdown(
                          value: startTime,
                          hint: 'Select start',
                          onChanged: (v) => setState(() {
                            if (isPickup) _pickupStartTime = v;
                            else _deliveryStartTime = v;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // End time dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End time', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        _buildTimeDropdown(
                          value: endTime,
                          hint: 'Select end',
                          onChanged: (v) => setState(() {
                            if (isPickup) _pickupEndTime = v;
                            else _deliveryEndTime = v;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Capacity
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Capacity', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          const SizedBox(height: 6),
                          Container(
                            height: 42,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Unlimited',
                                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              onChanged: (v) => setState(() {
                                if (isPickup) _pickupCapacity = v;
                                else _deliveryCapacity = v;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Save button
                    ElevatedButton.icon(
                      onPressed: () {
                        final st = isPickup ? _pickupStartTime : _deliveryStartTime;
                        final et = isPickup ? _pickupEndTime : _deliveryEndTime;
                        if (st != null && et != null) {
                          setState(() {
                            final cap = capacity.isEmpty ? 'Unlimited' : capacity;
                            slots.add({'time': '$st - $et', 'enabled': true, 'capacity': cap});
                            if (isPickup) { _pickupStartTime = null; _pickupEndTime = null; _pickupCapacity = ''; }
                            else { _deliveryStartTime = null; _deliveryEndTime = null; _deliveryCapacity = ''; }
                          });
                        }
                      },
                      icon: const Icon(Icons.add, size: 15, color: Colors.white),
                      label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A4FD6),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        minimumSize: const Size(0, 42),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Max orders per day for this slot; leave empty for unlimited', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Existing slots list
          ...slots.asMap().entries.map((e) {
            final idx = e.key;
            final slot = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: const Color(0xFFE2E8F0), width: idx == 0 ? 1 : 0),
                  bottom: const BorderSide(color: Color(0xFFE2E8F0)),
                  left: const BorderSide(color: Color(0xFFE2E8F0)),
                  right: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(idx == 0 ? 12 : 0),
                  topRight: Radius.circular(idx == 0 ? 12 : 0),
                  bottomLeft: Radius.circular(idx == slots.length - 1 ? 12 : 0),
                  bottomRight: Radius.circular(idx == slots.length - 1 ? 12 : 0),
                ),
              ),
              child: Row(
                children: [
                  Switch(
                    value: slot['enabled'] as bool,
                    activeColor: const Color(0xFF1A4FD6),
                    onChanged: (v) => setState(() => slot['enabled'] = v),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(slot['time'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  const SizedBox(width: 16),
                  const Text('Capacity:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(width: 4),
                  Text(slot['capacity'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1A4FD6))),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)), onPressed: () {}),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    onPressed: () => setState(() => slots.removeAt(idx)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeDropdown({required String? value, required String hint, required ValueChanged<String?> onChanged}) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showAddItemModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'Per piece');
    final turnaroundCtrl = TextEditingController(text: '1d');
    String selectedCat = _categories[_selectedCategoryIndex]['title'] as String;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Add New Service / Garment Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Service Category *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              StatefulBuilder(
                builder: (context, setModalState) {
                  return Container(
                    height: 42,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCat,
                        isExpanded: true,
                        items: _categories.map((c) => DropdownMenuItem(value: c['title'] as String, child: Text(c['title'] as String))).toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedCat = v);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              const Text('Item Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Jacket / Blazer',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Price (₹) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g. 150',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                        const Text('Unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: unitCtrl,
                          decoration: InputDecoration(
                            hintText: 'Per piece / Per pair',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text('Turnaround Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: turnaroundCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. 1d, 2d, 3d',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                final priceVal = double.tryParse(priceCtrl.text) ?? 50.0;
                final match = _categories.firstWhere(
                  (c) => c['title'] == selectedCat,
                  orElse: () => const <String, dynamic>{},
                );
                final ok = await context.read<AppProvider>().addGarmentItem({
                  'category': int.tryParse('${match['id']}'),
                  'name': nameCtrl.text.trim(),
                  'price': priceVal,
                  'unit': _unitCodeFrom(unitCtrl.text),
                  'turnaround_days': _turnaroundDaysFrom(turnaroundCtrl.text),
                });
                if (!ctx.mounted) return;
                if (!ok) {
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added "${nameCtrl.text.trim()}" to $selectedCat'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
