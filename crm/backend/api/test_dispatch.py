"""Rider dispatch: order -> task -> GPS pings -> customer live view -> completion webhook."""
import json
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from api.dispatch_views import sign_webhook
from api.models import (
    Customer, DeliveryType, Order, OrderStatus, RiderLocation, RiderTask, RiderTaskStatus,
    Shop, ShopMembership, ShopRole, Staff,
)

User = get_user_model()


def make_shop(slug, lat=25.5941, lng=85.1376):
    return Shop.objects.create(name=slug.title(), slug=slug, latitude=lat, longitude=lng)


def make_order(shop, delivery_type=DeliveryType.HOME_DELIVERY, customer=None, number='WA-1', geocoded=True):
    return Order.all_objects.create(
        shop=shop, order_number=number, customer=customer, customer_name='Asha', customer_phone='9999999999',
        delivery_type=delivery_type, address='Boring Road, Patna', due_amount=250,
        **({'pickup_lat': 25.61, 'pickup_lng': 85.16, 'drop_lat': 25.61, 'drop_lng': 85.16} if geocoded else {}))


@override_settings(API_AUTH_ENFORCED=False)
class DispatchFlowTests(TestCase):
    def setUp(self):
        cache.clear()
        self.shop = make_shop('alpha')
        self.rider = Staff.all_objects.create(shop=self.shop, name='Ravi', phone='8888888888',
                                              email='ravi@x.com', has_app_login=True)
        self.order = make_order(self.shop)
        self.client = APIClient(HTTP_X_TENANT_ID='alpha')

    def dispatch(self, order=None, **extra):
        order = order or self.order
        return self.client.post(f'/api/orders/{order.id}/dispatch/', {'rider': self.rider.id, **extra}, format='json')

    def test_dispatch_builds_deliveryboy_payload(self):
        r = self.dispatch()
        self.assertEqual(r.status_code, 201, r.content)
        p = r.json()['payload']
        task = RiderTask.all_objects.get()
        self.assertEqual(p['taskId'], str(task.id))
        self.assertEqual(p['externalOrderId'], 'WA-1')
        self.assertEqual(p['pickup']['latitude'], 25.5941)          # delivery starts at the shop
        self.assertEqual(p['destination']['latitude'], 25.61)       # and ends at the customer
        self.assertEqual(p['verificationRequirements']['expectedOtp'], task.otp)
        self.assertEqual(len(task.otp), 4)
        self.assertEqual(p['payment']['amountDue'], 250)
        self.assertIn('?shop=alpha', p['clientApp']['webhookUrl'])
        self.assertTrue(r.json()['deep_link'].startswith('deliveryboy://task?payload='))
        self.order.refresh_from_db()
        self.assertEqual(self.order.assigned_agent_id, self.rider.id)

    def test_pickup_goes_customer_to_shop(self):
        order = make_order(self.shop, DeliveryType.HOME_PICKUP, number='WA-2')
        p = self.dispatch(order).json()['payload']
        self.assertEqual(p['pickup']['latitude'], 25.61)
        self.assertEqual(p['destination']['latitude'], 25.5941)
        self.assertEqual(p['payment']['amountDue'], 0)

    def test_dispatch_rejections(self):
        store = make_order(self.shop, DeliveryType.STORE_PICKUP, number='WA-3')
        self.assertEqual(self.dispatch(store).status_code, 400)
        ungeo = make_order(self.shop, number='WA-4', geocoded=False)
        self.assertEqual(self.dispatch(ungeo).status_code, 400)
        self.assertEqual(self.client.post(f'/api/orders/{self.order.id}/dispatch/', {}, format='json').status_code, 400)
        self.assertEqual(self.dispatch().status_code, 201)
        self.assertEqual(self.dispatch().status_code, 409)   # already active

    def test_pings_move_task_en_route_and_prune(self):
        task_id = self.dispatch().json()['task_id']
        with mock.patch.object(RiderLocation, 'KEEP', 3):
            for i in range(5):
                r = self.client.post('/api/rider/location/', {'task_id': task_id, 'lat': 25.6 + i / 1000, 'lng': 85.15}, format='json')
                self.assertEqual(r.status_code, 201, r.content)
        task = RiderTask.all_objects.get()
        self.assertEqual(task.status, RiderTaskStatus.EN_ROUTE)
        self.assertEqual(RiderLocation.all_objects.count(), 3)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, OrderStatus.OUT_FOR_DELIVERY)

    def test_bad_coordinates_rejected(self):
        task_id = self.dispatch().json()['task_id']
        for bad in ({'lat': 91, 'lng': 0}, {'lat': 'x', 'lng': 0}, {'lng': 0}):
            r = self.client.post('/api/rider/location/', {'task_id': task_id, **bad}, format='json')
            self.assertEqual(r.status_code, 400)

    def _complete(self, task_id, secret_ok=True, verified=True, status='delivered'):
        body = json.dumps({'taskId': task_id, 'status': status, 'verification': {'otpVerified': verified},
                           'timeline': {}, 'deliveryLocation': {}, 'proofOfDelivery': {'driverNotes': 'ok'}}).encode()
        sig = sign_webhook(body) if secret_ok else 'deadbeef'
        return self.client.post('/api/rider/webhook/complete/?shop=alpha', data=body,
                                content_type='application/json', HTTP_X_SIGNATURE=sig)

    def test_webhook_completes_and_delivers(self):
        task_id = self.dispatch().json()['task_id']
        r = self._complete(task_id)
        self.assertEqual(r.status_code, 200, r.content)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, OrderStatus.DELIVERED)
        self.assertIsNotNone(self.order.delivered_at)
        self.assertEqual(RiderTask.all_objects.get().pod['proofOfDelivery']['driverNotes'], 'ok')
        self.assertTrue(self._complete(task_id).json().get('duplicate'))     # idempotent
        # pings after completion are refused
        r = self.client.post('/api/rider/location/', {'task_id': task_id, 'lat': 25.6, 'lng': 85.1}, format='json')
        self.assertEqual(r.status_code, 409)

    def test_webhook_rejects_bad_signature_unverified_otp_and_other_tenant(self):
        task_id = self.dispatch().json()['task_id']
        self.assertEqual(self._complete(task_id, secret_ok=False).status_code, 401)
        self.assertEqual(self._complete(task_id, verified=False).status_code, 400)
        self.assertEqual(self._complete(task_id, status='failed').status_code, 400)
        make_shop('beta')
        body = json.dumps({'taskId': task_id, 'verification': {'otpVerified': True}}).encode()
        r = APIClient().post('/api/rider/webhook/complete/?shop=beta', data=body, content_type='application/json',
                             HTTP_X_SIGNATURE=sign_webhook(body))
        self.assertEqual(r.status_code, 404)                                  # tenant-scoped lookup
        self.order.refresh_from_db()
        self.assertNotEqual(self.order.status, OrderStatus.DELIVERED)

    def test_dispatch_in_other_tenant_is_404(self):
        make_shop('beta')
        r = APIClient(HTTP_X_TENANT_ID='beta').post(
            f'/api/orders/{self.order.id}/dispatch/', {'rider': self.rider.id}, format='json')
        self.assertEqual(r.status_code, 404)


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True)
class DispatchAuthTests(TestCase):
    def setUp(self):
        cache.clear()
        self.shop = make_shop('alpha')
        self.owner = User.objects.create_user('owner@x.com', 'owner@x.com', 'pw')
        ShopMembership.objects.create(user=self.owner, shop=self.shop, role=ShopRole.OWNER, is_default=True)
        self.rider = Staff.all_objects.create(shop=self.shop, name='Ravi', phone='1', email='ravi@x.com', has_app_login=True)
        self.other = Staff.all_objects.create(shop=self.shop, name='Sam', phone='2', email='sam@x.com', has_app_login=True)
        self.cust = Customer.all_objects.create(shop=self.shop, name='Asha', phone='9', email='asha@x.com')
        self.other_cust = Customer.all_objects.create(shop=self.shop, name='Bo', phone='8', email='bo@x.com')
        self.order = make_order(self.shop, customer=self.cust)
        patcher = mock.patch('api.auth.id_token.verify_oauth2_token')
        self.verify = patcher.start()
        self.addCleanup(patcher.stop)
        self.client = APIClient()

    def as_(self, email, tenant=True):
        self.verify.return_value = {'email': email, 'email_verified': True}
        h = {'HTTP_AUTHORIZATION': 'Bearer g'}
        if tenant:
            h['HTTP_X_TENANT_ID'] = 'alpha'
        return h

    def test_full_journey_with_roles(self):
        # unauthenticated callers cannot dispatch
        self.assertEqual(self.client.post(f'/api/orders/{self.order.id}/dispatch/', {'rider': self.rider.id},
                                          format='json', HTTP_X_TENANT_ID='alpha').status_code, 401)
        r = self.client.post(f'/api/orders/{self.order.id}/dispatch/', {'rider': self.rider.id}, format='json', **self.as_('owner@x.com'))
        self.assertEqual(r.status_code, 201, r.content)
        task_id = r.json()['task_id']
        ping = {'task_id': task_id, 'lat': 25.6, 'lng': 85.15}
        # another rider cannot report for this task; the assigned rider can
        self.assertEqual(self.client.post('/api/rider/location/', ping, format='json', **self.as_('sam@x.com')).status_code, 403)
        self.assertEqual(self.client.post('/api/rider/location/', ping, format='json', **self.as_('ravi@x.com')).status_code, 201)

        # the customer sees position + OTP; another customer gets a plain 404
        t = self.client.get('/api/customer/orders/WA-1/track/', **self.as_('asha@x.com', tenant=False))
        self.assertEqual(t.status_code, 200)
        body = t.json()
        self.assertTrue(body['tracking'])
        self.assertEqual(body['location']['lat'], 25.6)
        self.assertEqual(body['otp'], RiderTask.all_objects.get().otp)
        self.assertEqual(body['rider']['name'], 'Ravi')
        self.assertEqual(self.client.get('/api/customer/orders/WA-1/track/', **self.as_('bo@x.com', tenant=False)).status_code, 404)
        self.assertEqual(self.client.get('/api/customer/orders/WA-1/track/').status_code, 401)

        # once completed the OTP and live position are no longer exposed
        RiderTask.all_objects.update(status=RiderTaskStatus.COMPLETED)
        done = self.client.get('/api/customer/orders/WA-1/track/', **self.as_('asha@x.com', tenant=False)).json()
        self.assertIsNone(done['otp'])
        self.assertIsNone(done['location'])

    def test_untracked_order(self):
        self.assertEqual(self.client.get('/api/customer/orders/WA-1/track/', **self.as_('asha@x.com', tenant=False)).json(),
                         {'tracking': False})
