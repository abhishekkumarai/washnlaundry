import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/garment_model.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/load_state.dart';
import '../utils/navigation.dart';
import '../utils/money.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  int _selectedTopTab = 0; // Items is the only view now
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';

  // Presentation only — the catalogue itself comes from the API. Keyed by the
  // category's `icon` string (what the seed writes, and what the New Service
  // dialog lets you pick) so a user-created category renders with the icon it
  // chose instead of a neutral fallback.
  static const Map<String, Map<String, dynamic>> _categoryStyles = {
    'Iron': {
      'icon': Icons.dry_cleaning_rounded,
      'color': Color(0xFF182C4F),
      'bg': Color(0xFFEFF6FF)
    },
    'Laundry': {
      'icon': Icons.local_laundry_service_rounded,
      'color': Color(0xFF0284C7),
      'bg': Color(0xFFE0F2FE)
    },
    'WashIron': {
      'icon': Icons.iron_rounded,
      'color': Color(0xFFD97706),
      'bg': Color(0xFFFEF3C7)
    },
    'Sparkles': {
      'icon': Icons.auto_awesome_rounded,
      'color': Color(0xFF2563EB),
      'bg': Color(0xFFEFF6FF)
    },
    'Home': {
      'icon': Icons.home_work_rounded,
      'color': Color(0xFF2563EB),
      'bg': Color(0xFFEFF6FF)
    },
    'Shoe': {
      'icon': Icons.roller_skating_rounded,
      'color': Color(0xFF10B981),
      'bg': Color(0xFFECFDF5)
    },
    'Star': {
      'icon': Icons.workspace_premium_rounded,
      'color': Color(0xFFEC4899),
      'bg': Color(0xFFFCE7F3)
    },
  };

  static const Map<String, dynamic> _fallbackStyle = {
    'icon': Icons.label_outline_rounded,
    'color': Color(0xFF64748B),
    'bg': Color(0xFFF1EFEA),
  };

  /// Categories in display order, as view-models. Rebuilt from the provider on
  /// every build so counts and price ranges always match the backend.
  List<Map<String, dynamic>> _categories = const [];

  /// Items of the selected category, honouring the search box.
  List<Map<String, dynamic>> _currentItems = const [];

  void _syncFromProvider(AppProvider provider) {
    _categories = provider.categories.map((c) {
      final style = _categoryStyles[c.icon] ?? _fallbackStyle;
      return <String, dynamic>{
        'id': c.id,
        'title': c.name,
        'count': c.itemCount,
        'icon': style['icon'],
        'color': style['color'],
        'bg': style['bg'],
        'isActive': c.isActive,
      };
    }).toList();

    if (_categories.isEmpty) {
      _currentItems = const [];
      return;
    }
    if (_selectedCategoryIndex >= _categories.length)
      _selectedCategoryIndex = 0;

    final categoryName = _categories[_selectedCategoryIndex]['title'] as String;
    final query = _searchQuery.toLowerCase();

    _currentItems = provider.garments
        // Inactive items stay listed (shown as off) so they can be switched
        // back on here; only New Order limits itself to active ones.
        .where((g) => g.categoryName == categoryName)
        .where((g) => query.isEmpty || g.name.toLowerCase().contains(query))
        .map((g) => <String, dynamic>{
              'id': g.id,
              'name': g.name,
              'price': g.price,
              'unit': g.unitLabel,
              'unitShort': g.unitShortLabel,
              'active': g.isActive,
              // The item's own category — Edit reads this instead of
              // assuming the sidebar's currently-selected tab, which only
              // coincidentally matches today (this list is itself always
              // pre-filtered to the selected tab) but shouldn't be load-
              // bearing for what category Edit preselects.
              'categoryName': g.categoryName,
              // Comes off the catalogue record now. Matching Unsplash URLs to
              // item *names* in the client meant a rename lost the photo.
              'img': g.imageUrl,
            })
        .toList();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncFromProvider(context.watch<AppProvider>());
    final isMobile = MediaQuery.sizeOf(context).width <
        SidebarNavigation.contentWideBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      floatingActionButton:
          (isMobile && _selectedTopTab == 0 && _categories.isNotEmpty)
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddItemModal(context),
                  backgroundColor: const Color(0xFF182C4F),
                  elevation: 4,
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  label: const Text(
                    'Add Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                )
              : null,
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final provider = context.watch<AppProvider>();
            if (provider.hasError && provider.categories.isEmpty) {
              return ErrorState(
                statusCode: provider.error != null &&
                        provider.error!.contains('not found')
                    ? 404
                    : 500,
                title: 'Error loading services',
                message: provider.error!,
                onRetry: () => provider.refresh(),
                onHome: () => context.goSection(0),
              );
            }
            if (provider.isLoading && provider.categories.isEmpty) {
              return const LoadingState();
            }

            final narrow =
                constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return Column(
              children: [
                narrow ? _buildNarrowHeader() : _buildHeader(),
                Expanded(child: _buildBody(narrow)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Row(
        children: [
          const Text('Services',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
          const SizedBox(width: 8),
          Text(
            '${_categories.length} Items · ${_categories.fold<int>(0, (sum, c) => sum + (c['count'] as int))} items',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const Spacer(),
          if (_selectedTopTab == 0) ...[
            OutlinedButton.icon(
              onPressed: _showDefaultServicesPreviewModal,
              icon: const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: Color(0xFF0F766E)),
              label: const Text('Default Services',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0F766E)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 180,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7F5),
                border: Border.all(color: const Color(0xFFE4E0D8)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search items...',
                        hintStyle:
                            TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Below [SidebarNavigation.contentWideBreakpoint]: title+count on one row,
  /// full-width search below (Items tab only) — same shape as Orders'/Staff's
  /// narrow headers.
  Widget _buildNarrowHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Services',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF141A24))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_categories.length} Items · ${_categories.fold<int>(0, (sum, c) => sum + (c['count'] as int))} items',
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          if (_selectedTopTab == 0) ...[
            const SizedBox(height: 10),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7F5),
                border: Border.all(color: const Color(0xFFE4E0D8)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search items...',
                        hintStyle:
                            TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(bool narrow) => _buildItemsView(narrow);

  // ─── TAB 1: Items ───────────────────────────────────────────────────
  Widget _buildItemsView(bool narrow) {
    // A fresh database has no categories at all, and every card below indexes
    // _categories[_selectedCategoryIndex] — so this has to come first.
    if (_categories.isEmpty) return _buildNoCategoriesView();

    final cat = _categories[_selectedCategoryIndex];
    final items = _currentItems;

    final categoryRail = Container(
      width: 264,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 16, bottom: 10),
            child: Text('SERVICE CATEGORIES',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final c = _categories[i];
                final sel = _selectedCategoryIndex == i;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _selectedCategoryIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFEFF6FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFF182C4F)
                              : const Color(0xFFE4E0D8)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: c['bg'] as Color,
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(c['icon'] as IconData,
                              size: 18, color: c['color'] as Color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['title'] as String,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? const Color(0xFF182C4F)
                                          : const Color(0xFF141A24))),
                              Text('${c['count']} items',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: (c['isActive'] as bool? ?? true)
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E0D8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showAddCategoryModal(context),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 15, color: Color(0xFF182C4F)),
                  SizedBox(width: 6),
                  // The rail is a fixed 264px, so the label has to be
                  // allowed to shrink rather than overflow it.
                  Expanded(
                    child: Text(
                      'New service category',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF182C4F)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Narrow mode: the 264px vertical rail alone would eat almost the whole
    // phone width, leaving no room for the grid — same bug class as Orders'
    // original table. Collapses to a horizontal-scroll chip row instead,
    // matching New Order's category `ChoiceChip` row.
    final categoryChips = SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _categories[i];
          final sel = _selectedCategoryIndex == i;
          return ChoiceChip(
            label: Text(c['title'] as String),
            selected: sel,
            onSelected: (_) => setState(() => _selectedCategoryIndex = i),
            avatar: Icon(c['icon'] as IconData,
                size: 16, color: sel ? Colors.white : c['color'] as Color),
            selectedColor: const Color(0xFF182C4F),
            labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : const Color(0xFF141A24)),
          );
        },
      ),
    );

    final itemsGrid = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        narrow ? 16 : 24,
        narrow ? 16 : 24,
        narrow ? 16 : 24,
        narrow
            ? 84
            : 24, // Extra bottom padding for mobile floating action button
      ),
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
              Flexible(
                child: Text(
                    items.every((i) => i['active'] as bool)
                        ? 'Items (${items.length})'
                        : 'Items (${items.length}) · '
                            '${items.where((i) => !(i['active'] as bool)).length} inactive',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF141A24))),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showAddItemModal(context),
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 15, color: Color(0xFF182C4F)),
                    SizedBox(width: 4),
                    Text('Add Item',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF182C4F))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items list. Wide screens get the live app's own layout — a
          // compact table (Photo/Service/Unit/Price/Active/Actions) — since
          // that's what LIVE_AUDIT.md's /inventory capture shows. Phone/
          // tablet widths keep the card grid: a 6-column table has no room
          // to breathe below ~900px, same reasoning as every other screen's
          // table-to-card fallback at contentWideBreakpoint.
          narrow ? _buildItemsCardGrid(items, narrow) : _buildItemsTable(items),
        ],
      ),
    );

    if (narrow) {
      return Column(
        children: [
          const SizedBox(height: 12),
          categoryChips,
          const SizedBox(height: 4),
          Expanded(child: itemsGrid),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        categoryRail,
        Expanded(child: itemsGrid),
      ],
    );
  }

  /// Card-grid form of the items list — phone/tablet widths, where a table's
  /// fixed columns have no room.
  /// On mobile (< 620px), images are hidden to keep cards compact and save space.
  Widget _buildItemsCardGrid(List<Map<String, dynamic>> items, bool narrow) {
    return LayoutBuilder(
      builder: (context, gridConstraints) {
        final isMobilePhone = gridConstraints.maxWidth < 620;
        final crossAxisCount = gridConstraints.maxWidth < 380
            ? 1
            : gridConstraints.maxWidth < 620
                ? 2
                : gridConstraints.maxWidth < 900
                    ? 3
                    : 4;

        // When mobile (images hidden), we use a wider/flatter aspect ratio to reduce card height
        final double aspectRatio = isMobilePhone
            ? (gridConstraints.maxWidth < 380 ? 2.4 : 1.35)
            : 0.78;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isMobilePhone ? 10 : 16,
            mainAxisSpacing: isMobilePhone ? 10 : 16,
            childAspectRatio: aspectRatio,
          ),
          itemCount: isMobilePhone ? items.length : items.length + 1,
          itemBuilder: (ctx, i) {
            if (i == items.length) return _buildAddNewItemCard();
            return _buildItemCard(items[i], hideImage: isMobilePhone);
          },
        );
      },
    );
  }

  Widget _colHead(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
          color: Color(0xFF64748B),
        ),
      );

  /// Table form of the items list — Photo / Service / Unit / Price / Active /
  /// Actions, matching the live app's own /inventory Items tab (LIVE_AUDIT.md).
  Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: _colHead('SERVICE')),
                Expanded(flex: 2, child: _colHead('UNIT')),
                Expanded(flex: 2, child: _colHead('PRICE')),
                SizedBox(width: 60, child: _colHead('ACTIVE')),
                const SizedBox(width: 76),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No items in this category yet.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ),
            )
          else
            for (final item in items) _buildItemRow(item),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final active = item['active'] as bool;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: (item['img'] as String).isEmpty
                  ? _itemImagePlaceholder()
                  : Image.network(
                      item['img'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _itemImagePlaceholder(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(item['name'] as String,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? const Color(0xFF141A24)
                              : const Color(0xFF94A3B8))),
                ),
                if (!active) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1EFEA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Off',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B))),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(item['unit'] as String,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(
                    '${Money.symbol}${(item['price'] as double).toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF141A24))),
                Text(' / ${item['unitShort']}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Switch(
              value: active,
              onChanged: (v) => context
                  .read<AppProvider>()
                  .updateGarmentItem(item['id'] as String, {'is_active': v}),
            ),
          ),
          SizedBox(
            width: 76,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'Edit item',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _showEditItemModal(context, item),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.edit_outlined,
                          size: 16, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Delete item',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _showDeleteItemConfirm(context, item),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.delete_outline_rounded,
                          size: 16, color: Color(0xFFDC2626)),
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

  /// Shown when the shop has no categories yet — the one state in which the
  /// items grid can't render anything. Copy matches the live app's empty state.
  Widget _buildNoCategoriesView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.category_outlined,
              size: 48, color: Color(0xFFD9D5CB)),
          const SizedBox(height: 14),
          const Text('No services',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF141A24))),
          const SizedBox(height: 6),
          const Text('Create services to organize your items.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryModal(context),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('New service category',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF182C4F),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showDefaultServicesPreviewModal,
                icon: const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: Color(0xFF0F766E)),
                label: const Text('Load Standard Laundromat Services',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(Map<String, dynamic> cat) {
    final iconAndTitle = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: cat['bg'] as Color,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(cat['icon'] as IconData,
              size: 22, color: cat['color'] as Color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(cat['title'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF141A24))),
                  ),
                  const SizedBox(width: 10),
                  Builder(builder: (_) {
                    final active = cat['isActive'] as bool? ?? true;
                    final color = active
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF1EFEA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: color),
                          const SizedBox(width: 4),
                          Text(active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              Text('${cat['count']} items in ${cat['title']}',
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );

    final actions = PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          size: 18, color: Color(0xFF64748B)),
      tooltip: 'More actions',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (action) {
        if (action == 'edit') {
          _showEditCategoryModal(context, cat);
        } else if (action == 'delete') {
          _showDeleteCategoryConfirm(context, cat);
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text('Edit category', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Delete category',
                  style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Below this the edit/menu cluster crowds the title column to
          // near-zero — stack them on their own row instead.
          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconAndTitle,
                const SizedBox(height: 14),
                actions,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: iconAndTitle),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _itemImagePlaceholder() => Container(
        color: const Color(0xFFF1EFEA),
        child: const Center(
          child:
              Icon(Icons.checkroom_rounded, color: Color(0xFFD9D5CB), size: 32),
        ),
      );

  Widget _buildItemCard(Map<String, dynamic> item, {bool hideImage = false}) {
    final active = item['active'] as bool;
    final fg = active ? const Color(0xFF10B981) : const Color(0xFF94A3B8);

    if (hideImage) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E0D8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF141A24),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 16, color: Color(0xFF64748B)),
                  tooltip: 'Options',
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditItemModal(context, item);
                    } else if (action == 'delete') {
                      _showDeleteItemConfirm(context, item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 15, color: Color(0xFF64748B)),
                          SizedBox(width: 8),
                          Text('Edit item', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 15, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text('Delete item',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFEA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['unit'] as String,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1EFEA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 5, color: fg),
                      const SizedBox(width: 3),
                      Text(
                        active ? 'Active' : 'Off',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '${Money.symbol}${(item['price'] as double).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141A24),
                  ),
                ),
                Text(
                  ' / ${item['unitShort']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with Active badge + edit button
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
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
                            errorBuilder: (_, __, ___) =>
                                _itemImagePlaceholder(),
                          ),
                  ),
                ),
                // Active / Inactive badge top-right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Builder(builder: (_) {
                    final fg = active
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF1EFEA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 5, color: fg),
                          const SizedBox(width: 3),
                          Text(active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: fg)),
                        ],
                      ),
                    );
                  }),
                ),
                // 3-dots options button bottom-right
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert_rounded,
                          size: 15, color: Color(0xFF64748B)),
                      tooltip: 'Item options',
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      onSelected: (action) {
                        if (action == 'edit') {
                          _showEditItemModal(context, item);
                        } else if (action == 'delete') {
                          _showDeleteItemConfirm(context, item);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined,
                                  size: 15, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Text('Edit item', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 15, color: Color(0xFFDC2626)),
                              SizedBox(width: 8),
                              Text('Delete item',
                                  style: TextStyle(
                                      fontSize: 13, color: Color(0xFFDC2626))),
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
          // Details below
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] as String,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF141A24))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF1EFEA),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(item['unit'] as String,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF64748B))),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                        '${Money.symbol}${(item['price'] as double).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF141A24))),
                    Text(' / ${item['unitShort']}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showAddItemModal(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFE4E0D8), style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 28, color: Color(0xFF94A3B8)),
            SizedBox(height: 8),
            Text('Add new item',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFF10B981)),
    );
  }

  void _showAddItemModal(BuildContext context) {
    if (_categories.isEmpty) {
      _showError('Please select a service category first');
      return;
    }

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String selectedCat = _categories[_selectedCategoryIndex]['title'] as String;
    String selectedUnit = PricingUnit.piece;

    String? nameError;
    String? priceError;
    String? submitError;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> save() async {
            final name = nameCtrl.text.trim();
            final price = double.tryParse(priceCtrl.text.trim());
            final match = _categories.firstWhere(
              (c) => c['title'] == selectedCat,
              orElse: () => const <String, dynamic>{},
            );
            final categoryId = int.tryParse('${match['id']}');

            setModalState(() {
              nameError = name.isEmpty ? 'Item name is required' : null;
              priceError =
                  (price == null || price <= 0) ? 'Enter a valid price' : null;
              submitError = categoryId == null
                  ? 'Please select a service category first'
                  : null;
            });
            if (nameError != null || priceError != null || submitError != null)
              return;

            setModalState(() => saving = true);
            final provider = context.read<AppProvider>();
            final ok = await provider.addGarmentItem({
              'category': categoryId,
              'name': name,
              'price': price,
              'unit': selectedUnit,
            });
            if (!ctx.mounted) return;

            if (!ok) {
              // Keep the dialog open — the old code popped it silently, which
              // read as success.
              setModalState(() {
                saving = false;
                submitError = provider.error ?? 'Could not save the item';
              });
              return;
            }
            Navigator.pop(ctx);
            _showSuccess('Added "$name" to $selectedCat');
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Add New Service / Garment Item',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A24))),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: math.min(440.0, MediaQuery.sizeOf(ctx).width - 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _modalLabel('Service Category *'),
                  _modalDropdown<String>(
                    value: selectedCat,
                    items: _categories
                        .map((c) => DropdownMenuItem(
                            value: c['title'] as String,
                            child: Text(c['title'] as String)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedCat = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  _modalLabel('Item Name *'),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Jacket / Blazer',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      errorText: nameError,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (_) {
                      if (nameError != null)
                        setModalState(() => nameError = null);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _modalLabel('Price (${Money.symbol}) *'),
                            TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'e.g. 150',
                                hintStyle: const TextStyle(
                                    fontSize: 13, color: Color(0xFF94A3B8)),
                                errorText: priceError,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (_) {
                                if (priceError != null)
                                  setModalState(() => priceError = null);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _modalLabel('Unit'),
                            _modalDropdown<String>(
                              value: selectedUnit,
                              items: PricingUnit.all
                                  .map((u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(PricingUnit.label(u))))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null)
                                  setModalState(() => selectedUnit = v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 14),
                    _modalErrorBanner(submitError!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF182C4F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Item',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// "New Service" — the category dialog reached from the sidebar. Limited to
  /// what GarmentCategory stores: name, icon and the active flag.
  void _showAddCategoryModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    bool isActive = true;
    String? nameError;
    String? submitError;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> save() async {
            final name = nameCtrl.text.trim();
            setModalState(() => nameError =
                name.isEmpty ? 'Please enter a service name.' : null);
            if (nameError != null) return;

            setModalState(() => saving = true);
            final provider = context.read<AppProvider>();
            final id = await provider.addCategory({
              'name': name,
              'display_order': _categories.length + 1,
              'is_active': isActive,
            });
            if (!ctx.mounted) return;

            if (id == null) {
              setModalState(() {
                saving = false;
                submitError = provider.error ?? 'Failed to save service.';
              });
              return;
            }
            Navigator.pop(ctx);
            // Jump to the category that was just created.
            final index = provider.categories.indexWhere((c) => c.id == id);
            if (index >= 0 && mounted)
              setState(() => _selectedCategoryIndex = index);
            _showSuccess('Added "$name"');
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('New Service',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A24))),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: math.min(400.0, MediaQuery.sizeOf(ctx).width - 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _modalLabel('Service Name *'),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g., Dry Clean',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      errorText: nameError,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (_) {
                      if (nameError != null)
                        setModalState(() => nameError = null);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Active',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF141A24))),
                    subtitle: const Text('Show in items list',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    value: isActive,
                    onChanged: (v) => setModalState(() => isActive = v),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 10),
                    _modalErrorBanner(submitError!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF182C4F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Add Service',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditCategoryModal(BuildContext context, Map<String, dynamic> cat) {
    final nameCtrl = TextEditingController(text: cat['title'] as String);
    // Was hardcoded `true` regardless of the category's real state — saving
    // any edit to an already-inactive category (even just its name) would
    // silently reactivate it, since the switch always started on.
    bool isActive = cat['isActive'] as bool? ?? true;
    String? nameError;
    String? submitError;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> save() async {
            final name = nameCtrl.text.trim();
            setModalState(() => nameError =
                name.isEmpty ? 'Please enter a service name.' : null);
            if (nameError != null) return;

            setModalState(() => saving = true);
            final provider = context.read<AppProvider>();
            final ok = await provider.updateCategory('${cat['id']}', {
              'name': name,
              'is_active': isActive,
            });
            if (!ctx.mounted) return;

            if (!ok) {
              setModalState(() {
                saving = false;
                submitError =
                    provider.error ?? 'Failed to update service category.';
              });
              return;
            }
            Navigator.pop(ctx);
            _showSuccess('Updated "$name"');
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Edit Service',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A24))),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: math.min(400.0, MediaQuery.sizeOf(ctx).width - 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _modalLabel('Service Name *'),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g., Dry Clean',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      errorText: nameError,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (_) {
                      if (nameError != null)
                        setModalState(() => nameError = null);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Active',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF141A24))),
                    subtitle: const Text('Show in items list',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    value: isActive,
                    onChanged: (v) => setModalState(() => isActive = v),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 10),
                    _modalErrorBanner(submitError!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF182C4F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteCategoryConfirm(
      BuildContext context, Map<String, dynamic> cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24))),
        content: Text(
            'Are you sure you want to delete "${cat['title']}"? All associated items will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<AppProvider>();
              final ok = await provider.deleteCategory('${cat['id']}');
              if (ok) {
                setState(() => _selectedCategoryIndex = 0);
                _showSuccess('Deleted category "${cat['title']}"');
              } else {
                _showError(provider.error ?? 'Could not delete category');
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteItemConfirm(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24))),
        content: Text(
            'Are you sure you want to delete "${item['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<AppProvider>();
              final ok = await provider.deleteGarmentItem('${item['id']}');
              if (ok) {
                _showSuccess('Deleted item "${item['name']}"');
              } else {
                _showError(provider.error ?? 'Could not delete item');
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditItemModal(BuildContext context, Map<String, dynamic> item) {
    final nameCtrl = TextEditingController(text: item['name'] as String? ?? '');
    final priceCtrl = TextEditingController(
        text: ((item['price'] as num?) ?? 0).toStringAsFixed(0));
    final imgCtrl = TextEditingController(text: item['img'] as String? ?? '');
    // The item's own category, not whatever tab the sidebar happens to be
    // on — the two only ever coincided by construction (see the comment
    // where 'categoryName' is set), which made this fragile rather than
    // actually correct.
    String selectedCat = item['categoryName'] as String? ??
        _categories[_selectedCategoryIndex]['title'] as String;
    String selectedUnit = PricingUnit.all.firstWhere(
      (u) => PricingUnit.label(u) == item['unit'],
      orElse: () => PricingUnit.piece,
    );
    bool isActive = (item['active'] as bool?) ?? true;

    String? nameError;
    String? priceError;
    String? submitError;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> save() async {
            final name = nameCtrl.text.trim();
            final price = double.tryParse(priceCtrl.text.trim());
            final match = _categories.firstWhere(
              (c) => c['title'] == selectedCat,
              orElse: () => const <String, dynamic>{},
            );
            final categoryId = int.tryParse('${match['id']}');

            setModalState(() {
              nameError = name.isEmpty ? 'Item name is required' : null;
              priceError =
                  (price == null || price <= 0) ? 'Enter a valid price' : null;
              submitError = categoryId == null
                  ? 'Please select a service category'
                  : null;
            });
            if (nameError != null || priceError != null || submitError != null)
              return;

            setModalState(() => saving = true);
            final provider = context.read<AppProvider>();
            final ok = await provider.updateGarmentItem('${item['id']}', {
              'category': categoryId,
              'name': name,
              'price': price,
              'unit': selectedUnit,
              'is_active': isActive,
              'image_url': imgCtrl.text.trim(),
            });
            if (!ctx.mounted) return;

            if (!ok) {
              setModalState(() {
                saving = false;
                submitError = provider.error ?? 'Could not update the item';
              });
              return;
            }
            Navigator.pop(ctx);
            _showSuccess('Updated "$name"');
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Edit Service / Item',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A24))),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: math.min(440.0, MediaQuery.sizeOf(ctx).width - 48),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _modalLabel('Service Category *'),
                    _modalDropdown<String>(
                      value: selectedCat,
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c['title'] as String,
                              child: Text(c['title'] as String)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedCat = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    _modalLabel('Item Name *'),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Jacket / Blazer',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                        errorText: nameError,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) {
                        if (nameError != null)
                          setModalState(() => nameError = null);
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _modalLabel('Price (${Money.symbol}) *'),
                              TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 150',
                                  hintStyle: const TextStyle(
                                      fontSize: 13, color: Color(0xFF94A3B8)),
                                  errorText: priceError,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) {
                                  if (priceError != null)
                                    setModalState(() => priceError = null);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _modalLabel('Unit'),
                              _modalDropdown<String>(
                                value: selectedUnit,
                                items: PricingUnit.all
                                    .map((u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(PricingUnit.label(u))))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null)
                                    setModalState(() => selectedUnit = v);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _modalLabel('Status'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(isActive ? 'Active' : 'Inactive',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      value: isActive,
                      onChanged: (v) => setModalState(() => isActive = v),
                    ),
                    const SizedBox(height: 14),
                    _modalLabel('Image URL (optional)'),
                    TextField(
                      controller: imgCtrl,
                      decoration: InputDecoration(
                        hintText: 'https://images.unsplash.com/...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (submitError != null) ...[
                      const SizedBox(height: 14),
                      _modalErrorBanner(submitError!),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              // A single Row so `Spacer` has the bounded Flex ancestor it
              // needs — `AlertDialog.actions` lays its children out in an
              // `OverflowBar`, which doesn't support flex children directly.
              // A bare `Spacer` here threw at layout time and took the whole
              // dialog content down with it (release builds show a blank
              // grey box instead of the usual red error screen).
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final provider = context.read<AppProvider>();
                              final ok = await provider
                                  .deleteGarmentItem('${item['id']}');
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (ok) {
                                _showSuccess('Deleted "${item['name']}"');
                              } else {
                                _showError(
                                    provider.error ?? 'Could not delete item');
                              }
                            },
                      child: const Text('Delete',
                          style: TextStyle(color: Color(0xFFDC2626))),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: saving ? null : save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF182C4F),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Shared modal chrome ────────────────────────────────────────────

  Widget _modalLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569))),
      );

  Widget _modalDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E0D8)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Color(0xFF64748B)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _modalErrorBanner(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFECACA)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 16, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            ),
          ],
        ),
      );

  // ─── Default Laundromat Services Preview & Loading Modal ───────────

  void _showDefaultServicesPreviewModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: ApiService.fetchDefaultServices(),
            builder: (ctx, snapshot) {
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              final catalogue = snapshot.data ?? [];
              final hasError = snapshot.hasError;

              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          size: 20, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Standard Laundromat Services',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF141A24))),
                          Text(
                              'Built-in laundromat price card & garment catalogue',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 580,
                  height: 440,
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF182C4F)),
                        )
                      : hasError
                          ? Center(
                              child: Text(
                                  'Failed to load standard services: ${snapshot.error}',
                                  style: const TextStyle(
                                      color: Color(0xFFDC2626))),
                            )
                          : ListView.separated(
                              itemCount: catalogue.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final cat = catalogue[i];
                                final items = (cat['items'] as List?) ?? [];
                                final iconKey =
                                    cat['icon'] as String? ?? 'Shirt';
                                final style =
                                    _categoryStyles[iconKey] ?? _fallbackStyle;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F7F5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFE4E0D8)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: style['bg'] as Color,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                                style['icon'] as IconData,
                                                size: 16,
                                                color: style['color'] as Color),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              cat['name'] as String? ?? '',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Color(0xFF141A24)),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFE4E0D8)),
                                            ),
                                            child: Text(
                                              '${items.length} items',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF64748B)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: items.take(8).map((it) {
                                          final name = it['name'] ?? '';
                                          final price = it['price'] ?? 0;
                                          final unit = it['unit_label'] ??
                                              it['unit'] ??
                                              '';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFE2E8F0)),
                                            ),
                                            child: Text(
                                              '$name (${Money.format(price)} $unit)',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF334155)),
                                            ),
                                          );
                                        }).toList()
                                          ..addAll(items.length > 8
                                              ? [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      '+${items.length - 8} more',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(
                                                              0xFF94A3B8)),
                                                    ),
                                                  )
                                                ]
                                              : []),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download_rounded,
                        size: 16, color: Colors.white),
                    label: const Text('Import Defaults to Shop',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final provider = context.read<AppProvider>();
                      final ok = await provider.loadDefaultServices();
                      if (ok) {
                        _showSuccess(
                            'Standard laundromat services loaded successfully!');
                      } else {
                        _showError(provider.error ??
                            'Failed to load default services');
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
