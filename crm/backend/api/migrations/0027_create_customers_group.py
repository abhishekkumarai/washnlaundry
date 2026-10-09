"""Data migration to provision 'Customers' Group and setup hierarchical permissions (KAN-131)."""
from django.db import migrations


def create_customers_group(apps, schema_editor):
    Group = apps.get_model('auth', 'Group')
    Permission = apps.get_model('auth', 'Permission')
    User = apps.get_model('auth', 'User')

    customers_group, _ = Group.objects.get_or_create(name='Customers')
    staff_group, _ = Group.objects.get_or_create(name='Staff')
    owner_group, _ = Group.objects.get_or_create(name='Owner')

    # Base permissions for Customers
    customer_codenames = [
        'view_order',
        'add_order',
        'view_customer',
        'change_customer',
        'view_garmentitem',
        'view_garmentcategory',
        'view_timeslot',
        'view_servicearea',
        'view_shop',
        'add_lead',
    ]

    customer_perms = Permission.objects.filter(
        content_type__app_label='api',
        codename__in=customer_codenames,
    )
    if customer_perms.exists():
        customers_group.permissions.set(customer_perms)

    # Ensure Staff group inherits all Customer permissions plus staff actions
    staff_codenames = customer_codenames + [
        'change_order',
        'view_orderitem',
        'add_orderitem',
        'change_orderitem',
        'add_customer',
        'add_attendance',
        'change_attendance',
        'view_attendance',
        'view_lead',
    ]
    staff_perms = Permission.objects.filter(
        content_type__app_label='api',
        codename__in=staff_codenames,
    )
    if staff_perms.exists():
        staff_group.permissions.set(staff_perms)

    # Owner group has all permissions across the API
    owner_perms = Permission.objects.filter(content_type__app_label='api')
    if owner_perms.exists():
        owner_group.permissions.set(owner_perms)

    # Assign existing non-staff users into the Customers group
    for u in User.objects.filter(is_staff=False, is_superuser=False):
        u.groups.add(customers_group)


def remove_customers_group(apps, schema_editor):
    Group = apps.get_model('auth', 'Group')
    Group.objects.filter(name='Customers').delete()


class Migration(migrations.Migration):
    dependencies = [
        ('api', '0026_create_groups_and_permissions'),
    ]

    operations = [
        migrations.RunPython(create_customers_group, remove_customers_group),
    ]
