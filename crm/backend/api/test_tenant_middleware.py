from django.test import TestCase
from rest_framework.test import APIClient

from .models import Customer, Order, Shop
from .tenancy import set_current_tenant


class TenantMiddlewareTests(TestCase):
    def setUp(self):
        set_current_tenant(None)
        self.client = APIClient()
        self.shop_alpha = Shop.objects.create(name='Alpha Cleaners', order_prefix='ALP')
        self.shop_beta = Shop.objects.create(name='Beta Laundry', order_prefix='BET')
        self.shop_suspended = Shop.objects.create(name='Suspended Shop', status='SUSPENDED')

        # Create customers in separate shops
        self.cust_alpha = Customer.objects.create(shop=self.shop_alpha, name='Alpha Customer', phone='9100000001')
        self.cust_beta = Customer.objects.create(shop=self.shop_beta, name='Beta Customer', phone='9200000002')

        # Create orders in separate shops
        self.order_alpha = Order.objects.create(shop=self.shop_alpha, customer=self.cust_alpha, customer_name='Alpha Customer', total_amount=500.0, paid_amount=500.0)
        self.order_beta = Order.objects.create(shop=self.shop_beta, customer=self.cust_beta, customer_name='Beta Customer', total_amount=1200.0, paid_amount=1200.0)

    def tearDown(self):
        set_current_tenant(None)

    def test_tenant_resolution_via_x_tenant_id_header(self):
        """Header X-Tenant-ID properly scopes list endpoints to that tenant."""
        res = self.client.get('/api/customers/', HTTP_X_TENANT_ID=self.shop_alpha.slug)
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res['X-Tenant-ID'], self.shop_alpha.slug)
        data = res.json()
        names = [c['name'] for c in data]
        self.assertIn('Alpha Customer', names)
        self.assertNotIn('Beta Customer', names)

    def test_tenant_resolution_via_query_param(self):
        """Query param ?shop=<slug> scopes requests when header is absent."""
        res = self.client.get(f'/api/customers/?shop={self.shop_beta.slug}')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res['X-Tenant-ID'], self.shop_beta.slug)
        data = res.json()
        names = [c['name'] for c in data]
        self.assertIn('Beta Customer', names)
        self.assertNotIn('Alpha Customer', names)

    def test_cross_tenant_detail_view_leak_prevented(self):
        """A tenant cannot retrieve or edit records belonging to another tenant by ID."""
        # Querying beta's order with alpha's header returns 404
        res = self.client.get(f'/api/orders/{self.order_beta.id}/', HTTP_X_TENANT_ID=self.shop_alpha.slug)
        self.assertEqual(res.status_code, 404)

        # Querying with beta's header succeeds
        res_beta = self.client.get(f'/api/orders/{self.order_beta.id}/', HTTP_X_TENANT_ID=self.shop_beta.slug)
        self.assertEqual(res_beta.status_code, 200)
        self.assertEqual(res_beta.json()['id'], str(self.order_beta.id))

    def test_cross_tenant_create_attaches_active_shop(self):
        """POST /api/customers/ automatically assigns the active tenant shop."""
        payload = {'name': 'New Tenant Customer', 'phone': '9300000003'}
        res = self.client.post('/api/customers/', payload, format='json', HTTP_X_TENANT_ID=self.shop_beta.slug)
        self.assertEqual(res.status_code, 201)
        new_cust = Customer.objects.get(phone='9300000003')
        self.assertEqual(new_cust.shop, self.shop_beta)

    def test_unknown_tenant_returns_404(self):
        """Request with non-existent tenant header returns 404."""
        res = self.client.get('/api/orders/', HTTP_X_TENANT_ID='non-existent-shop')
        self.assertEqual(res.status_code, 404)
        self.assertEqual(res.json()['detail'], 'Tenant shop not found.')

    def test_inactive_tenant_returns_403(self):
        """Request targeting an inactive or suspended tenant returns 403."""
        res = self.client.get('/api/orders/', HTTP_X_TENANT_ID=self.shop_suspended.slug)
        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.json()['detail'], 'Tenant shop is inactive or suspended.')

    def test_dashboard_stats_scoped_to_active_tenant(self):
        """Dashboard stats aggregate metrics solely for the requested shop."""
        res_alpha = self.client.get('/api/dashboard/stats/', HTTP_X_TENANT_ID=self.shop_alpha.slug)
        self.assertEqual(res_alpha.status_code, 200)
        data_alpha = res_alpha.json()
        self.assertEqual(data_alpha['total_revenue'], 500.0)
        self.assertEqual(data_alpha['total_orders'], 1)

        res_beta = self.client.get('/api/dashboard/stats/', HTTP_X_TENANT_ID=self.shop_beta.slug)
        self.assertEqual(res_beta.status_code, 200)
        data_beta = res_beta.json()
        self.assertEqual(data_beta['total_revenue'], 1200.0)
        self.assertEqual(data_beta['total_orders'], 1)
