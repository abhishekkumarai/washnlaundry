from django.db import migrations


def dedupe_order_prefixes(apps, schema_editor):
    """Give every shop its own order prefix before it becomes unique.

    The oldest shop keeps its prefix; later shops sharing it get a numeric
    suffix. Order numbers already issued are left alone (customers hold
    receipts), so only numbers issued from now on are platform-unique.
    """
    Shop = apps.get_model('api', 'Shop')
    seen = set()
    for shop in Shop.objects.order_by('pk'):
        prefix = (shop.order_prefix or '').strip().upper()
        if not prefix:
            continue
        candidate, n = prefix, 2
        while candidate in seen:
            candidate = f'{prefix}{n}'
            n += 1
        seen.add(candidate)
        if candidate != shop.order_prefix:
            shop.order_prefix = candidate
            shop.save(update_fields=['order_prefix'])


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0035_shop_lifecycle"),
    ]

    operations = [
        migrations.RunPython(dedupe_order_prefixes, migrations.RunPython.noop),
    ]
