"""Data migration to provision 'Owner' and 'Staff' Django Groups and permissions (KAN-127)."""
from django.db import migrations


def create_groups_and_permissions(apps, schema_editor):
    Group = apps.get_model('auth', 'Group')
    Permission = apps.get_model('auth', 'Permission')
    User = apps.get_model('auth', 'User')

    owner_group, _ = Group.objects.get_or_create(name='Owner')
    staff_group, _ = Group.objects.get_or_create(name='Staff')

    # Grant all API model permissions to Owner
    owner_perms = Permission.objects.filter(content_type__app_label='api')
    if owner_perms.exists():
        owner_group.permissions.set(owner_perms)

    # Grant operational permissions to Staff
    staff_model_actions = {
        'order': ['add_order', 'change_order', 'view_order'],
        'orderitem': ['add_orderitem', 'change_orderitem', 'view_orderitem'],
        'customer': ['add_customer', 'change_customer', 'view_customer'],
        'garmentitem': ['view_garmentitem'],
        'garmentcategory': ['view_garmentcategory'],
        'attendance': ['add_attendance', 'change_attendance', 'view_attendance'],
        'servicearea': ['view_servicearea'],
        'timeslot': ['view_timeslot'],
        'shop': ['view_shop'],
        'lead': ['add_lead', 'view_lead'],
    }

    staff_codenames = []
    for codenames in staff_model_actions.values():
        staff_codenames.extend(codenames)

    staff_perms = Permission.objects.filter(
        content_type__app_label='api',
        codename__in=staff_codenames,
    )
    if staff_perms.exists():
        staff_group.permissions.set(staff_perms)

    # Automatically add superusers and known staff emails to Owner group
    for u in User.objects.filter(is_superuser=True):
        u.groups.add(owner_group)
        if not u.is_staff:
            u.is_staff = True
            u.save(update_fields=['is_staff'])


def remove_groups_and_permissions(apps, schema_editor):
    Group = apps.get_model('auth', 'Group')
    Group.objects.filter(name__in=['Owner', 'Staff']).delete()


class Migration(migrations.Migration):
    dependencies = [
        ('api', '0025_auto_create_admin'),
        ('auth', '0012_alter_user_first_name_max_length'),
    ]

    operations = [
        migrations.RunPython(create_groups_and_permissions, remove_groups_and_permissions),
    ]
