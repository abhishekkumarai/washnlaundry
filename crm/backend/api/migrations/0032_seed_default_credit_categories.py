from django.db import migrations

DEFAULT_CREDIT_CATEGORIES = [
    'Laundry Income',
    'Dry Cleaning Income',
    'Delivery Charges',
    'Customer Advance',
    'Owner Investment',
    'Other',
]


def seed_default_credit_categories(apps, schema_editor):
    Shop = apps.get_model('api', 'Shop')
    CreditCategory = apps.get_model('api', 'CreditCategory')

    for shop in Shop.objects.all():
        for order, name in enumerate(DEFAULT_CREDIT_CATEGORIES):
            CreditCategory.objects.get_or_create(
                shop=shop,
                name=name,
                defaults={'display_order': order, 'is_active': True}
            )


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0031_metasettings_whatsapp_business_account_id_and_more"),
    ]

    operations = [
        migrations.RunPython(seed_default_credit_categories, migrations.RunPython.noop),
    ]
