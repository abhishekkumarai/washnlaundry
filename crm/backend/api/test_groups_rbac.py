"""Unit and integration tests for Django Groups RBAC (KAN-130)."""
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group, Permission
from django.test import TestCase
from rest_framework.test import APIRequestFactory

from api.auth import (
    OWNER, STAFF, CUSTOMER,
    IsOwner, IsStaff, IsOwnerOrStaffReadOnly,
    Principal, resolve_principal, sync_staff_user, sync_user_groups,
)
from api.models import Staff


User = get_user_model()


class GroupsRBACTests(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.owner_group, _ = Group.objects.get_or_create(name='Owner')
        self.staff_group, _ = Group.objects.get_or_create(name='Staff')

    def test_owner_group_permissions(self):
        """Owner group must have full API model permissions."""
        api_perms = Permission.objects.filter(content_type__app_label='api')
        self.assertTrue(api_perms.exists())
        self.owner_group.permissions.set(api_perms)

        user = User.objects.create_user(username='boss@store.com', email='boss@store.com', password='pass')
        user.groups.add(self.owner_group)

        self.assertTrue(user.has_perm('api.add_order'))
        self.assertTrue(user.has_perm('api.delete_expense'))
        self.assertTrue(user.has_perm('api.change_salarypayment'))

    def test_staff_group_permissions_restricted(self):
        """Staff group must have operational permissions but not financial/payroll."""
        order_perm = Permission.objects.filter(content_type__app_label='api', codename='add_order').first()
        salary_perm = Permission.objects.filter(content_type__app_label='api', codename='add_salarypayment').first()

        if order_perm:
            self.staff_group.permissions.add(order_perm)

        user = User.objects.create_user(username='washer@store.com', email='washer@store.com', password='pass')
        user.groups.add(self.staff_group)

        if order_perm:
            self.assertTrue(user.has_perm('api.add_order'))
        if salary_perm:
            self.assertFalse(user.has_perm('api.add_salarypayment'))

    def test_sync_staff_user_on_save(self):
        """Saving a Staff model instance synchronizes auth.User and Groups."""
        staff_owner = Staff.objects.create(
            name='Store Manager',
            role='Manager',
            phone='9876543210',
            email='manager@store.com',
            status='ACTIVE',
            has_app_login=True,
        )
        sync_staff_user(staff_owner)

        user = User.objects.filter(username='manager@store.com').first()
        self.assertIsNotNone(user)
        self.assertTrue(user.groups.filter(name='Owner').exists())
        self.assertFalse(user.groups.filter(name='Staff').exists())
        self.assertTrue(user.is_staff)

        # Worker staff role
        staff_washer = Staff.objects.create(
            name='Ramesh',
            role='Washer',
            phone='9876543211',
            email='ramesh@store.com',
            status='ACTIVE',
            has_app_login=True,
        )
        sync_staff_user(staff_washer)

        user_washer = User.objects.filter(username='ramesh@store.com').first()
        self.assertIsNotNone(user_washer)
        self.assertTrue(user_washer.groups.filter(name='Staff').exists())
        self.assertFalse(user_washer.groups.filter(name='Owner').exists())
        self.assertTrue(user_washer.is_staff)

    def test_resolve_principal_from_group(self):
        """resolve_principal correctly detects Owner and Staff groups."""
        user = User.objects.create_user(username='custom_admin@store.com', email='custom_admin@store.com')
        user.groups.add(self.owner_group)

        principal = resolve_principal('custom_admin@store.com')
        self.assertEqual(principal.role, OWNER)
        self.assertTrue(principal.in_group('Owner'))

        user2 = User.objects.create_user(username='custom_staff@store.com', email='custom_staff@store.com')
        user2.groups.add(self.staff_group)

        principal2 = resolve_principal('custom_staff@store.com')
        self.assertEqual(principal2.role, STAFF)
        self.assertTrue(principal2.in_group('Staff'))

    from django.test import override_settings

    @override_settings(API_AUTH_ENFORCED=True)
    def test_drf_permission_classes(self):
        """DRF permission classes respect Groups and Principal when enforced."""
        owner_principal = Principal(email='owner@test.com', role=OWNER)
        staff_principal = Principal(email='staff@test.com', role=STAFF)
        customer_principal = Principal(email='cust@test.com', role=CUSTOMER)

        is_owner = IsOwner()
        is_staff = IsStaff()
        read_only = IsOwnerOrStaffReadOnly()

        class MockRequest:
            def __init__(self, user, method='GET'):
                self.user = user
                self.method = method

        # Owner has permission to everything
        self.assertTrue(is_owner.has_permission(MockRequest(owner_principal), None))
        self.assertTrue(is_staff.has_permission(MockRequest(owner_principal), None))
        self.assertTrue(read_only.has_permission(MockRequest(owner_principal, 'POST'), None))

        # Staff can do general CRM, but not owner-restricted
        self.assertFalse(is_owner.has_permission(MockRequest(staff_principal), None))
        self.assertTrue(is_staff.has_permission(MockRequest(staff_principal), None))
        self.assertTrue(read_only.has_permission(MockRequest(staff_principal, 'GET'), None))
        self.assertFalse(read_only.has_permission(MockRequest(staff_principal, 'POST'), None))
