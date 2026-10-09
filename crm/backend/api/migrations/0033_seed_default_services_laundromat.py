from django.db import migrations


def seed_default_services_for_all_shops(apps, schema_editor):
    import sys
    from django.conf import settings
    if 'test' in sys.argv or getattr(settings, 'TESTING', False):
        return

    Shop = apps.get_model('api', 'Shop')
    GarmentCategory = apps.get_model('api', 'GarmentCategory')
    GarmentItem = apps.get_model('api', 'GarmentItem')

    # Import default services catalogue definition
    from api.default_services import DEFAULT_SERVICE_CATALOGUE, ITEM_IMAGES

    for shop in Shop.objects.all():
        for cat_order, (cat_name, cat_icon, items) in enumerate(DEFAULT_SERVICE_CATALOGUE):
            category, _ = GarmentCategory.objects.get_or_create(
                shop=shop,
                name=cat_name,
                defaults={
                    'icon': cat_icon,
                    'display_order': cat_order,
                    'is_active': True,
                },
            )

            for item_order, item_info in enumerate(items):
                item_name = item_info[0]
                price = item_info[1]
                unit = item_info[2]
                icon = item_info[3] if len(item_info) > 3 else 'Shirt'
                img = ITEM_IMAGES.get(item_name, '')

                GarmentItem.objects.get_or_create(
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


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0032_seed_default_credit_categories"),
    ]

    operations = [
        migrations.RunPython(seed_default_services_for_all_shops, migrations.RunPython.noop),
    ]
