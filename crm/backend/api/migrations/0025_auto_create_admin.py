from django.db import migrations
from django.contrib.auth.hashers import make_password
import os


def create_superusers(apps, schema_editor):
    User = apps.get_model('auth', 'User')
    password = os.environ.get('DJANGO_SUPERUSER_PASSWORD', 'WashNLaundry@2026')
    hashed_pwd = make_password(password)

    # Ensure 'admin' superuser
    admin_user, _ = User.objects.get_or_create(
        username='admin',
        defaults={'email': 'washnlaundry01@gmail.com'},
    )
    admin_user.password = hashed_pwd
    admin_user.is_superuser = True
    admin_user.is_staff = True
    admin_user.is_active = True
    admin_user.save()

    # Ensure washnlaundry01@gmail.com superuser
    w_user, _ = User.objects.get_or_create(
        username='washnlaundry01@gmail.com',
        defaults={'email': 'washnlaundry01@gmail.com'},
    )
    w_user.password = hashed_pwd
    w_user.is_superuser = True
    w_user.is_staff = True
    w_user.is_active = True
    w_user.save()

    # Promote 3abhishekkumar@gmail.com if present
    u = User.objects.filter(username='3abhishekkumar@gmail.com').first()
    if u:
        u.is_superuser = True
        u.is_staff = True
        u.is_active = True
        u.save()


def reverse_superusers(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ('api', '0024_shop_default_name'),
    ]

    operations = [
        migrations.RunPython(create_superusers, reverse_superusers),
    ]
