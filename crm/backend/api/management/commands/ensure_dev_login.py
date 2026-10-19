import os

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = (
        'Local dev only: make DEV_USER_EMAIL an active password account with '
        'DEV_USER_PASSWORD (both from the environment / crm/.env), so it can sign in '
        'on the email + password form. Does nothing unless DEBUG is on.'
    )

    def handle(self, *args, **options):
        email = os.environ.get('DEV_USER_EMAIL', '').strip().lower()
        password = os.environ.get('DEV_USER_PASSWORD', '')
        if not settings.DEBUG or not email or not password:
            self.stdout.write('ensure_dev_login: skipped (needs DEBUG, DEV_USER_EMAIL, DEV_USER_PASSWORD).')
            return
        User = get_user_model()
        # username = lower-cased email, as api/password_auth.py signs people up.
        user = User.objects.filter(username=email).first() or User(username=email, email=email)
        user.set_password(password)
        user.is_active = True
        user.save()
        self.stdout.write(self.style.SUCCESS(f'ensure_dev_login: {email} can sign in with its password.'))
