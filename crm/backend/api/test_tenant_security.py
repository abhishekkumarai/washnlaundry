"""Cross-tenant isolation and shop lifecycle (create / read / update / archive / purge)."""
from io import StringIO
from unittest import mock

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from api.models import (
    Customer, Shop, ShopMembership, ShopRole, ShopStatus, Staff,
)

User = get_user_model()


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True)
class TenantSecurityTests(TestCase):
    def setUp(self):
        self.a = Shop.objects.create(name='Alpha Wash', slug='alpha')
        self.b = Shop.objects.create(name='Beta Wash', slug='beta')
        self.owner_a = User.objects.create_user('owner-a@x.com', 'owner-a@x.com', 'pw')
        self.owner_b = User.objects.create_user('owner-b@x.com', 'owner-b@x.com', 'pw')
        ShopMembership.objects.create(user=self.owner_a, shop=self.a, role=ShopRole.OWNER, is_default=True)
        ShopMembership.objects.create(user=self.owner_b, shop=self.b, role=ShopRole.OWNER, is_default=True)
        Customer.all_objects.create(shop=self.b, name='Beta Customer', phone='9000000001')
        patcher = mock.patch('api.auth.id_token.verify_oauth2_token')
        self.verify = patcher.start()
        self.addCleanup(patcher.stop)
        self.client = APIClient()

    def as_(self, email):
        self.verify.return_value = {'email': email, 'email_verified': True}
        return {'HTTP_AUTHORIZATION': 'Bearer tok'}

    # ── isolation ────────────────────────────────────────────────────────────
    def test_owner_of_one_shop_cannot_use_another_via_header(self):
        auth = self.as_('owner-a@x.com')
        ok = self.client.get('/api/customers/', HTTP_X_TENANT_ID='alpha', **auth)
        self.assertEqual(ok.status_code, 200)
        spoof = self.client.get('/api/customers/', HTTP_X_TENANT_ID='beta', **auth)
        self.assertEqual(spoof.status_code, 403)

    def test_global_owner_group_does_not_cross_shops(self):
        # sync_user_groups puts every shop owner in the global "Owner" group.
        group, _ = Group.objects.get_or_create(name='Owner')
        self.owner_a.groups.add(group)
        auth = self.as_('owner-a@x.com')
        res = self.client.get('/api/customers/', HTTP_X_TENANT_ID='beta', **auth)
        self.assertEqual(res.status_code, 403)

    def test_staff_emails_setting_no_longer_exists(self):
        from django.conf import settings
        self.assertFalse(hasattr(settings, 'STAFF_EMAILS'))

    def test_two_shops_and_no_tenant_is_rejected_not_guessed(self):
        auth = self.as_('owner-a@x.com')
        res = self.client.get('/api/customers/', **auth)
        self.assertEqual(res.status_code, 400)

    def test_unsaved_tenant_scoped_row_without_tenant_raises(self):
        with self.assertRaises(ValueError):
            Customer(name='Orphan', phone='9000000002').save()

    # ── shop CRUD ────────────────────────────────────────────────────────────
    def test_shop_list_only_shows_own_shops(self):
        auth = self.as_('owner-a@x.com')
        res = self.client.get('/api/shops/', **auth)
        body = res.json()
        rows = body.get('results', body) if isinstance(body, dict) else body
        slugs = {s['slug'] for s in rows}
        self.assertEqual(slugs, {'alpha'})

    def test_cannot_update_or_archive_someone_elses_shop(self):
        auth = self.as_('owner-a@x.com')
        self.assertEqual(self.client.patch(f'/api/shops/{self.b.id}/', {'name': 'Hacked'},
                                           format='json', **auth).status_code, 404)
        self.assertEqual(self.client.delete(f'/api/shops/{self.b.id}/', **auth).status_code, 404)
        self.b.refresh_from_db()
        self.assertEqual((self.b.name, self.b.status), ('Beta Wash', ShopStatus.ACTIVE))

    def test_owner_can_edit_profile_but_not_protected_fields(self):
        auth = self.as_('owner-a@x.com')
        ok = self.client.patch(f'/api/shops/{self.a.id}/', {'city': 'Pune'}, format='json',
                               HTTP_X_TENANT_ID='alpha', **auth)
        self.assertEqual(ok.status_code, 200)
        for body in ({'slug': 'x'}, {'status': 'ACTIVE'}, {'subdomain': 'x'}, {'order_prefix': 'ZZZZ'}):
            res = self.client.patch(f'/api/shops/{self.a.id}/', body, format='json',
                                    HTTP_X_TENANT_ID='alpha', **auth)
            self.assertEqual(res.status_code, 403, body)

    def test_delete_archives_and_archived_shop_stops_serving(self):
        auth = self.as_('owner-a@x.com')
        res = self.client.delete(f'/api/shops/{self.a.id}/', HTTP_X_TENANT_ID='alpha', **auth)
        self.assertEqual(res.status_code, 204)
        self.a.refresh_from_db()
        self.assertEqual(self.a.status, ShopStatus.ARCHIVED)
        self.assertEqual(self.client.get('/api/customers/', HTTP_X_TENANT_ID='alpha', **auth).status_code, 403)

    def test_purge_requires_archived_and_confirmation(self):
        with self.assertRaises(CommandError):
            call_command('purge_shop', 'alpha', '--confirm', 'alpha', stdout=StringIO())
        self.a.status = ShopStatus.ARCHIVED
        self.a.save(update_fields=['status'])
        with self.assertRaises(CommandError):
            call_command('purge_shop', 'alpha', '--confirm', 'nope', stdout=StringIO())
        call_command('purge_shop', 'alpha', '--confirm', 'alpha', stdout=StringIO())
        self.assertFalse(Shop.objects.filter(slug='alpha').exists())

    # ── provisioning ─────────────────────────────────────────────────────────
    def test_provision_requires_sign_in_when_enforced(self):
        self.assertEqual(self.client.post('/api/shops/provision/', {'name': 'Nope'},
                                          format='json').status_code, 401)

    def test_provision_validates_slug(self):
        auth = self.as_('owner-a@x.com')
        for slug in ('Bad Slug!', 'admin', 'beta'):
            res = self.client.post('/api/shops/provision/', {'name': 'N', 'slug': slug},
                                   format='json', **auth)
            self.assertEqual(res.status_code, 400, slug)

    @override_settings(MAX_SHOPS_PER_USER=1)
    def test_provision_respects_shop_limit(self):
        auth = self.as_('owner-a@x.com')
        res = self.client.post('/api/shops/provision/', {'name': 'Second'}, format='json', **auth)
        self.assertEqual(res.status_code, 403)

    def test_subdomain_is_unique_when_set(self):
        from django.db import IntegrityError, transaction
        with self.assertRaises(IntegrityError), transaction.atomic():
            Shop.objects.create(name='Dup', slug='dup', subdomain=self.a.subdomain)

    # ── membership lifecycle ─────────────────────────────────────────────────
    def test_deleting_staff_revokes_membership(self):
        staff = Staff.all_objects.create(shop=self.a, name='Sam', phone='9111111111',
                                         email='sam@x.com', has_app_login=True, status='ACTIVE')
        self.assertTrue(ShopMembership.objects.filter(user__username='sam@x.com', shop=self.a).exists())
        staff.delete()
        self.assertFalse(ShopMembership.objects.filter(user__username='sam@x.com', shop=self.a).exists())

    def test_last_owner_cannot_be_removed_or_demoted(self):
        owner_staff = Staff.all_objects.create(shop=self.a, name='Olive', phone='9222222222',
                                               email='owner-a@x.com', role='Owner',
                                               has_app_login=True, status='ACTIVE')
        auth = self.as_('owner-a@x.com')
        hdr = {'HTTP_X_TENANT_ID': 'alpha', **auth}
        self.assertEqual(self.client.delete(f'/api/staff/{owner_staff.id}/', **hdr).status_code, 400)
        self.assertEqual(self.client.patch(f'/api/staff/{owner_staff.id}/', {'status': 'INACTIVE'},
                                           format='json', **hdr).status_code, 400)

    def test_transfer_ownership(self):
        member = User.objects.create_user('mgr@x.com', 'mgr@x.com', 'pw')
        ShopMembership.objects.create(user=member, shop=self.a, role=ShopRole.STAFF)
        auth = self.as_('owner-a@x.com')
        res = self.client.post(f'/api/shops/{self.a.id}/transfer-ownership/', {'email': 'mgr@x.com'},
                               format='json', HTTP_X_TENANT_ID='alpha', **auth)
        self.assertEqual(res.status_code, 200)
        roles = dict(ShopMembership.objects.filter(shop=self.a).values_list('user__username', 'role'))
        self.assertEqual(roles, {'owner-a@x.com': ShopRole.STAFF, 'mgr@x.com': ShopRole.OWNER})


