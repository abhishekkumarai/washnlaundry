import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/models/garment_model.dart';
import 'package:washnlaundrycrm/screens/new_order_screen.dart' show matchesSelectedTags;

GarmentItemModel _item(int id, String category, String name, List<String> tags) =>
    GarmentItemModel.fromJson({
      'id': id,
      'category': 1,
      'category_name': category,
      'name': name,
      'price': 100.0,
      'is_active': true,
      'tags': tags,
    });

void main() {
  group('Item Tags & Tag-based Search Filtering', () {
    final items = [
      _item(101, 'Dry Clean', 'Silk Saree', ['express', 'delicate', 'premium']),
      _item(102, 'Dry Clean', 'Woolen Coat', ['premium']),
      _item(103, 'Wash & Fold', 'Cotton Bedsheet', ['bulk', 'economy']),
      _item(104, 'Steam Iron', 'Linen Shirt', ['express', 'daily']),
      _item(105, 'Steam Iron', 'Handkerchief', []),
    ];

    List<GarmentItemModel> filter({
      String selectedCategory = '',
      Set<String> selectedTags = const {},
      String searchQuery = '',
    }) {
      final q = searchQuery.toLowerCase().trim();
      return items.where((item) {
        final matchesCategory =
            selectedCategory.isEmpty || item.categoryName == selectedCategory;
        // The screen's own tag rule, not a copy of it.
        final matchesTags = matchesSelectedTags(item.tags, selectedTags);
        final matchesSearch = q.isEmpty ||
            item.name.toLowerCase().contains(q) ||
            item.categoryName.toLowerCase().contains(q) ||
            item.tags.any((t) => t.toLowerCase().contains(q));
        return matchesCategory && matchesTags && matchesSearch;
      }).toList();
    }

    test('search query matches an item by its own tag only', () {
      expect(filter(searchQuery: 'delicate').map((i) => i.name), ['Silk Saree']);
      expect(filter(searchQuery: 'bulk').map((i) => i.name), ['Cotton Bedsheet']);
      expect(filter(searchQuery: 'express').map((i) => i.name),
          ['Silk Saree', 'Linen Shirt']);
    });

    test('a tag on one item does not tag its siblings', () {
      // Woolen Coat shares a category with Silk Saree but not its tags.
      expect(filter(selectedTags: {'delicate'}).map((i) => i.name),
          ['Silk Saree']);
      expect(filter(selectedTags: {'express'}).map((i) => i.name),
          isNot(contains('Handkerchief')));
    });

    test('multi-select tag filtering is OR: items with ANY selected tag', () {
      expect(filter(selectedTags: {'premium'}).map((i) => i.name),
          ['Silk Saree', 'Woolen Coat']);
      expect(filter(selectedTags: {'premium', 'express'}).map((i) => i.name),
          ['Silk Saree', 'Woolen Coat', 'Linen Shirt']);
      expect(filter(selectedTags: {'economy', 'express'}).map((i) => i.name),
          ['Silk Saree', 'Cotton Bedsheet', 'Linen Shirt']);
      expect(filter(selectedTags: {'nonexistent'}), isEmpty);
      // Case-insensitive, and an untagged item never matches a selection.
      expect(filter(selectedTags: {'PREMIUM'}).length, 2);
      expect(filter(selectedTags: {'express', 'bulk', 'premium', 'daily'})
          .map((i) => i.name), isNot(contains('Handkerchief')));
    });

    test('category filter and tag filter combine correctly', () {
      expect(
          filter(selectedCategory: 'Steam Iron', selectedTags: {'express'})
              .map((i) => i.name),
          ['Linen Shirt']);
      expect(
          filter(selectedCategory: 'Wash & Fold', selectedTags: {'express'}),
          isEmpty);
    });

    test('all available tags are computed and sorted cleanly', () {
      final allTags = <String>{for (final i in items) ...i.tags}.toList()
        ..sort();
      expect(allTags,
          ['bulk', 'daily', 'delicate', 'economy', 'express', 'premium']);
    });
  });
}
