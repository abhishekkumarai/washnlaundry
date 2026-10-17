"""Every catalogue item gets starter tags (api/item_tags.py), in both catalogues."""
from io import StringIO

from django.core.management import call_command
from django.test import TestCase

from api import default_services
from api.item_tags import FALLBACK_TAG, category_tags, item_tags
from api.models import GarmentCategory, GarmentItem, Shop


class ItemTagRulesTests(TestCase):
    def test_whole_words_only(self):
        # "suit" must not match "suitcase", nor "pant" inside another word.
        self.assertEqual(item_tags('Premium Care', 'Travel Bag / Suitcase', 'PC'), ['premium', 'bags'])
        self.assertIn('male', item_tags('Dry Cleaning', 'Suit (2 piece)', 'PC'))
        self.assertIn('male', item_tags('Steam Ironing', 'T-Shirt', 'PC'))

    def test_items_the_old_rules_missed_now_have_tags(self):
        self.assertEqual(item_tags('Ironing', 'Bedsheet (Double)', 'PC'), ['home'])
        self.assertEqual(item_tags('Dry Cleaning', 'Winter Jacket', 'PC'), ['winter'])
        self.assertEqual(item_tags('Dry Cleaning', 'Comforter', 'PC'), ['home', 'winter'])
        self.assertEqual(item_tags('Wash & Fold', 'Regular Clothes (Per Kg)', 'KG'), ['bulk'])
        self.assertEqual(item_tags('Shoe Care & Spa', 'Boots', 'PC'), ['shoes'])

    def test_never_empty(self):
        self.assertEqual(item_tags('Misc', 'Something else', 'PC'), [FALLBACK_TAG])

    def test_category_tags(self):
        self.assertEqual(category_tags('Household & Furnishing'), ['home'])
        self.assertEqual(category_tags('Shoe Cleaning'), ['shoes'])
        self.assertEqual(category_tags('Dry Cleaning'), [])

    def test_every_item_in_both_catalogues_gets_a_real_tag(self):
        import seed_db
        seeded = [(c, n, u) for c, _icon, items in seed_db.CATALOGUE for n, _p, u in items]
        default = [(c, i[0], i[2]) for c, _icon, items in default_services.DEFAULT_SERVICE_CATALOGUE
                   for i in items]
        for cat, name, unit in seeded + default:
            tags = item_tags(cat, name, unit)
            self.assertTrue(tags and tags != [FALLBACK_TAG], f'{cat} / {name} has no tag')


class DefaultCatalogueTagTests(TestCase):
    def test_a_new_shop_catalogue_is_tagged(self):
        shop = Shop.objects.create(name='Fresh', slug='fresh')
        GarmentItem.all_objects.filter(shop=shop).delete()
        GarmentCategory.all_objects.filter(shop=shop).delete()
        default_services.populate_default_services_for_shop(shop)
        items = GarmentItem.all_objects.filter(shop=shop)
        self.assertTrue(items.exists())
        self.assertFalse(items.filter(tags=[]).exists())
        self.assertEqual(GarmentCategory.all_objects.get(shop=shop, name='Shoe Care & Spa').tags, ['shoes'])

    def test_fill_item_tags_only_fills_empty_tags(self):
        shop = Shop.objects.create(name='Old', slug='old')
        cat = GarmentCategory.all_objects.create(shop=shop, name='Dry Cleaning')
        empty = GarmentItem.all_objects.create(shop=shop, category=cat, name='Winter Jacket', price=1)
        custom = GarmentItem.all_objects.create(shop=shop, category=cat, name='Sherwani', price=1,
                                                tags=['wedding'])
        call_command('fill_item_tags', '--shop', 'old', stdout=StringIO())
        empty.refresh_from_db()
        custom.refresh_from_db()
        self.assertEqual(empty.tags, ['winter'])
        self.assertEqual(custom.tags, ['wedding'])  # an owner's tags are left alone
