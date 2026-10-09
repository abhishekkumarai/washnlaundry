from django.contrib.auth.models import User
from django.db import IntegrityError
from django.test import TestCase

from .models import (
    Customer,
    CreditCategory,
    Order,
    Shop,
    ShopMembership,
    ShopRole,
    ShopOrderSequence,
)
from .tenancy import get_current_tenant, tenant_context


class MultiTenantSchemaTests(TestCase):
    def setUp(self):
        self.shop1 = Shop.objects.create(name='Shop Alpha', order_prefix='ALP')
        self.shop2 = Shop.objects.create(name='Shop Beta', order_prefix='BET')

    def test_shop_slug_and_subdomain_auto_derived(self):
        """Shop save() auto-derives slug and subdomain from name."""
        self.assertEqual(self.shop1.slug, 'shop-alpha')
        self.assertEqual(self.shop1.subdomain, 'shop-alpha')
        self.assertEqual(self.shop2.slug, 'shop-beta')
        self.assertEqual(self.shop2.subdomain, 'shop-beta')

    def test_customer_composite_phone_uniqueness(self):
        """Customers across different shops can share the same phone number.
        Within the same shop, phone numbers must be unique."""
        c1 = Customer.objects.create(shop=self.shop1, name='Alice', phone='9876543210')
        self.assertEqual(c1.shop, self.shop1)

        # Same phone in shop2 must succeed
        c2 = Customer.objects.create(shop=self.shop2, name='Alice in Beta', phone='9876543210')
        self.assertEqual(c2.shop, self.shop2)

        # Duplicate phone in shop1 must fail
        with self.assertRaises(IntegrityError):
            Customer.objects.create(shop=self.shop1, name='Alice Duplicate', phone='9876543210')

    def test_order_number_per_shop_sequence(self):
        """Order numbers are strictly scoped and sequentially generated per shop."""
        o1 = Order.objects.create(shop=self.shop1, customer_name='C1')
        o2 = Order.objects.create(shop=self.shop1, customer_name='C2')
        self.assertEqual(o1.order_number, 'ALP-00001')
        self.assertEqual(o2.order_number, 'ALP-00002')

        # Shop 2 starts its own sequence from 1
        o3 = Order.objects.create(shop=self.shop2, customer_name='C3')
        self.assertEqual(o3.order_number, 'BET-00001')

    def test_credit_category_composite_uniqueness(self):
        """CreditCategory names are unique per shop, but can duplicate across shops."""
        cat1 = CreditCategory.objects.create(shop=self.shop1, name='Special Income')
        self.assertEqual(cat1.shop, self.shop1)

        cat2 = CreditCategory.objects.create(shop=self.shop2, name='Special Income')
        self.assertEqual(cat2.shop, self.shop2)

        with self.assertRaises(IntegrityError):
            CreditCategory.objects.create(shop=self.shop1, name='Special Income')

    def test_tenant_context_manager(self):
        """tenant_context sets get_current_tenant() and safely restores it upon exit."""
        self.assertIsNone(get_current_tenant())
        with tenant_context(self.shop1):
            self.assertEqual(get_current_tenant(), self.shop1)
            with tenant_context(self.shop2):
                self.assertEqual(get_current_tenant(), self.shop2)
            self.assertEqual(get_current_tenant(), self.shop1)
        self.assertIsNone(get_current_tenant())

    def test_tenant_model_auto_assignment_from_context(self):
        """Models inheriting TenantModel automatically assign shop from active context."""
        with tenant_context(self.shop2):
            cust = Customer.objects.create(name='Context Customer', phone='9123456789')
            self.assertEqual(cust.shop, self.shop2)

    def test_shop_membership_multi_store_user(self):
        """A user can hold distinct roles across multiple shops."""
        user = User.objects.create_user(username='multi@example.com', email='multi@example.com')
        m1 = ShopMembership.objects.create(user=user, shop=self.shop1, role=ShopRole.OWNER, is_default=True)
        m2 = ShopMembership.objects.create(user=user, shop=self.shop2, role=ShopRole.STAFF)

        self.assertEqual(user.shop_memberships.count(), 2)
        self.assertEqual(m1.role, ShopRole.OWNER)
        self.assertEqual(m2.role, ShopRole.STAFF)

        # Duplicate membership in same shop must fail
        with self.assertRaises(IntegrityError):
            ShopMembership.objects.create(user=user, shop=self.shop1, role=ShopRole.CUSTOMER)