class OrderNumberUniquenessTests(TestCase):
    """Order numbers must not collide across shops, even for look-alike names."""

    def test_shops_with_the_same_or_similar_names_get_distinct_prefixes(self):
        a = Shop.objects.create(name='Spotless Cleaners')
        b = Shop.objects.create(name='Spotless Cleaners')
        c = Shop.objects.create(name='Spotless Laundry')
        self.assertEqual(len({a.order_prefix, b.order_prefix, c.order_prefix}), 3)

    def test_first_orders_of_look_alike_shops_do_not_share_a_number(self):
        from api.tenancy import tenant_context
        from api.models import Order
        numbers = []
        for _ in range(2):
            shop = Shop.objects.create(name='Spotless Cleaners')
            with tenant_context(shop):
                numbers.append(Order.objects.create(customer_name='A', customer_phone='1').order_number)
        self.assertEqual(len(set(numbers)), 2, numbers)

    def test_explicit_duplicate_prefix_is_rejected_by_the_database(self):
        from django.db import IntegrityError, transaction
        Shop.objects.create(name='One', order_prefix='DUPE')
        with self.assertRaises(IntegrityError), transaction.atomic():
            Shop.objects.create(name='Two', order_prefix='dupe')  # normalised to DUPE

    def test_numbering_passes_99999_without_reissuing(self):
        from api.tenancy import tenant_context
        from api.models import Order
        shop = Shop.objects.create(name='Big Shop')
        with tenant_context(shop):
            Order.objects.create(customer_name='A', customer_phone='1',
                                 order_number=f'{shop.order_prefix}-99999')
            nxt = Order.objects.create(customer_name='B', customer_phone='2')
            after = Order.objects.create(customer_name='C', customer_phone='3')
        self.assertEqual(nxt.order_number, f'{shop.order_prefix}-100000')
        self.assertEqual(after.order_number, f'{shop.order_prefix}-100001')

    @override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=False)
    def test_provision_rejects_a_taken_prefix(self):
        Shop.objects.create(name='Taken', order_prefix='TAKE')
        res = APIClient().post('/api/shops/provision/', {'name': 'Other', 'order_prefix': 'take'},
                               format='json')
        self.assertEqual(res.status_code, 400)
