"""Demo Mode sandboxes: private per session, writable, destroyed on logout/expiry."""
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from api.demo import DEMO_DOMAIN, purge_expired_demos
from api.models import Customer, Order, Shop

User = get_user_model()


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True)
class DemoSandboxTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.real = Shop.objects.create(name='Real Shop', slug='real')
        Customer.all_objects.create(shop=self.real, name='Real Customer', phone='9000000001')

    def start(self):
        res = self.client.post('/api/demo/start/')
        self.assertEqual(res.status_code, 201, res.content)
        body = res.json()
        return {'HTTP_AUTHORIZATION': f"Bearer {body['token']}", 'HTTP_X_TENANT_ID': body['shop']['slug']}, body

    def test_demo_has_data_and_is_writable(self):
        auth, body = self.start()
        res = self.client.get('/api/customers/', **auth)
        self.assertEqual(res.status_code, 200)
        rows = res.json()
        rows = rows.get('results', rows) if isinstance(rows, dict) else rows
        self.assertTrue(rows)
        self.assertNotIn('Real Customer', str(rows))
        made = self.client.post('/api/customers/', {'name': 'Mine', 'phone': '9123456780'},
                                format='json', **auth)
        self.assertEqual(made.status_code, 201, made.content)
        self.assertTrue(Order.all_objects.filter(shop__slug=body['shop']['slug']).exists())

    def test_demo_cannot_reach_real_shop_or_outbound_endpoints(self):
        auth, _ = self.start()
        spoof = dict(auth, HTTP_X_TENANT_ID='real')
        self.assertEqual(self.client.get('/api/customers/', **spoof).status_code, 403)
        for path in ('/api/whatsapp/neonize/status/', '/api/meta-settings/', '/api/meta-social/analytics/'):
            self.assertEqual(self.client.get(path, **auth).status_code, 403, path)
        self.assertEqual(self.client.post('/api/shops/provision/', {'name': 'x'}, format='json',
                                          **auth).status_code, 403)

    def test_logout_destroys_the_sandbox(self):
        auth, body = self.start()
        slug = body['shop']['slug']
        self.assertTrue(Shop.objects.filter(slug=slug).exists())
        self.assertEqual(self.client.post('/api/demo/end/', **auth).status_code, 200)
        self.assertFalse(Shop.objects.filter(slug=slug).exists())
        self.assertFalse(User.objects.filter(username__endswith=DEMO_DOMAIN).exists())
        self.assertIn(self.client.get('/api/customers/', **auth).status_code, (401, 403, 404))
        self.assertTrue(Shop.objects.filter(slug='real').exists())

    def test_abandoned_sandbox_is_purged_after_ttl(self):
        _, body = self.start()
        User.objects.filter(username__endswith=DEMO_DOMAIN).update(
            date_joined=timezone.now() - timedelta(hours=4))
        self.assertEqual(purge_expired_demos(), 1)
        self.assertFalse(Shop.objects.filter(slug=body['shop']['slug']).exists())

    def test_forged_token_is_rejected(self):
        res = self.client.get('/api/customers/', HTTP_AUTHORIZATION='Bearer demo.forged',
                              HTTP_X_TENANT_ID='real')
        self.assertEqual(res.status_code, 401)

    def test_users_cannot_claim_demo_slugs(self):
        owner = User.objects.create_user('o@x.com', 'o@x.com', 'pw')
        res = self.client.post('/api/shops/provision/', {'name': 'Hack', 'slug': 'demo-abc'}, format='json')
        self.assertIn(res.status_code, (400, 401, 403))
        self.assertFalse(Shop.objects.filter(slug='demo-abc').exists())
        self.assertTrue(owner)
