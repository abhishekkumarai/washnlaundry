"""KAN-219: customer booking API (POST /api/customer/orders/, GET booking-options)."""
from datetime import time, timedelta
from unittest import mock

from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from .models import (
    Customer, GarmentCategory, GarmentItem, Order, OrderSource, ServiceArea, TimeSlot,
)


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True)
class CustomerBookingTests(APITestCase):
    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.alice = Customer.objects.create(name='Alice', phone='9111111111', email='alice@example.com',
                                             address='12 MG Road')
        self.shop = self.alice.shop
        cat = GarmentCategory.objects.create(name='Dry Cleaning')
        self.shirt = GarmentItem.objects.create(category=cat, name='Shirt', price=40)
        self.saree = GarmentItem.objects.create(category=cat, name='Saree', price=150)
        self.hidden = GarmentItem.objects.create(category=cat, name='Old', price=5, is_active=False)
        self.slot = TimeSlot.objects.create(kind=TimeSlot.PICKUP, start_time=time(23, 58),
                                            end_time=time(23, 59), capacity=2)
        ServiceArea.objects.create(name='Indiranagar', pin_code='560038')
        patcher = mock.patch('api.auth.id_token.verify_oauth2_token',
                             return_value={'email': 'alice@example.com', 'email_verified': True})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.auth = {'HTTP_AUTHORIZATION': 'Bearer tok'}
        self.tomorrow = (timezone.localdate() + timedelta(days=1)).isoformat()

    def book(self, key=None, **overrides):
        body = {'items': [{'item_id': self.shirt.id, 'quantity': 3},
                          {'item_id': self.saree.id, 'quantity': 1}],
                'pickup_date': self.tomorrow, 'slot_id': self.slot.id,
                'address': '12 MG Road', 'pin_code': '560038',
                'latitude': 12.97, 'longitude': 77.64, 'notes': 'Ring twice'}
        body.update(overrides)
        extra = dict(self.auth)
        if key:
            extra['HTTP_IDEMPOTENCY_KEY'] = key
        return self.client.post('/api/customer/orders/', body, format='json', **extra)

    def test_order_is_priced_server_side_and_ignores_extra_fields(self):
        res = self.book(items=[{'item_id': self.shirt.id, 'quantity': 3, 'unit_price': 0,
                                'total_price': 0}],
                        total_amount=0, paid_amount=999, discount_amount=500,
                        delivery_type='STORE_PICKUP', status='DELIVERED', customer_name='Mallory')
        self.assertEqual(res.status_code, 201, res.content)
        order = Order.objects.get(order_number=res.json()['order_number'])
        self.assertEqual((order.subtotal, order.total_amount, order.due_amount, order.paid_amount,
                          order.discount_amount), (120, 120, 120, 0, 0))
        self.assertEqual((order.status, order.delivery_type, order.payment_status, order.source),
                         ('PLACED', 'HOME_PICKUP', 'UNPAID', OrderSource.MOBILE_APP))
        self.assertEqual((order.customer, order.customer_name), (self.alice, 'Alice'))
        self.assertEqual(order.items.get().unit_price, 40)
        self.assertEqual((order.pin_code, order.latitude, order.notes), ('560038', 12.97, 'Ring twice'))
        self.assertNotIn('notes', res.json())  # staff-only on the customer API
        self.assertEqual(order.pickup_time, self.slot.start_time)
        self.assertTrue(order.audit_log.exists())

    def test_inactive_or_unknown_items_are_rejected(self):
        for item_id in (self.hidden.id, 99999):
            res = self.book(items=[{'item_id': item_id, 'quantity': 1}])
            self.assertEqual(res.status_code, 400, item_id)
        self.assertEqual(self.book(items=[{'item_id': self.shirt.id, 'quantity': 0}]).status_code, 400)
        self.assertEqual(self.book(items=[]).status_code, 400)
        self.assertFalse(Order.objects.exists())

    def test_full_slot_is_rejected(self):
        self.assertEqual(self.book().status_code, 201)
        self.assertEqual(self.book().status_code, 201)
        self.assertEqual(self.book().status_code, 409)
        self.assertEqual(Order.objects.count(), 2)

    def test_unserved_pincode_and_bad_slot_are_rejected(self):
        self.assertEqual(self.book(pin_code='110001').status_code, 400)
        self.assertEqual(self.book(pin_code='12').status_code, 400)
        past = (timezone.localdate() - timedelta(days=1)).isoformat()
        self.assertEqual(self.book(pickup_date=past).status_code, 400)
        self.assertEqual(self.book(slot_id=99999).status_code, 400)
        self.assertFalse(Order.objects.exists())

    def test_same_idempotency_key_returns_the_first_order(self):
        first = self.book(key='abc-123')
        again = self.book(key='abc-123')
        self.assertEqual((first.status_code, again.status_code), (201, 200))
        self.assertEqual(first.json()['order_number'], again.json()['order_number'])
        self.assertEqual(Order.objects.count(), 1)

    def test_customer_cannot_use_the_staff_order_endpoint(self):
        with override_settings(API_AUTH_ENFORCED=False):
            res = self.client.post('/api/orders/', {
                'customer_name': 'Alice', 'customer_phone': '9111111111',
                'items': [{'item_title': 'Shirt', 'service_type': 'X', 'quantity': 5,
                           'unit_price': 0}]}, format='json', **self.auth)
        self.assertEqual(res.status_code, 403, res.content)
        self.assertFalse(Order.objects.exists())

    def test_booking_options_lists_items_slots_and_pincodes(self):
        self.book()
        res = self.client.get('/api/customer/booking-options/', **self.auth)
        self.assertEqual(res.status_code, 200, res.content)
        body = res.json()
        items = [i['name'] for c in body['categories'] for i in c['items']]
        self.assertEqual(items, ['Shirt', 'Saree'])
        self.assertEqual(body['pincodes'], ['560038'])
        tomorrow = next(d for d in body['days'] if d['date'] == self.tomorrow)
        self.assertEqual(tomorrow['slots'][0]['remaining'], 1)

    def test_booking_with_a_saved_address_copies_it_onto_the_order(self):
        res = self.client.post('/api/customer/addresses/', {
            'label': 'WORK', 'address': '5 Residency Rd', 'landmark': 'Opp. park',
            'pin_code': '560038', 'latitude': 12.9, 'longitude': 77.6}, format='json', **self.auth)
        self.assertEqual(res.status_code, 201, res.content)
        addr_id = res.json()['id']
        order = self.book(address_id=addr_id, address='', pin_code='')
        self.assertEqual(order.status_code, 201, order.content)
        self.assertEqual((order.json()['address'], order.json()['pin_code']),
                         ('5 Residency Rd, Opp. park', '560038'))
        # Editing the address book later does not rewrite the order.
        self.client.patch(f'/api/customer/addresses/{addr_id}/', {'address': 'Moved'},
                          format='json', **self.auth)
        self.assertEqual(Order.objects.get().address, '5 Residency Rd, Opp. park')

    def test_address_book_crud_default_and_validation(self):
        url = '/api/customer/addresses/'
        first = self.client.post(url, {'address': 'A', 'pin_code': '560038'}, format='json', **self.auth).json()
        self.assertTrue(first['is_default'])
        second = self.client.post(url, {'address': 'B', 'pin_code': '560001', 'is_default': True},
                                  format='json', **self.auth).json()
        rows = self.client.get(url, **self.auth).json()['addresses']
        self.assertEqual([(r['address'], r['is_default']) for r in rows], [('B', True), ('A', False)])
        self.assertEqual(self.client.post(url, {'address': 'C', 'pin_code': '12'}, format='json',
                                          **self.auth).status_code, 400)
        self.assertEqual(self.client.post(url, {'address': 'C', 'pin_code': '560001', 'latitude': 95,
                                                'longitude': 1}, format='json', **self.auth).status_code, 400)
        self.assertEqual(self.client.delete(f'{url}{second["id"]}/', **self.auth).status_code, 204)
        rows = self.client.get(url, **self.auth).json()['addresses']
        self.assertEqual([(r['address'], r['is_default']) for r in rows], [('A', True)])

    def test_cannot_touch_another_customers_address(self):
        from .models import CustomerAddress
        bob = Customer.objects.create(name='Bob', phone='9222222222')
        theirs = CustomerAddress.objects.create(customer=bob, address='Bob St', pin_code='560038')
        url = f'/api/customer/addresses/{theirs.id}/'
        self.assertEqual(self.client.patch(url, {'address': 'x'}, format='json', **self.auth).status_code, 404)
        self.assertEqual(self.client.delete(url, **self.auth).status_code, 404)
        self.assertEqual(self.book(address_id=theirs.id).status_code, 400)
        self.assertTrue(CustomerAddress.objects.filter(pk=theirs.id, address='Bob St').exists())

    def test_shop_is_emailed_after_commit(self):
        self.shop.email = 'shop@example.com'
        self.shop.save()
        with mock.patch('api.services.email_service.EmailService.send', return_value=(True, None)) as send, \
                self.captureOnCommitCallbacks(execute=True):
            res = self.book()
        self.assertEqual(res.status_code, 201)
        to, subject, text = send.call_args.args
        self.assertEqual(to, 'shop@example.com')
        self.assertIn(res.json()['order_number'], subject)
        self.assertIn('maps?q=12.97,77.64', text)
        with mock.patch('api.services.email_service.EmailService.send') as send, \
                self.captureOnCommitCallbacks(execute=True):
            self.book(pin_code='110001')  # rejected: no email
        send.assert_not_called()

    def test_staff_changes_feed_returns_new_orders(self):
        from django.contrib.auth import get_user_model
        from .models import ShopMembership, ShopRole
        before = timezone.now().isoformat()
        self.book()
        owner = get_user_model().objects.create_user(username='owner@shop.com', email='owner@shop.com')
        ShopMembership.objects.create(user=owner, shop=self.shop, role=ShopRole.OWNER)
        with mock.patch('api.auth.id_token.verify_oauth2_token',
                        return_value={'email': 'owner@shop.com', 'email_verified': True}):
            res = self.client.get('/api/orders/changes/', {'since': before}, **self.auth,
                                  HTTP_X_TENANT_ID=self.shop.slug)
            self.assertEqual(res.status_code, 200, res.content)
            self.assertEqual(len(res.json()['orders']), 1)
            later = self.client.get('/api/orders/changes/', {'since': res.json()['now']}, **self.auth,
                                    HTTP_X_TENANT_ID=self.shop.slug)
            self.assertEqual(later.json()['orders'], [])
        # Customers cannot read the staff feed.
        self.assertEqual(self.client.get('/api/orders/changes/', {'since': before},
                                         **self.auth).status_code, 403)

    def test_booking_requires_sign_in(self):
        res = self.client.post('/api/customer/orders/', {}, format='json')
        self.assertEqual(res.status_code, 401)
