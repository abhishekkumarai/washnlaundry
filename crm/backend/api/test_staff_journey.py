"""End-to-end: owner approves a staff sign-in, resets it, and the staff member recovers it.

Runs with API auth ENFORCED (as in production) and a real owner principal, unlike
the unit tests in test_staff_credentials.py which run with enforcement off.
"""
import re
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from api.models import Shop, ShopMembership, ShopRole, Staff

User = get_user_model()
PW1, PW2, PW3 = 'First-pass-1', 'Second-pass-2', 'Third-pass-3'


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True, PASSWORD_AUTH_ENABLED=True,
                   APP_ORIGINS=['https://app.washnlaundry.com'])
class StaffCredentialJourneyTests(TestCase):
    def setUp(self):
        cache.clear()
        self.shop = Shop.objects.create(name='Alpha', slug='alpha')
        self.other = Shop.objects.create(name='Beta', slug='beta')
        self.owner = User.objects.create_user('owner@x.com', 'owner@x.com', 'pw')
        ShopMembership.objects.create(user=self.owner, shop=self.shop, role=ShopRole.OWNER, is_default=True)
        self.other_owner = User.objects.create_user('boss@y.com', 'boss@y.com', 'pw')
        ShopMembership.objects.create(user=self.other_owner, shop=self.other, role=ShopRole.OWNER, is_default=True)
        patcher = mock.patch('api.auth.id_token.verify_oauth2_token')
        self.verify = patcher.start()
        self.addCleanup(patcher.stop)
        self.client = APIClient()
        self.sent = []
        mailer = mock.patch('api.password_auth.EmailService.send',
                            side_effect=lambda to, subject, text: (self.sent.append((to, text)) or (True, '')))
        mailer.start()
        self.addCleanup(mailer.stop)

    # helpers ---------------------------------------------------------------
    def as_owner(self, who='owner@x.com'):
        self.verify.return_value = {'email': who, 'email_verified': True}
        return {'HTTP_AUTHORIZATION': 'Bearer google', 'HTTP_X_TENANT_ID': 'alpha'}

    def as_staff(self, token):
        return {'HTTP_AUTHORIZATION': f'Bearer {token}', 'HTTP_X_TENANT_ID': 'alpha'}

    def login(self, email, password):
        return self.client.post('/api/auth/login/', {'email': email, 'password': password}, format='json')

    def new_staff(self):
        res = self.client.post('/api/staff/', {'name': 'Asha', 'phone': '9876543210', 'role': 'Washer'},
                               format='json', **self.as_owner())
        self.assertEqual(res.status_code, 201, res.content)
        return res.json()['id']

    def last_link_token(self):
        text = self.sent[-1][1]
        return re.search(r'token=([^\s]+)', text).group(1)

    # tests -----------------------------------------------------------------
    def test_owner_issues_staff_login_and_staff_gets_staff_access_only(self):
        sid = self.new_staff()
        res = self.client.post(f'/api/staff/{sid}/credentials/', {'email': 'Asha@X.com', 'password': PW1},
                               format='json', **self.as_owner())
        self.assertEqual(res.status_code, 200, res.content)
        self.assertTrue(res.json()['password_set'])

        login = self.login('asha@x.com', PW1)
        self.assertEqual(login.status_code, 200, login.content)
        auth = self.as_staff(login.json()['token'])

        me = self.client.get('/api/me/', **auth).json()
        self.assertEqual(me['role'], 'staff')
        self.assertEqual(self.client.get('/api/customers/', **auth).status_code, 200)
        # Owner-only areas stay closed to staff, including issuing logins to anyone.
        self.assertEqual(self.client.get('/api/staff/', **auth).status_code, 403)
        self.assertEqual(self.client.post(f'/api/staff/{sid}/credentials/', {'email': 'a@x.com', 'password': PW2},
                                          format='json', **auth).status_code, 403)

    def test_staff_cannot_use_the_login_in_another_shop(self):
        sid = self.new_staff()
        self.client.post(f'/api/staff/{sid}/credentials/', {'email': 'asha@x.com', 'password': PW1},
                         format='json', **self.as_owner())
        token = self.login('asha@x.com', PW1).json()['token']
        spoof = {'HTTP_AUTHORIZATION': f'Bearer {token}', 'HTTP_X_TENANT_ID': 'beta'}
        self.assertEqual(self.client.get('/api/customers/', **spoof).status_code, 403)

    def test_owner_reset_changes_the_password_and_kills_old_sessions(self):
        sid = self.new_staff()
        self.client.post(f'/api/staff/{sid}/credentials/', {'email': 'asha@x.com', 'password': PW1},
                         format='json', **self.as_owner())
        old_token = self.login('asha@x.com', PW1).json()['token']

        reset = self.client.post(f'/api/staff/{sid}/credentials/', {'email': 'asha@x.com', 'password': PW2},
                                 format='json', **self.as_owner())
        self.assertEqual(reset.status_code, 200, reset.content)
        self.assertTrue(reset.json()['password_set'])
        self.assertEqual(self.login('asha@x.com', PW1).status_code, 401)
        new = self.login('asha@x.com', PW2)
        self.assertEqual(new.status_code, 200)
        self.assertEqual(self.client.get('/api/me/', **self.as_staff(old_token)).status_code, 401)
        self.assertEqual(self.client.get('/api/me/', **self.as_staff(new.json()['token'])).status_code, 200)

    def test_owner_cannot_reset_a_staff_member_of_another_shop(self):
        sid = self.new_staff()
        foreign = self.client.post(f'/api/staff/{sid}/credentials/', {'email': 'x@x.com', 'password': PW1},
                                   format='json', **self.as_owner('boss@y.com'))
        self.assertIn(foreign.status_code, (403, 404))
        self.assertFalse(User.objects.filter(username='x@x.com').exists())

    def test_staff_recovers_a_forgotten_password_by_email_link(self):
        sid = self.new_staff()
        self.client.post(f'/api/staff/{sid}/credentials/', {'email': 'asha@x.com', 'password': PW1},
                         format='json', **self.as_owner())
        res = self.client.post('/api/auth/forgot-password/', {'email': 'asha@x.com'}, format='json',
                               HTTP_ORIGIN='https://app.washnlaundry.com')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(self.sent[-1][0], 'asha@x.com')
        self.assertIn('https://app.washnlaundry.com/reset?token=', self.sent[-1][1])
        token = self.last_link_token()

        done = self.client.post('/api/auth/reset-password/', {'token': token, 'password': PW3}, format='json')
        self.assertEqual(done.status_code, 200, done.content)
        self.assertEqual(self.login('asha@x.com', PW1).status_code, 401)
        self.assertEqual(self.login('asha@x.com', PW3).status_code, 200)
        # A reset link works once.
        again = self.client.post('/api/auth/reset-password/', {'token': token, 'password': 'Another-pass-4'},
                                 format='json')
        self.assertEqual(again.status_code, 400)
        # Unknown emails get the same answer and no email.
        before = len(self.sent)
        unknown = self.client.post('/api/auth/forgot-password/', {'email': 'nobody@x.com'}, format='json')
        self.assertEqual(unknown.status_code, 200)
        self.assertEqual(len(self.sent), before)

    def test_owner_approved_staff_sets_their_first_password_via_forgot_password(self):
        sid = self.new_staff()
        # Owner "approves" by setting the staff row's sign-in email (no password issued).
        patch = self.client.patch(f'/api/staff/{sid}/', {'email': 'ravi@x.com', 'has_app_login': True},
                                  format='json', **self.as_owner())
        self.assertEqual(patch.status_code, 200, patch.content)
        # Signing up with that email must not let anyone overwrite the approved account.
        signup = self.client.post('/api/auth/signup/', {'email': 'ravi@x.com', 'password': PW1, 'name': 'Ravi',
                                                        'phone': '9876543210'}, format='json',
                                  HTTP_ORIGIN='https://app.washnlaundry.com')
        self.assertEqual(signup.status_code, 201, signup.content)
        self.assertIn('already have', self.sent[-1][1])
        self.assertEqual(self.login('ravi@x.com', PW1).status_code, 401)

        # The mailbox owner sets a password through the recovery link and is staff.
        self.client.post('/api/auth/forgot-password/', {'email': 'ravi@x.com'}, format='json',
                         HTTP_ORIGIN='https://app.washnlaundry.com')
        done = self.client.post('/api/auth/reset-password/', {'token': self.last_link_token(), 'password': PW2},
                                format='json')
        self.assertEqual(done.status_code, 200, done.content)
        me = self.client.get('/api/me/', **self.as_staff(done.json()['token'])).json()
        self.assertEqual(me['role'], 'staff')

    def test_an_unapproved_signup_gets_no_staff_access(self):
        self.new_staff()
        signup = self.client.post('/api/auth/signup/', {'email': 'rando@x.com', 'password': PW1, 'name': 'R',
                                                        'phone': '9000000009'}, format='json',
                                  HTTP_ORIGIN='https://app.washnlaundry.com')
        self.assertEqual(signup.status_code, 201, signup.content)
        verified = self.client.post('/api/auth/verify-email/', {'token': self.last_link_token()}, format='json')
        self.assertEqual(verified.status_code, 200, verified.content)  # no 500 with several shops
        token = verified.json()['token']
        self.assertEqual(self.client.get('/api/customers/', **self.as_staff(token)).status_code, 403)

    def test_revoking_removes_access_to_the_shop(self):
        sid = self.new_staff()
        self.client.post(f'/api/staff/{sid}/credentials/', {'email': 'asha@x.com', 'password': PW1},
                         format='json', **self.as_owner())
        token = self.login('asha@x.com', PW1).json()['token']
        self.assertEqual(self.client.get('/api/customers/', **self.as_staff(token)).status_code, 200)
        res = self.client.delete(f'/api/staff/{sid}/credentials/', **self.as_owner())
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(self.client.get('/api/customers/', **self.as_staff(token)).status_code, 403)
