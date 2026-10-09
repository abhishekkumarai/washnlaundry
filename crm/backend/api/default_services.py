"""Default services and garment catalogue for laundromats.

Provides canonical laundry and dry cleaning categories and items with
standard industry pricing and units. Used when seeding shops and can be
populated on demand or rendered directly in the CRM when a tenant is brand new.
"""

from .models import PricingUnit

PC = PricingUnit.PIECE
KG = PricingUnit.KG
SQFT = PricingUnit.SQFT
SET = PricingUnit.SET

_UNSPLASH = 'https://images.unsplash.com/photo-{}?w=300&h=300&fit=crop'
ITEM_IMAGES = {
    'Shirt': _UNSPLASH.format('1602810316493-c1e5e6a89dce'),
    'T-Shirt': _UNSPLASH.format('1527719327859-c6ce80353573'),
    'Kurta': _UNSPLASH.format('1594938291221-94f18cbb5660'),
    'Suit (2 piece)': _UNSPLASH.format('1507679799987-c73779587ccf'),
    'Pant': _UNSPLASH.format('1624378439575-d8705ad7ae80'),
    'Jeans': _UNSPLASH.format('1542272604-787c3835535d'),
    'Shorts': _UNSPLASH.format('1591195853828-11db59a44f43'),
    'Top / Kurti': _UNSPLASH.format('1610030469983-98e550d6193c'),
    'Saree (Silk)': _UNSPLASH.format('1610030469983-98e550d6193c'),
    'Sherwani': _UNSPLASH.format('1599643478518-a784e5dc4c8f'),
    'Lehenga (Bridal)': _UNSPLASH.format('1515372039744-b8f02a3ae446'),
    'Blazer/Jacket': _UNSPLASH.format('1507679799987-c73779587ccf'),
}

