"""KAN-217 / KAN-215: find a shop, join it as a customer, customer role resolution."""
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import override_settings
from rest_framework.test import APITestCase

from .models import Customer, CustomerAddress, EmailLinkRequest, Shop, ShopMembership, ShopRole


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True)
class CustomerJoinTests(APITestCase):
    def setUp(self):
        cache.clear()
        self.sunny = Shop.objects.create(name='Sunny Laundry', slug='sunny', city='Bengaluru',
                                         pin_code='560038', accepts_online_customers=True)
        self.closed = Shop.objects.create(name='Closed Cleaners', slug='closed')
        self.known = Customer.all_objects.create(shop=self.sunny, name='Asha', phone='9876500001')
        patcher = mock.patch('api.auth.id_token.verify_oauth2_token')
        self.verify = patcher.start()
        self.addCleanup(patcher.stop)
        self.as_('new@example.com')

    def as_(self, email):
        self.verify.return_value = {'email': email, 'email_verified': True}

    def auth(self, shop=None):
        extra = {'HTTP_AUTHORIZATION': 'Bearer tok'}
        if shop:
            extra['HTTP_X_TENANT_ID'] = shop.slug
        return extra

    def join(self, shop, **body):
        body = {'name': 'Neha', 'phone': '98765 00002', **body}
        return self.client.post('/api/customer/join/', body, format='json', **self.auth(shop))

    def test_search_lists_only_opted_in_active_shops(self):
        Shop.objects.create(name='Sunny Demo', slug='demo-abc', accepts_online_customers=True)
        Shop.objects.create(name='Sunny Old', slug='sunny-old', accepts_online_customers=True,
                            status='ARCHIVED')
        for q in ('sunny', '560038', 'bengal'):
            res = self.client.get('/api/customer/shops/', {'q': q})
            self.assertEqual([s['slug'] for s in res.json()['shops']], ['sunny'], q)
        self.assertEqual(self.client.get('/api/customer/shops/sunny/').json()['name'], 'Sunny Laundry')
        self.assertEqual(self.client.get('/api/customer/shops/closed/').status_code, 404)

    def test_join_creates_customer_and_membership_then_resolves_as_customer(self):
        res = self.join(self.sunny)
        self.assertEqual(res.status_code, 201, res.content)
        customer = Customer.all_objects.get(shop=self.sunny, email='new@example.com')
        self.assertEqual((customer.name, customer.phone), ('Neha', '9876500002'))
        user = get_user_model().objects.get(username='new@example.com')
        self.assertTrue(ShopMembership.objects.filter(
            user=user, shop=self.sunny, role=ShopRole.CUSTOMER, is_active=True).exists())
        # Joining again is a no-op.
        self.assertEqual(self.join(self.sunny).status_code, 200)
        self.assertEqual(Customer.all_objects.filter(email='new@example.com').count(), 1)
        for self_service in (False, True):
            with override_settings(SELF_SERVICE_SHOPS=self_service):
                for shop in (self.sunny, None):  # with and without X-Tenant-ID
                    me = self.client.get('/api/me/', **self.auth(shop)).json()
                    self.assertEqual(me['role'], 'customer', (self_service, shop))
                    self.assertNotIn('needs_shop_onboarding', me)
                    res = self.client.get('/api/customer/orders/', **self.auth(shop))
                    self.assertEqual(res.status_code, 200, (self_service, shop))

    def test_existing_phone_needs_owner_approval(self):
        res = self.join(self.sunny, phone='9876500001')
        self.assertEqual(res.status_code, 202, res.content)
        link = EmailLinkRequest.all_objects.get(customer=self.known)
        self.assertEqual((link.email, link.status, link.shop), ('new@example.com', 'PENDING', self.sunny))
        self.assertIsNone(Customer.all_objects.filter(email='new@example.com').first())
        self.assertEqual(self.client.get('/api/customer/orders/', **self.auth(self.sunny)).status_code, 404)
        self.assertTrue(link.approve())
        self.known.refresh_from_db()
        self.assertEqual(self.known.email, 'new@example.com')
        user = get_user_model().objects.get(username='new@example.com')
        self.assertTrue(ShopMembership.objects.filter(user=user, shop=self.sunny,
                                                      role=ShopRole.CUSTOMER).exists())
        self.assertEqual(self.client.get('/api/customer/orders/').status_code, 401)
        self.assertEqual(self.client.get('/api/customer/orders/', **self.auth()).status_code, 200)

    def test_join_is_refused_for_shops_not_taking_online_customers(self):
        self.assertEqual(self.join(self.closed).status_code, 404)
        self.assertEqual(self.join(None).status_code, 404)
        self.assertFalse(Customer.all_objects.filter(email='new@example.com').exists())

    def test_demo_accounts_cannot_join_a_real_shop(self):
        with mock.patch('api.customer_views.verified_email', return_value='abc123@demo.invalid'):
            self.assertEqual(self.join(self.sunny).status_code, 403)
        self.assertFalse(Customer.all_objects.filter(email='abc123@demo.invalid').exists())

    def test_join_validates_and_requires_sign_in(self):
        self.assertEqual(self.join(self.sunny, phone='12345').status_code, 400)
        self.assertEqual(self.join(self.sunny, name=' ').status_code, 400)
        res = self.client.post('/api/customer/join/', {'name': 'X', 'phone': '9876500003'},
                               format='json', HTTP_X_TENANT_ID='sunny')
        self.assertEqual(res.status_code, 401)

    def test_customer_of_one_shop_is_not_a_customer_of_another(self):
        self.join(self.sunny)
        other = Shop.objects.create(name='Other', slug='other', accepts_online_customers=True)
        self.assertEqual(self.client.get('/api/me/', **self.auth(other)).json()['role'], 'unlinked')
        self.assertEqual(self.client.get('/api/customer/orders/', **self.auth(other)).status_code, 404)

    def test_joining_another_shop_reuses_name_phone_and_addresses(self):
        self.assertEqual(self.join(self.sunny).status_code, 201)
        first = Customer.all_objects.get(shop=self.sunny, email='new@example.com')
        CustomerAddress.all_objects.create(shop=self.sunny, customer=first, label='HOME',
                                           address='12 MG Road', pin_code='560001', is_default=True)
        other = Shop.objects.create(name='Other', slug='other', accepts_online_customers=True)
        res = self.client.post('/api/customer/join/', {}, format='json', **self.auth(other))
        self.assertEqual(res.status_code, 201, res.content)
        joined = Customer.all_objects.get(shop=other, email='new@example.com')
        self.assertEqual((joined.name, joined.phone), ('Neha', '9876500002'))
        copied = CustomerAddress.all_objects.get(customer=joined)
        self.assertEqual((copied.shop, copied.address, copied.is_default), (other, '12 MG Road', True))

    def test_a_first_join_still_needs_name_and_phone(self):
        res = self.client.post('/api/customer/join/', {}, format='json', **self.auth(self.sunny))
        self.assertEqual(res.status_code, 400)
        self.assertFalse(Customer.all_objects.filter(email='new@example.com').exists())

    def test_owner_keeps_owner_role_after_joining_another_shop_as_customer(self):
        owner = get_user_model().objects.create_user(username='new@example.com', email='new@example.com')
        ShopMembership.objects.create(user=owner, shop=self.closed, role=ShopRole.OWNER, is_default=True)
        self.assertEqual(self.join(self.sunny).status_code, 201)
        self.assertEqual(self.client.get('/api/me/', **self.auth(self.closed)).json()['role'], 'owner')
        self.assertEqual(self.client.get('/api/me/', **self.auth(self.sunny)).json()['role'], 'customer')
