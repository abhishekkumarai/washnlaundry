"""Owner-issued customer sign-in (POST/DELETE /api/customers/<id>/credentials/)."""
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from api.models import Customer, Shop, ShopMembership, ShopRole, Staff

User = get_user_model()


class CustomerCredentialsTests(TestCase):
    def setUp(self):
        self.shop = Shop.objects.create(name='A', slug='shop-a')
        self.other = Shop.objects.create(name='B', slug='shop-b')
        self.customer = Customer.objects.create(shop=self.shop, name='Ravi', phone='9811111111')
        self.client = APIClient()

    def url(self, customer=None):
        return f'/api/customers/{(customer or self.customer).pk}/credentials/?shop={self.shop.id}'

    def test_enable_creates_account_membership_and_password(self):
        r = self.client.post(self.url(), {'email': 'Ravi@Example.com', 'password': 'S3cret-pass'}, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertTrue(r.data['password_set'])
        user = User.objects.get(username='ravi@example.com')
        self.assertTrue(user.check_password('S3cret-pass'))
        self.assertEqual(ShopMembership.objects.get(user=user, shop=self.shop).role, ShopRole.CUSTOMER)
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.email, 'ravi@example.com')
        listed = self.client.get(f'/api/customers/{self.customer.pk}/?shop={self.shop.id}')
        self.assertTrue(listed.data['has_app_login'])

    def test_validation_and_duplicates(self):
        self.assertEqual(self.client.post(self.url(), {'email': 'x', 'password': 'S3cret-pass'}, format='json').status_code, 400)
        self.assertEqual(self.client.post(self.url(), {'email': 'a@b.co', 'password': 'short'}, format='json').status_code, 400)
        Customer.objects.create(shop=self.shop, name='Sita', phone='9822222222', email='sita@example.com')
        r = self.client.post(self.url(), {'email': 'sita@example.com', 'password': 'S3cret-pass'}, format='json')
        self.assertEqual(r.status_code, 400)

    def test_never_overwrites_a_staff_or_other_shop_account(self):
        owner = User.objects.create_user('boss@example.com', 'boss@example.com', 'their-own-pass')
        ShopMembership.objects.create(user=owner, shop=self.other, role=ShopRole.OWNER)
        r = self.client.post(self.url(), {'email': 'boss@example.com', 'password': 'attacker-pass'}, format='json')
        self.assertFalse(r.data['password_set'])
        owner.refresh_from_db()
        self.assertTrue(owner.check_password('their-own-pass'))

        worker = User.objects.create_user('w@example.com', 'w@example.com', 'worker-pass')
        Staff.objects.create(shop=self.other, name='W', phone='9000000001', email='w@example.com')
        r = self.client.post(self.url(), {'email': 'w@example.com', 'password': 'attacker-pass'}, format='json')
        self.assertFalse(r.data['password_set'])
        worker.refresh_from_db()
        self.assertTrue(worker.check_password('worker-pass'))

    def test_owner_can_reset_then_revoke(self):
        self.client.post(self.url(), {'email': 'ravi@example.com', 'password': 'first-pass-1'}, format='json')
        r = self.client.post(self.url(), {'email': 'ravi@example.com', 'password': 'second-pass-2'}, format='json')
        self.assertTrue(r.data['password_set'])
        user = User.objects.get(username='ravi@example.com')
        self.assertTrue(user.check_password('second-pass-2'))

        self.assertEqual(self.client.delete(self.url()).status_code, 200)
        user.refresh_from_db()
        self.assertFalse(user.has_usable_password())
        self.assertFalse(ShopMembership.objects.filter(user=user, shop=self.shop).exists())

    def test_other_shops_customer_is_not_reachable(self):
        foreign = Customer.objects.create(shop=self.other, name='Z', phone='9833333333')
        r = self.client.post(self.url(foreign), {'email': 'z@example.com', 'password': 'S3cret-pass'}, format='json')
        self.assertEqual(r.status_code, 404)
