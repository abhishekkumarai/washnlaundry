import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';

void main() {
  group('Category Tags & Tag-based Search Filtering', () {
    final catDryClean = GarmentCategoryModel.fromJson({
      'id': 1,
      'name': 'Dry Clean',
      'tags': ['express', 'delicate', 'premium'],
    });

    final catWash = GarmentCategoryModel.fromJson({
      'id': 2,
      'name': 'Wash & Fold',
      'tags': ['daily', 'bulk', 'economy'],
    });

    final catIron = GarmentCategoryModel.fromJson({
      'id': 3,
      'name': 'Steam Iron',
      'tags': ['express', 'daily'],
    });

    final items = [
      GarmentItemModel.fromJson({
        'id': 101,
        'category': 1,
        'category_name': 'Dry Clean',
        'name': 'Silk Saree',
        'price': 250.0,
        'is_active': true,
      }),
      GarmentItemModel.fromJson({
        'id': 102,
        'category': 1,
        'category_name': 'Dry Clean',
        'name': 'Woolen Coat',
        'price': 350.0,
        'is_active': true,
      }),
      GarmentItemModel.fromJson({
        'id': 103,
        'category': 2,
        'category_name': 'Wash & Fold',
        'name': 'Cotton Bedsheet',
        'price': 80.0,
        'is_active': true,
      }),
      GarmentItemModel.fromJson({
        'id': 104,
        'category': 3,
        'category_name': 'Steam Iron',
        'name': 'Linen Shirt',
        'price': 25.0,
        'is_active': true,
      }),
    ];

    final categoryTagsByName = <String, List<String>>{
      catDryClean.name: catDryClean.tags,
      catWash.name: catWash.tags,
      catIron.name: catIron.tags,
    };

    List<GarmentItemModel> filter({
      String selectedCategory = '',
      Set<String> selectedTags = const {},
      String searchQuery = '',
    }) {
      final q = searchQuery.toLowerCase().trim();
      return items.where((item) {
        final matchesCategory = selectedCategory.isEmpty ||
            item.categoryName == selectedCategory;
        final tags = categoryTagsByName[item.categoryName] ?? const [];
        final matchesTags = selectedTags.isEmpty ||
            selectedTags.any((selTag) =>
                tags.any((t) => t.toLowerCase() == selTag.toLowerCase()));
        final matchesSearch = q.isEmpty ||
            item.name.toLowerCase().contains(q) ||
            item.categoryName.toLowerCase().contains(q) ||
            tags.any((t) => t.toLowerCase().contains(q));
        return matchesCategory && matchesTags && matchesSearch;
      }).toList();
    }

    test('search query matches items by category tag', () {
      // Searching 'delicate' matches Dry Clean items
      final delicateItems = filter(searchQuery: 'delicate');
      expect(delicateItems.map((i) => i.name), ['Silk Saree', 'Woolen Coat']);

      // Searching 'bulk' matches Wash & Fold items
      final bulkItems = filter(searchQuery: 'bulk');
      expect(bulkItems.map((i) => i.name), ['Cotton Bedsheet']);

      // Searching 'express' matches Dry Clean AND Steam Iron items
      final expressItems = filter(searchQuery: 'express');
      expect(expressItems.map((i) => i.name),
          ['Silk Saree', 'Woolen Coat', 'Linen Shirt']);
    });

    test('multi-select tag filtering returns items matching any selected tag', () {
      // Single selected tag
      final premiumOnly = filter(selectedTags: {'premium'});
      expect(premiumOnly.map((i) => i.name), ['Silk Saree', 'Woolen Coat']);

      // Multi-select tags: economy OR express
      final economyOrExpress = filter(selectedTags: {'economy', 'express'});
      expect(economyOrExpress.map((i) => i.name), [
        'Silk Saree',
        'Woolen Coat',
        'Cotton Bedsheet',
        'Linen Shirt',
      ]);
    });

    test('category filter and tag filter combine correctly', () {
      // Selected category 'Steam Iron' + tag 'express'
      final ironExpress =
          filter(selectedCategory: 'Steam Iron', selectedTags: {'express'});
      expect(ironExpress.map((i) => i.name), ['Linen Shirt']);

      // Selected category 'Wash & Fold' + tag 'express' -> No match because Wash & Fold has no 'express' tag
      final washExpress =
          filter(selectedCategory: 'Wash & Fold', selectedTags: {'express'});
      expect(washExpress, isEmpty);
    });

    test('all available tags are computed and sorted cleanly', () {
      final allTags = <String>{
        ...catDryClean.tags,
        ...catWash.tags,
        ...catIron.tags,
      }.toList()
        ..sort();

      expect(allTags, ['bulk', 'daily', 'delicate', 'economy', 'express', 'premium']);
    });
  });
}