DEFAULT_SERVICE_CATALOGUE = [
    ('Wash & Fold', 'Laundry', [
        ('Regular Clothes (Per Kg)', 85.0, KG, 'Shirt'),
        ('Wash & Fold (Bedsheet / Towel)', 95.0, KG, 'Shirt'),
        ('Household Linen Wash', 125.0, PC, 'Shirt'),
        ('Heavy Bedspread / Quilt', 185.0, PC, 'Shirt'),
    ]),
    ('Wash & Iron', 'WashIron', [
        ('Shirt (Cotton)', 40.0, PC, 'Shirt'),
        ('Shirt (Silk/Linen)', 60.0, PC, 'Shirt'),
        ('T-Shirt / Polo', 35.0, PC, 'T-Shirt'),
        ('Trouser / Jeans', 50.0, PC, 'Jeans'),
        ('Kurta', 55.0, PC, 'Kurta'),
        ('Top / Kurti', 40.0, PC, 'Top / Kurti'),
        ('Salwar / Leggings', 40.0, PC, 'Pant'),
        ('Salwar Kameez Set', 80.0, PC, 'Kurta'),
        ('Saree (Cotton)', 80.0, PC, 'Shirt'),
        ('Saree (Silk)', 140.0, PC, 'Saree (Silk)'),
        ('Bedsheet (Single)', 70.0, PC, 'Shirt'),
        ('Bedsheet (Double)', 95.0, PC, 'Shirt'),
        ('Pillow Cover', 28.0, PC, 'Shirt'),
        ('Frock / Dress', 42.0, PC, 'Shirt'),
        ('School Uniform', 25.0, PC, 'Shirt'),
    ]),
    ('Steam Ironing', 'Iron', [
        ('Shirt', 15.0, PC, 'Shirt'),
        ('T-Shirt', 12.0, PC, 'T-Shirt'),
        ('Kurta', 20.0, PC, 'Kurta'),
        ('Suit (2 piece)', 100.0, PC, 'Suit (2 piece)'),
        ('Pant', 18.0, PC, 'Pant'),
        ('Jeans', 20.0, PC, 'Jeans'),
        ('Shorts', 12.0, PC, 'Shorts'),
        ('Top / Kurti', 15.0, PC, 'Top / Kurti'),
        ('Blouse', 12.0, PC, 'Shirt'),
        ('Dress', 25.0, PC, 'Shirt'),
        ('Leggings', 12.0, PC, 'Pant'),
        ('Salwar', 15.0, PC, 'Pant'),
        ('Skirt', 15.0, PC, 'Shirt'),
        ('Saree (Cotton)', 30.0, PC, 'Shirt'),
        ('Saree (Silk)', 50.0, PC, 'Saree (Silk)'),
        ('Dupatta', 12.0, PC, 'Shirt'),
        ('Bedsheet (Single)', 25.0, PC, 'Shirt'),
        ('Bedsheet (Double)', 35.0, PC, 'Shirt'),
        ('Pillow Cover', 10.0, PC, 'Shirt'),
        ('School Uniform', 10.0, PC, 'Shirt'),
    ]),
    ('Dry Cleaning', 'Sparkles', [
        ('Suit (2 piece)', 250.0, PC, 'Suit (2 piece)'),
        ('Suit (3 piece)', 350.0, PC, 'Suit (2 piece)'),
        ('Blazer / Jacket', 150.0, PC, 'Blazer/Jacket'),
        ('Overcoat (Wool)', 240.0, PC, 'Blazer/Jacket'),
        ('Leather Jacket', 400.0, PC, 'Blazer/Jacket'),
        ('Sherwani', 350.0, PC, 'Sherwani'),
        ('Saree (Silk)', 250.0, PC, 'Saree (Silk)'),
        ('Saree (Heavy work)', 400.0, PC, 'Saree (Silk)'),
        ('Lehenga (Bridal)', 700.0, PC, 'Lehenga (Bridal)'),
        ('Kurta (Silk)', 150.0, PC, 'Kurta'),
        ('Shirt (Silk/Premium)', 100.0, PC, 'Shirt'),
        ('Trouser (Wool)', 90.0, PC, 'Pant'),
        ('Dress / Gown', 200.0, PC, 'Shirt'),
        ('Blanket (Double)', 300.0, PC, 'Shirt'),
        ('Comforter', 400.0, PC, 'Shirt'),
        ('Curtains (Panel)', 180.0, PC, 'Shirt'),
        ('Party Dress', 140.0, PC, 'Shirt'),
        ('Winter Jacket', 190.0, PC, 'Blazer/Jacket'),
    ]),
    ('Household & Furnishing', 'Home', [
        ('Blanket (Wash)', 200.0, PC, 'Shirt'),
        ('Comforter (Wash)', 280.0, PC, 'Shirt'),
        ('Curtains (Wash)', 80.0, PC, 'Shirt'),
        ('Carpet (Vacuum)', 15.0, SQFT, 'Shirt'),
        ('Sofa Cleaning', 200.0, SET, 'Shirt'),
    ]),
    ('Shoe Care & Spa', 'Shoe', [
        ('Sports Shoes / Running', 200.0, PC, 'Shirt'),
        ('Sneakers Deep Clean', 250.0, PC, 'Shirt'),
        ('Leather Shoes Polish & Clean', 300.0, PC, 'Shirt'),
        ('Boots', 350.0, PC, 'Shirt'),
        ('Sandals', 100.0, PC, 'Shirt'),
        ('Suede Shoes Treatment', 350.0, PC, 'Shirt'),
        ('Heels / Designer Footwear', 250.0, PC, 'Shirt'),
    ]),
    ('Premium Care', 'Star', [
        ('Designer Handbag', 500.0, PC, 'Shirt'),
        ('Leather Bag Cleaning', 300.0, PC, 'Shirt'),
        ('Travel Bag / Suitcase', 400.0, PC, 'Shirt'),
        ('Soft Toy Cleaning', 100.0, PC, 'Shirt'),
        ('Stroller / Pram', 600.0, PC, 'Shirt'),
    ]),
]


def populate_default_services_for_shop(shop, overwrite_existing=False):
    """Creates default laundromat categories and garment items for a shop.

    If `overwrite_existing` is False, categories and items are created only if
    they don't already exist for this shop.
    """
    from .models import GarmentCategory, GarmentItem

    categories_created = 0
    items_created = 0

    for cat_order, (cat_name, cat_icon, items) in enumerate(DEFAULT_SERVICE_CATALOGUE):
        category, created = GarmentCategory.objects.get_or_create(
            shop=shop,
            name=cat_name,
            defaults={
                'icon': cat_icon,
                'display_order': cat_order,
                'is_active': True,
            },
        )
        if created:
            categories_created += 1

        for item_order, item_info in enumerate(items):
            item_name = item_info[0]
            price = item_info[1]
            unit = item_info[2]
            icon = item_info[3] if len(item_info) > 3 else 'Shirt'
            img = ITEM_IMAGES.get(item_name, '')

            item_obj, i_created = GarmentItem.objects.get_or_create(
                shop=shop,
                category=category,
                name=item_name,
                defaults={
                    'price': price,
                    'unit': unit,
                    'icon': icon,
                    'image_url': img,
                    'display_order': item_order,
                    'is_active': True,
                },
            )
            if i_created:
                items_created += 1
            elif overwrite_existing:
                item_obj.price = price
                item_obj.unit = unit
                item_obj.icon = icon
                if img:
                    item_obj.image_url = img
                item_obj.save()

    return {
        'categories_created': categories_created,
        'items_created': items_created,
    }
