"""Unit and integration tests for Multi-Tenant RBAC & Shop-Scoped Memberships (KAN-135)."""
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.test import TestCase, override_settings
from rest_framework.test import APIClient, APIRequestFactory

from api.auth import (
    OWNER, STAFF, CUSTOMER, UNLINKED,
    IsOwner, IsStaff,
    Principal, resolve_principal, sync_staff_user,
)
from api.models import Shop, Staff, ShopMembership, ShopRole
from api.tenancy import tenant_context

User = get_user_model()


class TenantRBACTests(TestCase):
    def setUp(self):
        self.shop_a = Shop.objects.create(name='Shop Alpha', slug='shop-alpha', subdomain='alpha')
        self.shop_b = Shop.objects.create(name='Shop Beta', slug='shop-beta', subdomain='beta')
        self.owner_group, _ = Group.objects.get_or_create(name='Owner')
        self.staff_group, _ = Group.objects.get_or_create(name='Staff')

    def test_sync_staff_user_creates_shop_membership(self):
        """Saving or syncing a staff member attaches ShopMembership for their specific shop."""
        staff_owner = Staff.objects.create(
            shop=self.shop_a,
            name='Alpha Manager',
            role='Manager',
            phone='9999900001',
            email='alpha_mgr@example.com',
            status='ACTIVE',
            has_app_login=True,
        )
        sync_staff_user(staff_owner)

        user = User.objects.get(username='alpha_mgr@example.com')
        membership = ShopMembership.objects.filter(user=user, shop=self.shop_a).first()
        self.assertIsNotNone(membership)
        self.assertEqual(membership.role, ShopRole.OWNER)

        staff_worker = Staff.objects.create(
            shop=self.shop_a,
            name='Alpha Washer',
            role='Washer',
            phone='9999900002',
            email='alpha_washer@example.com',
            status='ACTIVE',
            has_app_login=True,
        )
        sync_staff_user(staff_worker)

        user_worker = User.objects.get(username='alpha_washer@example.com')
        membership_worker = ShopMembership.objects.filter(user=user_worker, shop=self.shop_a).first()
        self.assertIsNotNone(membership_worker)
        self.assertEqual(membership_worker.role, ShopRole.STAFF)

    @override_settings(API_AUTH_ENFORCED=True)
    def test_multi_tenant_role_differentiation(self):
        """A user can be OWNER of Shop A and STAFF in Shop B."""
        user = User.objects.create_user(
            username='hybrid_user@example.com',
            email='hybrid_user@example.com',
            password='password123',
        )

        ShopMembership.objects.create(
            user=user,
            shop=self.shop_a,
            role=ShopRole.OWNER,
            is_active=True,
        )
        ShopMembership.objects.create(
            user=user,
            shop=self.shop_b,
            role=ShopRole.STAFF,
            is_active=True,
        )

        # Context: Shop A -> role is OWNER
        principal_a = resolve_principal(user.email, shop=self.shop_a)
        self.assertEqual(principal_a.role, OWNER)
        self.assertTrue(principal_a.has_role(OWNER))
        self.assertTrue(IsOwner().has_permission(type('Req', (), {'user': principal_a})(), None))

        # Context: Shop B -> role is STAFF
        principal_b = resolve_principal(user.email, shop=self.shop_b)
        self.assertEqual(principal_b.role, STAFF)
        self.assertFalse(principal_b.has_role(OWNER))
        self.assertTrue(principal_b.has_role(STAFF))
        # Owner check fails in Shop B
        self.assertFalse(IsOwner().has_permission(type('Req', (), {'user': principal_b})(), None))

    def test_inactive_membership_is_ignored(self):
        """Inactive memberships are not resolved."""
        user = User.objects.create_user(
            username='inactive_staff@example.com',
            email='inactive_staff@example.com',
        )
        ShopMembership.objects.create(
            user=user,
            shop=self.shop_a,
            role=ShopRole.OWNER,
            is_active=False,
        )

        principal = resolve_principal(user.email, shop=self.shop_a)
        self.assertNotEqual(principal.role, OWNER)

    def test_superuser_and_staff_emails_remain_global_owner(self):
        """Superusers and explicit STAFF_EMAILS retain OWNER across all shops."""
        superuser = User.objects.create_superuser(
            username='super@example.com',
            email='super@example.com',
            password='password',
        )
        p_a = resolve_principal(superuser.email, shop=self.shop_a)
        p_b = resolve_principal(superuser.email, shop=self.shop_b)
        self.assertEqual(p_a.role, OWNER)
        self.assertEqual(p_b.role, OWNER)

    def test_me_endpoint_returns_shop_context_and_memberships(self):
        """GET /api/me/ includes active shop and list of user memberships."""
        user = User.objects.create_user(
            username='portal_user@example.com',
            email='portal_user@example.com',
        )
        ShopMembership.objects.create(
            user=user,
            shop=self.shop_a,
            role=ShopRole.OWNER,
            is_default=True,
        )
        ShopMembership.objects.create(
            user=user,
            shop=self.shop_b,
            role=ShopRole.STAFF,
            is_default=False,
        )

        client = APIClient()
        principal = resolve_principal(user.email, shop=self.shop_a)
        client.force_authenticate(user=principal)

        resp = client.get('/api/me/', HTTP_X_TENANT_ID=self.shop_a.slug)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        self.assertEqual(data['role'], OWNER)
        self.assertEqual(data['email'], user.email)
        self.assertEqual(data['shop']['slug'], self.shop_a.slug)
        self.assertEqual(len(data['shops']), 2)
        slugs = {s['slug'] for s in data['shops']}
        self.assertIn(self.shop_a.slug, slugs)
        self.assertIn(self.shop_b.slug, slugs)
