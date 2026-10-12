"""KAN-190..196: secret masking, owner-only endpoints, client IP, RAG limits, customer edits."""
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import RequestFactory, TestCase, override_settings
from rest_framework.test import APIClient

from api.models import Customer, MetaSettings, Shop, ShopMembership, ShopRole
from api.netutils import client_ip

User = get_user_model()


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True)
class SecurityHardeningTests(TestCase):
    def setUp(self):
        cache.clear()
        self.shop = Shop.objects.create(name='Alpha Wash', slug='alpha')
        self.owner = User.objects.create_user('owner@x.com', 'owner@x.com', 'pw')
        self.staff = User.objects.create_user('staff@x.com', 'staff@x.com', 'pw')
        ShopMembership.objects.create(user=self.owner, shop=self.shop, role=ShopRole.OWNER, is_default=True)
        ShopMembership.objects.create(user=self.staff, shop=self.shop, role=ShopRole.STAFF, is_default=True)
        patcher = mock.patch('api.auth.id_token.verify_oauth2_token')
        self.verify = patcher.start()
        self.addCleanup(patcher.stop)
        self.client = APIClient()

    def as_(self, email):
        self.verify.return_value = {'email': email, 'email_verified': True}
        return {'HTTP_AUTHORIZATION': 'Bearer tok', 'HTTP_X_TENANT_ID': 'alpha'}

    # KAN-193
    def test_client_ip_ignores_spoofed_leftmost_forwarded_for(self):
        req = RequestFactory().get('/', HTTP_X_FORWARDED_FOR='1.2.3.4, 9.9.9.9', REMOTE_ADDR='10.0.0.1')
        self.assertEqual(client_ip(req), '9.9.9.9')
        req = RequestFactory().get('/', HTTP_CF_CONNECTING_IP='5.5.5.5', HTTP_X_FORWARDED_FOR='1.2.3.4')
        self.assertEqual(client_ip(req), '5.5.5.5')
        self.assertEqual(client_ip(RequestFactory().get('/', REMOTE_ADDR='10.0.0.1')), '10.0.0.1')

    # KAN-191
    def test_staff_cannot_read_neonize_qr(self):
        res = self.client.get('/api/whatsapp/neonize/status/', **self.as_('staff@x.com'))
        self.assertEqual(res.status_code, 403)

    # KAN-190
    def test_meta_secrets_never_returned(self):
        MetaSettings.objects.create(shop=self.shop, page_access_token='PAGE-SECRET', app_secret='APP-SECRET')
        for who in ('staff@x.com', 'owner@x.com'):
            res = self.client.get('/api/meta-settings/', **self.as_(who))
            self.assertEqual(res.status_code, 200)
            self.assertNotIn('SECRET', res.content.decode())
        self.assertTrue(res.json()['has_page_access_token'])

    def test_blank_secret_write_keeps_stored_value(self):
        MetaSettings.objects.create(shop=self.shop, page_access_token='PAGE-SECRET')
        res = self.client.post('/api/meta-settings/', {'page_access_token': ''}, format='json',
                               **self.as_('owner@x.com'))
        self.assertIn(res.status_code, (200, 201, 405))
        self.assertEqual(MetaSettings.objects.get(shop=self.shop).page_access_token, 'PAGE-SECRET')

    # KAN-196
    def test_staff_cannot_change_customer_email_or_phone_but_owner_can(self):
        c = Customer.all_objects.create(shop=self.shop, name='C', phone='9000000001', email='a@x.com')
        url = f'/api/customers/{c.pk}/'
        res = self.client.patch(url, {'email': 'evil@x.com'}, format='json', **self.as_('staff@x.com'))
        self.assertEqual(res.status_code, 400)
        res = self.client.patch(url, {'phone': '9000000002'}, format='json', **self.as_('staff@x.com'))
        self.assertEqual(res.status_code, 400)
        res = self.client.patch(url, {'name': 'New'}, format='json', **self.as_('staff@x.com'))
        self.assertEqual(res.status_code, 200)
        res = self.client.patch(url, {'email': 'b@x.com'}, format='json', **self.as_('owner@x.com'))
        self.assertEqual(res.status_code, 200)

    # KAN-192
    @override_settings(RAG_CHAT_RATE_PER_HOUR=2)
    def test_rag_chat_origin_rate_limit_and_history_cap(self):
        bad = self.client.post('/api/rag/chat/', {'message': 'hi'}, format='json', HTTP_ORIGIN='https://evil.com', HTTP_X_TENANT_ID='alpha')
        self.assertEqual(bad.status_code, 403, bad.content)
        with mock.patch('api.views.RagService.stream_chat', return_value=iter([b'x'])) as m:
            history = [{'role': 'user', 'content': 'q'}] * 50 + [{'role': 'system', 'content': 'x'}]
            self.client.post('/api/rag/chat/', {'message': 'm' * 5000, 'history': history}, format='json',
                            HTTP_CF_CONNECTING_IP='7.7.7.7', HTTP_X_TENANT_ID='alpha')
            msg, hist = m.call_args[0]
            self.assertEqual(len(msg), 2000)
            self.assertLessEqual(len(hist), 10)
            self.assertTrue(all(t['role'] in ('user', 'assistant') for t in hist))
            self.client.post('/api/rag/chat/', {'message': 'a'}, format='json', HTTP_CF_CONNECTING_IP='7.7.7.7', HTTP_X_TENANT_ID='alpha')
            third = self.client.post('/api/rag/chat/', {'message': 'a'}, format='json',
                                     HTTP_CF_CONNECTING_IP='7.7.7.7', HTTP_X_TENANT_ID='alpha')
            self.assertEqual(third.status_code, 429)
