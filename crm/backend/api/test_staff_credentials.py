"""Owner-issued staff sign-in credentials (POST/DELETE /api/staff/<id>/credentials/)."""
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from api.models import Customer, Shop, ShopMembership, ShopRole, Staff

User = get_user_model()


class StaffCredentialsTests(TestCase):
    def setUp(self):
        self.shop = Shop.objects.create(name='A', slug='shop-a')
        self.other = Shop.objects.create(name='B', slug='shop-b')
        self.staff = Staff.objects.create(shop=self.shop, name='Asha', phone='9876543210')
        self.client = APIClient()

    def url(self, staff=None):
        return f'/api/staff/{(staff or self.staff).pk}/credentials/?shop={self.shop.id}'

    def test_enable_creates_login_and_membership_with_password(self):
        r = self.client.post(self.url(), {'email': 'Asha@Example.com', 'password': 'S3cret-pass'}, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertTrue(r.data['password_set'])
        user = User.objects.get(username='asha@example.com')
        self.assertTrue(user.check_password('S3cret-pass'))
        self.assertTrue(user.is_active)
        m = ShopMembership.objects.get(user=user, shop=self.shop)
        self.assertEqual(m.role, ShopRole.STAFF)
        self.staff.refresh_from_db()
        self.assertTrue(self.staff.has_app_login)
        self.assertEqual(self.staff.email, 'asha@example.com')

    def test_validation(self):
        bad_email = self.client.post(self.url(), {'email': 'nope', 'password': 'S3cret-pass'}, format='json')
        self.assertEqual(bad_email.status_code, 400)
        short = self.client.post(self.url(), {'email': 'a@b.co', 'password': 'short'}, format='json')
        self.assertEqual(short.status_code, 400)

    def test_duplicate_email_in_same_shop_rejected(self):
        Staff.objects.create(shop=self.shop, name='Ravi', phone='9876543211', email='ravi@example.com')
        r = self.client.post(self.url(), {'email': 'ravi@example.com', 'password': 'S3cret-pass'}, format='json')
        self.assertEqual(r.status_code, 400)

    def test_never_overwrites_password_of_an_account_from_another_shop(self):
        victim = User.objects.create_user('boss@example.com', 'boss@example.com', 'their-own-pass')
        ShopMembership.objects.create(user=victim, shop=self.other, role=ShopRole.OWNER)
        r = self.client.post(self.url(), {'email': 'boss@example.com', 'password': 'attacker-pass'}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertFalse(r.data['password_set'])
        victim.refresh_from_db()
        self.assertTrue(victim.check_password('their-own-pass'))

    def test_never_overwrites_a_customer_account(self):
        user = User.objects.create_user('cust@example.com', 'cust@example.com', 'cust-pass')
        Customer.objects.create(shop=self.other, name='C', phone='9000000000', email='cust@example.com')
        r = self.client.post(self.url(), {'email': 'cust@example.com', 'password': 'attacker-pass'}, format='json')
        self.assertFalse(r.data['password_set'])
        user.refresh_from_db()
        self.assertTrue(user.check_password('cust-pass'))

    def test_owner_can_reset_a_staff_logins_password(self):
        self.client.post(self.url(), {'email': 'asha@example.com', 'password': 'first-pass-1'}, format='json')
        r = self.client.post(self.url(), {'email': 'asha@example.com', 'password': 'second-pass-2'}, format='json')
        self.assertTrue(r.data['password_set'])
        self.assertTrue(User.objects.get(username='asha@example.com').check_password('second-pass-2'))

    def test_revoke_removes_membership(self):
        self.client.post(self.url(), {'email': 'asha@example.com', 'password': 'S3cret-pass'}, format='json')
        r = self.client.delete(self.url())
        self.assertEqual(r.status_code, 200)
        self.staff.refresh_from_db()
        self.assertFalse(self.staff.has_app_login)
        self.assertFalse(ShopMembership.objects.filter(user__username='asha@example.com', shop=self.shop).exists())

    def test_cannot_touch_staff_of_another_shop(self):
        foreign = Staff.objects.create(shop=self.other, name='Zed', phone='9876543299')
        r = self.client.post(self.url(foreign), {'email': 'z@example.com', 'password': 'S3cret-pass'}, format='json')
        self.assertEqual(r.status_code, 404)
