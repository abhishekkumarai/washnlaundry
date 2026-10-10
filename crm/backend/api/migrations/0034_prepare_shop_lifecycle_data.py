from django.conf import settings
from django.db import migrations


def prepare_existing_data(apps, schema_editor):
    """Make existing data satisfy the new rules before they are enforced.

    1. Duplicate non-empty subdomains / custom domains would break the new unique
       constraints (and made tenant resolution ambiguous): keep the oldest.
    2. STAFF_EMAILS no longer grants ownership, so every login-enabled Staff row
       gets the explicit ShopMembership that now carries its access.
    """
    Shop = apps.get_model('api', 'Shop')
    for field in ('subdomain', 'custom_domain'):
        seen = set()
        for shop in Shop.objects.exclude(**{field: ''}).order_by('pk'):
            value = getattr(shop, field).lower()
            if value in seen:
                setattr(shop, field, '' if field == 'custom_domain' else f'{value}-{shop.pk}')
                shop.save(update_fields=[field])
            else:
                seen.add(value)

    Staff = apps.get_model('api', 'Staff')
    ShopMembership = apps.get_model('api', 'ShopMembership')
    User = apps.get_model(*settings.AUTH_USER_MODEL.split('.'))
    for staff in Staff.objects.filter(has_app_login=True).exclude(email='').exclude(shop__isnull=True):
        email = staff.email.strip().lower()
        user, _ = User.objects.get_or_create(username=email, defaults={'email': email, 'is_active': True})
        role = 'OWNER' if staff.role.strip().lower() in ('owner', 'manager') else 'STAFF'
        ShopMembership.objects.update_or_create(
            user=user, shop_id=staff.shop_id,
            defaults={'role': role, 'is_active': staff.status == 'ACTIVE'},
        )


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0033_seed_default_services_laundromat"),
    ]

    operations = [
        migrations.RunPython(prepare_existing_data, migrations.RunPython.noop),
    ]
