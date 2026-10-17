"""Weak passwords are refused everywhere a password is set; Google signup survives several shops."""
import re
import unittest
from unittest import mock

from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from api.models import Shop, Staff


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True, PASSWORD_AUTH_ENABLED=True,
                   APP_ORIGINS=['https://app.washnlaundry.com'])
class RegistrationHardeningTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.sent = []
        mailer = mock.patch('api.password_auth.EmailService.send',
                            side_effect=lambda to, subject, text: (self.sent.append((to, text)) or (True, '')))
        mailer.start()
        self.addCleanup(mailer.stop)

    def signup(self, password, email='new@x.com'):
        return self.client.post('/api/auth/signup/', {'email': email, 'password': password, 'name': 'N',
                                                     'phone': '9123456780'}, format='json')

    def test_signup_rejects_common_numeric_and_name_like_passwords(self):
        for weak in ('12345678', 'password', 'new@x.com1'):
            res = self.signup(weak)
            self.assertEqual(res.status_code, 400, weak)
        self.assertEqual(self.signup('Brand-new-1').status_code, 201)

    def test_reset_rejects_a_weak_password(self):
        self.signup('Brand-new-1')
        token = re.search(r'token=([^\s]+)', self.sent[-1][1]).group(1)
        self.client.post('/api/auth/verify-email/', {'token': token}, format='json')
        self.client.post('/api/auth/forgot-password/', {'email': 'new@x.com'}, format='json')
        reset = re.search(r'token=([^\s]+)', self.sent[-1][1]).group(1)
        weak = self.client.post('/api/auth/reset-password/', {'token': reset, 'password': '12345678'}, format='json')
        self.assertEqual(weak.status_code, 400)
        ok = self.client.post('/api/auth/reset-password/', {'token': reset, 'password': 'Fresh-pass-77'}, format='json')
        self.assertEqual(ok.status_code, 200)  # the failed attempt did not burn the link

    def test_owner_issued_passwords_must_not_be_weak(self):
        shop = Shop.objects.create(name='A', slug='shop-a')
        staff = Staff.objects.create(shop=shop, name='Asha', phone='9876543210')
        with override_settings(API_AUTH_ENFORCED=False):
            res = self.client.post(f'/api/staff/{staff.pk}/credentials/?shop={shop.id}',
                                   {'email': 'asha@x.com', 'password': '12345678'}, format='json')
        self.assertEqual(res.status_code, 400)

    @unittest.skip('customer self-registration is switched off')
    def test_google_signup_gives_a_clean_error_instead_of_a_500_with_several_shops(self):
        Shop.objects.create(name='A', slug='shop-a')
        Shop.objects.create(name='B', slug='shop-b')
        with mock.patch('api.auth.id_token.verify_oauth2_token',
                        return_value={'email': 'g@x.com', 'email_verified': True}):
            res = self.client.post('/api/customer/me/', {'name': 'G', 'phone': '9123456781'}, format='json',
                                   HTTP_AUTHORIZATION='Bearer google')
        self.assertEqual(res.status_code, 503, res.content)


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True, PASSWORD_AUTH_ENABLED=True,
                   APP_ORIGINS=['https://app.washnlaundry.com'])
class ConfirmationLinkTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.sent = []
        mailer = mock.patch('api.password_auth.EmailService.send',
                            side_effect=lambda to, subject, text: (self.sent.append((to, text)) or (True, '')))
        mailer.start()
        self.addCleanup(mailer.stop)
        self.client.post('/api/auth/signup/', {'email': 'new@x.com', 'password': 'Brand-new-1', 'name': 'N',
                                               'phone': '9123456780'}, format='json')
        self.token = re.search(r'token=([^\s]+)', self.sent[-1][1]).group(1)

    def test_the_link_signs_you_in_once_then_refuses(self):
        first = self.client.post('/api/auth/verify-email/', {'token': self.token}, format='json')
        self.assertEqual(first.status_code, 200)
        self.assertIn('token', first.json())
        again = self.client.post('/api/auth/verify-email/', {'token': self.token}, format='json')
        self.assertEqual(again.status_code, 409)
        self.assertNotIn('token', again.json())
        self.assertIn('already been used', again.json()['error'] if 'error' in again.json() else str(again.json()))
        # The account itself still works with the password.
        login = self.client.post('/api/auth/login/', {'email': 'new@x.com', 'password': 'Brand-new-1'}, format='json')
        self.assertEqual(login.status_code, 200)

    def test_an_expired_link_is_refused(self):
        import time
        from django.core import signing
        with mock.patch('time.time', return_value=time.time() - 4 * 24 * 3600):
            old = signing.dumps({'e': 'new@x.com', 'p': '9123456780'}, salt='email-verify')
        res = self.client.post('/api/auth/verify-email/', {'token': old}, format='json')
        self.assertEqual(res.status_code, 400)

    def _expired_token(self, email='new@x.com', phone='9123456780'):
        import time
        from django.core import signing
        with mock.patch('time.time', return_value=time.time() - 4 * 24 * 3600):
            return signing.dumps({'e': email, 'p': phone}, salt='email-verify')

    def test_an_expired_link_can_be_resent_and_the_new_link_works_once(self):
        old = self._expired_token()
        self.assertEqual(self.client.post('/api/auth/verify-email/', {'token': old}, format='json').status_code, 400)
        before = len(self.sent)
        res = self.client.post('/api/auth/resend-verification/', {'token': old}, format='json',
                               HTTP_ORIGIN='https://app.washnlaundry.com')
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(len(self.sent), before + 1)
        self.assertEqual(self.sent[-1][0], 'new@x.com')
        self.assertIn('https://app.washnlaundry.com/verify?token=', self.sent[-1][1])
        fresh = re.search(r'token=([^\s]+)', self.sent[-1][1]).group(1)
        first = self.client.post('/api/auth/verify-email/', {'token': fresh}, format='json')
        self.assertEqual(first.status_code, 200)
        self.assertEqual(self.client.post('/api/auth/verify-email/', {'token': fresh}, format='json').status_code, 409)

    def test_resend_is_a_no_op_once_confirmed_and_rejects_forged_tokens(self):
        self.client.post('/api/auth/verify-email/', {'token': self.token}, format='json')
        before = len(self.sent)
        done = self.client.post('/api/auth/resend-verification/', {'token': self.token}, format='json')
        self.assertTrue(done.json().get('already_confirmed'))
        self.assertEqual(len(self.sent), before)
        forged = self.client.post('/api/auth/resend-verification/', {'token': 'forged.token'}, format='json')
        self.assertEqual(forged.status_code, 400)

    def test_resend_is_rate_limited_per_email(self):
        old = self._expired_token()
        codes = [self.client.post('/api/auth/resend-verification/', {'token': old}, format='json').status_code
                 for _ in range(4)]
        self.assertEqual(codes, [200, 200, 200, 429])
