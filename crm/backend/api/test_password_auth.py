import re
from unittest import mock

from django.core.cache import cache
from django.test import Client, override_settings
from rest_framework.test import APITestCase

from .models import Customer


@override_settings(PASSWORD_AUTH_ENABLED=True, GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True,
                   STAFF_EMAILS=['owner@shop.com'],
                   APP_ORIGINS=['https://customer.washnlaundry.com'],
                   APP_BASE_URL='https://customer.washnlaundry.com')
class PasswordAuthTests(APITestCase):
    """Email + password sign-in: verification, login, reset, rate limits, roles."""

    def setUp(self):
        cache.clear()
        self.sent = []

        def fake_send(to, subject, text):
            self.sent.append((to, subject, text))
            return True, None

        patcher = mock.patch('api.password_auth.EmailService.send', side_effect=fake_send)
        patcher.start()
        self.addCleanup(patcher.stop)

    def post(self, path, body):
        return self.client.post(f'/api/auth/{path}/', body, format='json')

    def link_token(self):
        return re.search(r'token=([^\s]+)', self.sent[-1][2]).group(1)

    def bearer(self, token):
        return {'HTTP_AUTHORIZATION': f'Bearer {token}'}

    def signup_and_verify(self, email='cust@example.com', password='correct horse'):
        self.assertEqual(self.post('signup', {'email': email, 'password': password}).status_code, 201)
        res = self.post('verify-email', {'token': self.link_token()})
        self.assertEqual(res.status_code, 200)
        return res.json()['token']

    def test_signup_requires_verification_before_login(self):
        res = self.post('signup', {'email': 'Cust@Example.com', 'password': 'correct horse'})
        self.assertEqual(res.status_code, 201)
        self.assertEqual(self.sent[-1][0], 'cust@example.com')
        self.assertIn('https://customer.washnlaundry.com/verify?token=', self.sent[-1][2])
        res = self.post('login', {'email': 'cust@example.com', 'password': 'correct horse'})
        self.assertEqual(res.status_code, 403)

    def test_verify_then_login_and_token_works_on_the_api(self):
        Customer.objects.create(name='Cu', phone='9000000010', email='cust@example.com')
        token = self.signup_and_verify()
        me = self.client.get('/api/me/', **self.bearer(token)).json()
        self.assertEqual((me['role'], me['email']), ('customer', 'cust@example.com'))
        res = self.post('login', {'email': 'CUST@example.com', 'password': 'correct horse'})
        self.assertEqual(res.status_code, 200)
        orders = self.client.get('/api/customer/orders/', **self.bearer(res.json()['token']))
        self.assertEqual(orders.status_code, 200)

    def test_unverified_email_never_gets_a_role(self):
        # Squatting on the owner's address must not make anyone owner.
        self.post('signup', {'email': 'owner@shop.com', 'password': 'attacker pass'})
        res = self.post('login', {'email': 'owner@shop.com', 'password': 'attacker pass'})
        self.assertEqual(res.status_code, 403)
        # And a forged token is rejected.
        self.assertEqual(self.client.get('/api/orders/', **self.bearer('app.forged')).status_code, 401)

    def test_verified_owner_email_is_owner(self):
        token = self.signup_and_verify('owner@shop.com')
        self.assertEqual(self.client.get('/api/me/', **self.bearer(token)).json()['role'], 'owner')
        self.assertEqual(self.client.get('/api/orders/', **self.bearer(token)).status_code, 200)

    def test_wrong_password_and_unknown_user_look_identical(self):
        self.signup_and_verify()
        a = self.post('login', {'email': 'cust@example.com', 'password': 'wrong password'})
        b = self.post('login', {'email': 'nobody@example.com', 'password': 'wrong password'})
        self.assertEqual((a.status_code, a.json()), (b.status_code, b.json()))
        self.assertEqual(a.status_code, 401)

    def test_login_locks_after_repeated_failures_but_successes_do_not_count(self):
        self.signup_and_verify()
        for _ in range(10):
            ok = self.post('login', {'email': 'cust@example.com', 'password': 'correct horse'})
            self.assertEqual(ok.status_code, 200)
        for _ in range(8):
            self.post('login', {'email': 'cust@example.com', 'password': 'wrong password'})
        res = self.post('login', {'email': 'cust@example.com', 'password': 'correct horse'})
        self.assertEqual(res.status_code, 429)

    def test_password_rules(self):
        self.assertEqual(self.post('signup', {'email': 'a@b.com', 'password': 'short'}).status_code, 400)
        res = self.post('signup', {'email': 'not-an-email', 'password': 'long enough pw'})
        self.assertEqual(res.status_code, 400)

    def test_existing_account_signup_does_not_reveal_or_change_it(self):
        self.signup_and_verify()
        res = self.post('signup', {'email': 'cust@example.com', 'password': 'attacker pass'})
        self.assertEqual(res.status_code, 201)
        self.assertIn('already have', self.sent[-1][1])
        ok = self.post('login', {'email': 'cust@example.com', 'password': 'correct horse'})
        self.assertEqual(ok.status_code, 200)
        bad = self.post('login', {'email': 'cust@example.com', 'password': 'attacker pass'})
        self.assertEqual(bad.status_code, 401)

    def test_bad_verify_token(self):
        self.assertEqual(self.post('verify-email', {'token': 'junk'}).status_code, 400)

    def test_forgot_and_reset_flow_is_single_use_and_signs_out_old_sessions(self):
        old = self.signup_and_verify()
        self.assertEqual(self.post('forgot-password', {'email': 'cust@example.com'}).status_code, 200)
        self.assertIn('/reset?token=', self.sent[-1][2])
        token = self.link_token()
        res = self.post('reset-password', {'token': token, 'password': 'brand new pass'})
        self.assertEqual(res.status_code, 200)
        again = self.post('reset-password', {'token': token, 'password': 'another one!!'})
        self.assertEqual(again.status_code, 400)
        new = self.post('login', {'email': 'cust@example.com', 'password': 'brand new pass'})
        self.assertEqual(new.status_code, 200)
        stale = self.post('login', {'email': 'cust@example.com', 'password': 'correct horse'})
        self.assertEqual(stale.status_code, 401)
        self.assertEqual(self.client.get('/api/me/', **self.bearer(old)).status_code, 401)

    def test_forgot_password_does_not_reveal_unknown_emails(self):
        before = len(self.sent)
        res = self.post('forgot-password', {'email': 'ghost@example.com'})
        self.assertEqual((res.status_code, res.json()), (200, {'ok': True}))
        self.assertEqual(len(self.sent), before)

    def test_disabled_on_the_default_secret_key(self):
        with override_settings(PASSWORD_AUTH_ENABLED=False):
            res = self.post('signup', {'email': 'a@b.com', 'password': 'long enough pw'})
            self.assertEqual(res.status_code, 503)
            self.assertEqual(self.client.get('/api/me/', **self.bearer('app.x')).status_code, 401)

    def test_link_origin_is_allow_listed(self):
        self.client.post('/api/auth/signup/', {'email': 'a@b.com', 'password': 'long enough pw',
                                               'return_to': 'https://evil.example'}, format='json')
        self.assertIn('https://customer.washnlaundry.com/verify', self.sent[-1][2])
        self.assertNotIn('evil.example', self.sent[-1][2])

    def test_link_goes_back_to_the_callers_own_site(self):
        with override_settings(APP_ORIGINS=['https://app.washnlaundry.com',
                                            'https://customer.washnlaundry.com']):
            self.client.post('/api/auth/signup/', {'email': 'a@b.com', 'password': 'long enough pw'},
                             format='json', HTTP_ORIGIN='https://app.washnlaundry.com')
            self.assertIn('https://app.washnlaundry.com/verify?token=', self.sent[-1][2])

    def test_link_falls_back_to_app_base_url_without_an_allowed_origin(self):
        with override_settings(APP_BASE_URL='https://customer.washnlaundry.com/'):
            self.client.post('/api/auth/signup/', {'email': 'a@b.com', 'password': 'long enough pw'},
                             format='json')
            self.assertIn('https://customer.washnlaundry.com/verify?token=', self.sent[-1][2])
            self.assertNotIn('.com//verify', self.sent[-1][2])

    @override_settings(DEBUG=True)
    def test_localhost_origin_is_accepted_only_in_debug(self):
        self.client.post('/api/auth/signup/', {'email': 'a@b.com', 'password': 'long enough pw'},
                         format='json', HTTP_ORIGIN='http://localhost:5055')
        self.assertIn('http://localhost:5055/verify?token=', self.sent[-1][2])
        with override_settings(DEBUG=False):
            self.client.post('/api/auth/signup/', {'email': 'c@d.com', 'password': 'long enough pw'},
                             format='json', HTTP_ORIGIN='http://localhost:5055')
            self.assertNotIn('localhost', self.sent[-1][2])

    def test_works_without_a_csrf_token(self):
        res = Client(enforce_csrf_checks=True).post(
            '/api/auth/signup/', {'email': 'c@d.com', 'password': 'long enough pw'},
            content_type='application/json')
        self.assertEqual(res.status_code, 201)
