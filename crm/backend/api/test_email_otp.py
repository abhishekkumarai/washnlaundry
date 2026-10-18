"""KAN-216: email one-time-code sign-in (api/otp.py)."""
import re
from datetime import timedelta
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from . import otp
from .models import EmailOtp


@override_settings(PASSWORD_AUTH_ENABLED=True, API_AUTH_ENFORCED=True, OTP_SENDER='email')
class EmailOtpTests(APITestCase):
    def setUp(self):
        cache.clear()
        self.sent = []
        patcher = mock.patch('api.password_auth.EmailService.send',
                             side_effect=lambda to, subject, text: self.sent.append((to, text)) or (True, None))
        patcher.start()
        self.addCleanup(patcher.stop)

    def request_code(self, email='neha@example.com'):
        res = self.client.post('/api/auth/email-code/request/', {'email': email}, format='json')
        self.assertEqual(res.status_code, 200, res.content)
        return re.search(r'\b(\d{6})\b', self.sent[-1][1]).group(1)

    def verify(self, code, email='neha@example.com'):
        return self.client.post('/api/auth/email-code/verify/', {'email': email, 'code': code},
                                format='json')

    def test_code_signs_in_and_creates_an_account(self):
        code = self.request_code('Neha@Example.com')
        self.assertEqual(self.sent[-1][0], 'neha@example.com')
        self.assertNotIn(code, EmailOtp.objects.get().code_hash)  # only a hash is stored
        res = self.verify(code)
        self.assertEqual(res.status_code, 200, res.content)
        token = res.json()['token']
        self.assertTrue(token.startswith('app.'))
        user = get_user_model().objects.get(username='neha@example.com')
        self.assertTrue(user.is_active)
        self.assertFalse(user.has_usable_password())
        me = self.client.get('/api/me/', HTTP_AUTHORIZATION=f'Bearer {token}')
        self.assertEqual((me.status_code, me.json()['email']), (200, 'neha@example.com'))
        self.assertEqual(self.verify(code).status_code, 400)  # single use

    def test_wrong_codes_burn_the_code_after_max_attempts(self):
        code = self.request_code()
        wrong = f'{(int(code) + 1) % 1000000:06d}'
        for _ in range(otp.MAX_ATTEMPTS):
            self.assertEqual(self.verify(wrong).status_code, 400)
        self.assertEqual(self.verify(code).status_code, 400)

    def test_expired_and_superseded_codes_fail(self):
        first = self.request_code()
        second = self.request_code()
        if first != second:
            self.assertEqual(self.verify(first).status_code, 400)
        EmailOtp.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.verify(second).status_code, 400)

    def test_requests_are_rate_limited(self):
        for _ in range(5):
            self.request_code()
        res = self.client.post('/api/auth/email-code/request/', {'email': 'neha@example.com'}, format='json')
        self.assertEqual(res.status_code, 429)

    def test_unverified_password_signup_loses_its_password_when_the_code_activates_it(self):
        squatter = get_user_model().objects.create_user(
            username='neha@example.com', email='neha@example.com', password='Squatter#2026', is_active=False)
        self.assertEqual(self.verify(self.request_code()).status_code, 200)
        squatter.refresh_from_db()
        self.assertTrue(squatter.is_active)
        self.assertFalse(squatter.check_password('Squatter#2026'))

    def test_bad_input_and_disabled(self):
        self.assertEqual(self.client.post('/api/auth/email-code/request/', {'email': 'nope'},
                                          format='json').status_code, 400)
        self.assertEqual(self.verify('12').status_code, 400)
        with override_settings(PASSWORD_AUTH_ENABLED=False):
            self.assertEqual(self.client.post('/api/auth/email-code/request/', {'email': 'a@b.co'},
                                              format='json').status_code, 503)

    @override_settings(DEBUG=True, DEV_LOGIN_CODE='424242', DEV_LOGIN_EMAILS={'tester@example.com'})
    def test_dev_login_code_signs_in_listed_test_emails_locally(self):
        self.assertEqual(self.verify('424242', 'Tester@example.com').status_code, 200)
        # Not for anyone else, and a wrong code still fails.
        self.assertEqual(self.verify('424242', 'neha@example.com').status_code, 400)
        self.assertEqual(self.verify('111111', 'tester@example.com').status_code, 400)

    @override_settings(DEBUG=False, DEV_LOGIN_CODE='424242', DEV_LOGIN_EMAILS={'tester@example.com'})
    def test_dev_login_code_is_dead_without_debug(self):
        self.assertEqual(self.verify('424242', 'tester@example.com').status_code, 400)
