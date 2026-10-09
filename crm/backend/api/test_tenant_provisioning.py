"""Unit and integration tests for Tenant Provisioning (KAN-136)."""
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from api.models import (
    Shop, GarmentCategory, GarmentItem, CreditCategory,
    ShopOrderSequence, ShopMembership, ShopRole,
)
from api.auth import resolve_principal, OWNER

User = get_user_model()


class TenantProvisioningTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='newowner@example.com',
            email='newowner@example.com',
            password='securepassword123',
        )

    def test_provision_new_shop_unauthenticated(self):
        """Self-service onboarding creates a new shop even without initial auth."""
        payload = {
            'name': 'Spotless Cleaners',
            'phone': '+91 91234 56789',
            'owner_name': 'Ravi Kumar',
            'tax_rate': 18.0,
            'city': 'Bengaluru',
        }
        res = self.client.post('/api/shops/provision/', payload, format='json')
        self.assertEqual(res.status_code, 201)
        data = res.json()

        shop = Shop.objects.get(id=data['id'])
        self.assertEqual(shop.name, 'Spotless Cleaners')
        self.assertEqual(shop.slug, 'spotless-cleaners')
        self.assertEqual(shop.order_prefix, 'SPOT')
        self.assertEqual(shop.tax_rate, 18.0)
        self.assertEqual(shop.city, 'Bengaluru')

        # Check sequence initialized
        seq = ShopOrderSequence.objects.filter(shop=shop).first()
        self.assertIsNotNone(seq)
        self.assertEqual(seq.last_number, 0)

        # Check seeded default credit categories
        credit_cats = CreditCategory.objects.filter(shop=shop)
        self.assertGreaterEqual(credit_cats.count(), 6)

        # Check seeded default garment categories and items
        garment_cats = GarmentCategory.objects.filter(shop=shop)
        self.assertEqual(garment_cats.count(), 4)
        items = GarmentItem.objects.filter(shop=shop)
        self.assertEqual(items.count(), 16)

    def test_provision_new_shop_authenticated_attaches_owner(self):
        """Provisioning by an authenticated user attaches them as OWNER and sets default membership."""
        principal = resolve_principal(self.user.email)
        self.client.force_authenticate(user=principal)

        payload = {
            'name': 'Elite Dry Cleaners',
            'phone': '+91 99887 76655',
            'owner_name': 'Meera Verma',
            'order_prefix': 'ELIT',
        }
        res = self.client.post('/api/shops/provision/', payload, format='json')
        self.assertEqual(res.status_code, 201)
        data = res.json()

        shop = Shop.objects.get(id=data['id'])
        self.assertEqual(shop.order_prefix, 'ELIT')

        # Check membership created
        membership = ShopMembership.objects.filter(user=self.user, shop=shop).first()
        self.assertIsNotNone(membership)
        self.assertEqual(membership.role, ShopRole.OWNER)
        self.assertTrue(membership.is_default)

        # Principal in shop context resolves to OWNER
        p = resolve_principal(self.user.email, shop=shop)
        self.assertEqual(p.role, OWNER)
