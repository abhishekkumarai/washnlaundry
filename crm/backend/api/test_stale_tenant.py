"""A stale X-Tenant-ID (deleted demo sandbox, archived shop) must never block signing in."""
import re
from unittest import mock

from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from api.models import Shop

STALE = {'HTTP_X_TENANT_ID': 'demo-deadbeef00'}


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True, PASSWORD_AUTH_ENABLED=True,
                   APP_ORIGINS=['https://app.washnlaundry.com'])
class StaleTenantHeaderTests(TestCase):
    def setUp(self):
        cache.clear()
        Shop.objects.create(name='Alpha', slug='alpha')
        self.client = APIClient()
        self.sent = []
        mailer = mock.patch('api.password_auth.EmailService.send',
                            side_effect=lambda to, subject, text: (self.sent.append((to, text)) or (True, '')))
        mailer.start()
        self.addCleanup(mailer.stop)

    def link_token(self):
        return re.search(r'token=([^\s]+)', self.sent[-1][1]).group(1)

    def test_signup_confirm_and_sign_in_work_with_a_stale_shop_header(self):
        signup = self.client.post('/api/auth/signup/', {'email': 'new@x.com', 'password': 'Brand-new-1', 'name': 'N',
                                                       'phone': '9123456780'}, format='json',
                                  HTTP_ORIGIN='https://app.washnlaundry.com', **STALE)
        self.assertEqual(signup.status_code, 201, signup.content)

        verified = self.client.post('/api/auth/verify-email/', {'token': self.link_token()}, format='json', **STALE)
        self.assertEqual(verified.status_code, 200, verified.content)

        login = self.client.post('/api/auth/login/', {'email': 'new@x.com', 'password': 'Brand-new-1'},
                                 format='json', **STALE)
        self.assertEqual(login.status_code, 200, login.content)

        me = self.client.get('/api/me/', HTTP_AUTHORIZATION=f"Bearer {login.json()['token']}", **STALE)
        self.assertEqual(me.status_code, 200, me.content)

    def test_password_reset_works_with_a_stale_shop_header(self):
        self.client.post('/api/auth/signup/', {'email': 'new@x.com', 'password': 'Brand-new-1', 'name': 'N',
                                               'phone': '9123456780'}, format='json')
        self.client.post('/api/auth/verify-email/', {'token': self.link_token()}, format='json')
        self.client.post('/api/auth/forgot-password/', {'email': 'new@x.com'}, format='json', **STALE)
        done = self.client.post('/api/auth/reset-password/', {'token': self.link_token(), 'password': 'Another-pass-2'},
                                format='json', **STALE)
        self.assertEqual(done.status_code, 200, done.content)

    def test_an_archived_shop_header_does_not_block_sign_in_either(self):
        Shop.objects.filter(slug='alpha').update(status='ARCHIVED')
        res = self.client.post('/api/auth/login/', {'email': 'nobody@x.com', 'password': 'whatever-1'},
                               format='json', HTTP_X_TENANT_ID='alpha')
        self.assertEqual(res.status_code, 401)  # wrong credentials, not 403 "shop archived"

    def test_shop_scoped_endpoints_still_reject_an_unknown_shop(self):
        res = self.client.get('/api/customers/', **STALE)
        self.assertEqual(res.status_code, 404)

    def test_a_confirmed_signup_with_no_store_record_can_sign_in_but_is_unlinked(self):
        from api.models import Customer, EmailLinkRequest
        Customer.all_objects.create(shop=Shop.objects.get(slug='alpha'), name='Existing', phone='9123456780')
        self.client.post('/api/auth/signup/', {'email': 'wait@x.com', 'password': 'Brand-new-1', 'name': 'W',
                                               'phone': '9123456780'}, format='json')
        verified = self.client.post('/api/auth/verify-email/', {'token': self.link_token()}, format='json')
        self.assertEqual(verified.status_code, 200)
        login = self.client.post('/api/auth/login/', {'email': 'wait@x.com', 'password': 'Brand-new-1'}, format='json')
        self.assertEqual(login.status_code, 200)
        me = self.client.get('/api/me/', HTTP_AUTHORIZATION=f"Bearer {login.json()['token']}")
        self.assertEqual(me.status_code, 200, me.content)  # used to be a 500
        self.assertEqual(me.json()['role'], 'unlinked')
        # Customer self-registration is off: no link request is queued for the store.
        self.assertFalse(me.json()['pending_link'])
        self.assertFalse(EmailLinkRequest.objects.exists())
        self.assertFalse(Customer.all_objects.filter(email='wait@x.com').exists())
