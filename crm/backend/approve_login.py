"""Look up an email and (optionally) approve its sign-in. Run against the REAL database:

    cd crm/backend
    DJANGO_DATABASE_URL='<neon url>' python manage.py shell < approve_login.py            # look only
    DJANGO_DATABASE_URL='<neon url>' APPROVE=1 python manage.py shell < approve_login.py  # approve

EMAIL defaults to account.sipu@gmail.com (override with EMAIL=...). Nothing is changed unless APPROVE=1.
Approval means: a pending customer link request is approved, or a staff row with that email has its
sign-in switched on (membership reactivated). It never touches passwords.
"""
import os

from django.contrib.auth import get_user_model
from api.models import Customer, EmailLinkRequest, Shop, ShopMembership, Staff

EMAIL = os.environ.get('EMAIL', 'account.sipu@gmail.com').strip().lower()
APPROVE = os.environ.get('APPROVE') == '1'
User = get_user_model()

print('real shops:', [(s.pk, s.slug, s.status) for s in Shop.objects.exclude(slug__startswith='demo-')])
users = User.objects.filter(username__iexact=EMAIL)
print('user:', [(u.pk, u.is_active, u.is_superuser, u.has_usable_password()) for u in users])
print('memberships:', [(m.shop.slug, m.role, m.is_active) for m in ShopMembership.objects.filter(user__username__iexact=EMAIL)])
staff = list(Staff.all_objects.filter(email__iexact=EMAIL))
print('staff:', [(s.pk, s.shop.slug, s.name, s.role, s.status, s.has_app_login) for s in staff])
print('customers:', [(str(c.pk)[:8], c.shop.slug, c.name, c.phone) for c in Customer.all_objects.filter(email__iexact=EMAIL)])
links = list(EmailLinkRequest.objects.filter(email__iexact=EMAIL))
print('link requests:', [(r.pk, r.status, r.customer.name, r.customer.phone) for r in links])

if not APPROVE:
    print('\nDRY RUN: nothing changed. Re-run with APPROVE=1 to approve.')
else:
    done = False
    for r in links:
        if r.status == EmailLinkRequest.PENDING:
            print('approve link request', r.pk, '->', r.approve())
            done = True
    for s in staff:
        if s.status == 'ACTIVE' and not s.has_app_login:
            s.has_app_login = True
            s.save()  # reactivates / creates the shop membership
            print('staff sign-in enabled:', s.pk, s.name)
            done = True
    print('APPROVED' if done else 'Nothing to approve (already approved, or no matching record).')
