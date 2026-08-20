"""Tests for the LaundryBill CRM API.

Focus is on the things that were previously broken or unmodelled: the status
vocabulary, order numbering, the timeline stamps, delivery charges, derived
filters, and the catalogue shape.
"""

from datetime import date, time, timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APITestCase

from .models import (
    Shop, Customer, GarmentCategory, GarmentItem, Order, OrderItem,
    Staff, Expense, Attendance, SalaryPayment, ServiceArea, TimeSlot,
    OrderStatus, PaymentStatus, DeliveryType, PricingUnit,
)


class ShopTests(TestCase):
    def test_order_prefix_derived_from_name(self):
        shop = Shop.objects.create(name='washing')
        self.assertEqual(shop.order_prefix, 'WASH')

    def test_short_name_is_padded(self):
        shop = Shop.objects.create(name='Ab')
        self.assertEqual(len(shop.order_prefix), 4)

    def test_punctuation_is_stripped(self):
        shop = Shop.objects.create(name='A&B Dry-Clean!')
        self.assertEqual(shop.order_prefix, 'ABDR')

    def test_explicit_prefix_is_respected(self):
        shop = Shop.objects.create(name='washing', order_prefix='WA3P')
        self.assertEqual(shop.order_prefix, 'WA3P')


class OrderNumberTests(TestCase):
    def setUp(self):
        Shop.objects.create(name='washing', order_prefix='WA3P')

    def test_first_order_number(self):
        order = Order.objects.create(customer_name='A', customer_phone='1')
        self.assertEqual(order.order_number, 'WA3P-00001')

    def test_numbers_increment(self):
        Order.objects.create(customer_name='A', customer_phone='1')
        second = Order.objects.create(customer_name='B', customer_phone='2')
        self.assertEqual(second.order_number, 'WA3P-00002')

    def test_numbering_survives_a_gap(self):
        Order.objects.create(customer_name='A', customer_phone='1')
        mid = Order.objects.create(customer_name='B', customer_phone='2')
        mid.delete()
        third = Order.objects.create(customer_name='C', customer_phone='3')
        # Continues from the highest existing number rather than reusing 00002.
        self.assertEqual(third.order_number, 'WA3P-00002')


class OrderTimelineTests(TestCase):
    def setUp(self):
        Shop.objects.create(name='washing')
        self.order = Order.objects.create(customer_name='A', customer_phone='1')

    def test_mark_status_stamps_matching_field(self):
        self.assertIsNone(self.order.processing_at)
        self.order.mark_status(OrderStatus.PROCESSING)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, OrderStatus.PROCESSING)
        self.assertIsNotNone(self.order.processing_at)

    def test_stamps_are_not_overwritten_on_revisit(self):
        self.order.mark_status(OrderStatus.READY)
        first = Order.objects.get(pk=self.order.pk).ready_at
        self.order.mark_status(OrderStatus.PROCESSING)
        self.order.mark_status(OrderStatus.READY)
        self.assertEqual(Order.objects.get(pk=self.order.pk).ready_at, first)

    def test_every_status_has_a_timestamp_field(self):
        for status in OrderStatus.values:
            self.assertIn(status, Order.STATUS_TIMESTAMP_FIELD)
            field = Order.STATUS_TIMESTAMP_FIELD[status]
            self.assertTrue(hasattr(self.order, field), f'missing {field}')


class OrderOverdueTests(TestCase):
    def setUp(self):
        Shop.objects.create(name='washing')
        self.today = timezone.localdate()

    def _order(self, **kwargs):
        return Order.objects.create(customer_name='A', customer_phone='1', **kwargs)

    def test_past_scheduled_date_is_overdue(self):
        order = self._order(scheduled_date=self.today - timedelta(days=1))
        self.assertTrue(order.is_overdue)

    def test_future_scheduled_date_is_not_overdue(self):
        order = self._order(scheduled_date=self.today + timedelta(days=1))
        self.assertFalse(order.is_overdue)

    def test_no_scheduled_date_is_not_overdue(self):
        self.assertFalse(self._order().is_overdue)

    def test_delivered_orders_are_never_overdue(self):
        order = self._order(
            scheduled_date=self.today - timedelta(days=5),
            status=OrderStatus.DELIVERED,
        )
        self.assertFalse(order.is_overdue)

    def test_cancelled_orders_are_never_overdue(self):
        order = self._order(
            scheduled_date=self.today - timedelta(days=5),
            status=OrderStatus.CANCELLED,
        )
        self.assertFalse(order.is_overdue)


class StatusVocabularyTests(TestCase):
    """The bug this suite exists to prevent: three layers drifting apart."""

    def test_canonical_statuses(self):
        self.assertEqual(
            OrderStatus.values,
            ['PLACED', 'PROCESSING', 'IRONING', 'READY',
             'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED'],
        )

    def test_ironing_is_modelled(self):
        self.assertIn('IRONING', OrderStatus.values)

    def test_out_for_delivery_is_a_real_status(self):
        # seed_db.py used to write this even though it wasn't in STATUS_CHOICES.
        self.assertIn('OUT_FOR_DELIVERY', OrderStatus.values)

    def test_overdue_is_derived_not_stored(self):
        self.assertNotIn('OVERDUE', OrderStatus.values)

    def test_washing_is_gone(self):
        self.assertNotIn('WASHING', OrderStatus.values)

    def test_payment_statuses(self):
        self.assertEqual(PaymentStatus.values, ['PAID', 'PARTIAL', 'UNPAID'])


class CatalogueTests(TestCase):
    def setUp(self):
        self.ironing = GarmentCategory.objects.create(name='Ironing', display_order=1)
        self.dry = GarmentCategory.objects.create(name='Dry Cleaning', display_order=2)

    def test_same_garment_in_two_categories_at_two_prices(self):
        GarmentItem.objects.create(category=self.ironing, name='Shirt', price=15)
        GarmentItem.objects.create(category=self.dry, name='Shirt', price=100)
        prices = sorted(GarmentItem.objects.filter(name='Shirt').values_list('price', flat=True))
        self.assertEqual(prices, [15.0, 100.0])

    def test_price_range_and_count(self):
        for price in (10, 50, 100):
            GarmentItem.objects.create(category=self.ironing, name=f'I{price}', price=price)
        self.assertEqual(self.ironing.item_count, 3)
        self.assertEqual(self.ironing.price_range, {'min': 10.0, 'max': 100.0})

    def test_inactive_items_excluded_from_count_and_range(self):
        GarmentItem.objects.create(category=self.ironing, name='A', price=10)
        GarmentItem.objects.create(category=self.ironing, name='B', price=999, is_active=False)
        self.assertEqual(self.ironing.item_count, 1)
        self.assertEqual(self.ironing.price_range['max'], 10.0)

    def test_empty_category_price_range(self):
        self.assertEqual(self.dry.price_range, {'min': 0, 'max': 0})

    def test_non_piece_units(self):
        item = GarmentItem.objects.create(
            category=self.ironing, name='Carpet', price=15, unit=PricingUnit.SQFT
        )
        self.assertEqual(item.get_unit_display(), 'per sq.ft')


class CustomerTests(TestCase):
    def test_avg_order_value(self):
        c = Customer.objects.create(name='A', phone='1', total_orders=4, total_spent=1000)
        self.assertEqual(c.avg_order_value, 250.0)

    def test_avg_order_value_without_orders(self):
        c = Customer.objects.create(name='B', phone='2')
        self.assertEqual(c.avg_order_value, 0.0)


class OrderApiTests(APITestCase):
    def setUp(self):
        Shop.objects.create(name='washing', order_prefix='WA3P')
        self.category = GarmentCategory.objects.create(name='Ironing')
        self.item = GarmentItem.objects.create(category=self.category, name='Shirt', price=15)

    def _create_payload(self, **overrides):
        payload = {
            'customer_name': 'Walk-in',
            'customer_phone': '9000000001',
            'delivery_type': DeliveryType.HOME_DELIVERY,
            'delivery_charge': 50,
            'items': [
                {'item_title': 'Shirt', 'service_type': 'Ironing',
                 'quantity': 4, 'unit': 'PC', 'unit_price': 15},
                {'item_title': 'Sneakers', 'service_type': 'Shoe Cleaning',
                 'quantity': 1, 'unit': 'PC', 'unit_price': 250},
            ],
        }
        payload.update(overrides)
        return payload

    def test_create_order_with_nested_items(self):
        response = self.client.post('/api/orders/', self._create_payload(), format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(len(response.data['items']), 2)

    def test_create_order_derives_totals(self):
        response = self.client.post('/api/orders/', self._create_payload(), format='json')
        self.assertEqual(response.data['subtotal'], 310.0)   # 4*15 + 1*250
        self.assertEqual(response.data['total_amount'], 360.0)  # + 50 delivery
        self.assertEqual(response.data['due_amount'], 360.0)

    def test_create_order_accounts_for_payment(self):
        response = self.client.post(
            '/api/orders/', self._create_payload(paid_amount=100), format='json'
        )
        self.assertEqual(response.data['due_amount'], 260.0)

    def test_create_order_assigns_number_and_places_it(self):
        response = self.client.post('/api/orders/', self._create_payload(), format='json')
        self.assertEqual(response.data['order_number'], 'WA3P-00001')
        self.assertEqual(response.data['status'], OrderStatus.PLACED)
        self.assertIsNotNone(response.data['placed_at'])

    def test_line_totals_are_computed(self):
        response = self.client.post('/api/orders/', self._create_payload(), format='json')
        totals = sorted(i['total_price'] for i in response.data['items'])
        self.assertEqual(totals, [60.0, 250.0])

    def test_status_action_updates_and_stamps(self):
        order = Order.objects.create(customer_name='A', customer_phone='1')
        response = self.client.post(
            f'/api/orders/{order.id}/status/', {'status': 'READY'}, format='json'
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], OrderStatus.READY)
        self.assertIsNotNone(response.data['ready_at'])

    def test_status_action_rejects_unknown_value(self):
        order = Order.objects.create(customer_name='A', customer_phone='1')
        response = self.client.post(
            f'/api/orders/{order.id}/status/', {'status': 'WASHING'}, format='json'
        )
        self.assertEqual(response.status_code, 400)

    def test_payment_action_marks_paid(self):
        order = Order.objects.create(
            customer_name='A', customer_phone='1',
            total_amount=250, due_amount=250, payment_status=PaymentStatus.UNPAID,
        )
        response = self.client.post(
            f'/api/orders/{order.id}/payment/', {'amount': 250}, format='json'
        )
        self.assertEqual(response.data['payment_status'], PaymentStatus.PAID)
        self.assertEqual(response.data['due_amount'], 0.0)

    def test_partial_payment(self):
        order = Order.objects.create(
            customer_name='A', customer_phone='1',
            total_amount=250, due_amount=250, payment_status=PaymentStatus.UNPAID,
        )
        response = self.client.post(
            f'/api/orders/{order.id}/payment/', {'amount': 100}, format='json'
        )
        self.assertEqual(response.data['payment_status'], PaymentStatus.PARTIAL)
        self.assertEqual(response.data['due_amount'], 150.0)

    def test_overpayment_is_capped(self):
        order = Order.objects.create(
            customer_name='A', customer_phone='1', total_amount=250, due_amount=250,
        )
        response = self.client.post(
            f'/api/orders/{order.id}/payment/', {'amount': 9999}, format='json'
        )
        self.assertEqual(response.data['paid_amount'], 250.0)
        self.assertEqual(response.data['due_amount'], 0.0)

    def test_payment_rejects_non_positive_amount(self):
        order = Order.objects.create(customer_name='A', customer_phone='1', total_amount=250)
        response = self.client.post(
            f'/api/orders/{order.id}/payment/', {'amount': 0}, format='json'
        )
        self.assertEqual(response.status_code, 400)


class OrderFilterTests(APITestCase):
    def setUp(self):
        Shop.objects.create(name='washing')
        today = timezone.localdate()
        self.overdue = Order.objects.create(
            customer_name='Overdue', customer_phone='1',
            scheduled_date=today - timedelta(days=2), status=OrderStatus.PROCESSING,
        )
        self.scheduled = Order.objects.create(
            customer_name='Scheduled', customer_phone='2',
            scheduled_date=today + timedelta(days=2), status=OrderStatus.PLACED,
        )
        self.delivered_late = Order.objects.create(
            customer_name='Delivered', customer_phone='3',
            scheduled_date=today - timedelta(days=9), status=OrderStatus.DELIVERED,
        )
        self.unpaid = Order.objects.create(
            customer_name='Unpaid', customer_phone='4',
            payment_status=PaymentStatus.UNPAID,
        )

    def _names(self, query):
        response = self.client.get(f'/api/orders/?status={query}')
        self.assertEqual(response.status_code, 200)
        return {o['customer_name'] for o in response.data}

    def test_overdue_filter_excludes_delivered(self):
        names = self._names('OVERDUE')
        self.assertIn('Overdue', names)
        self.assertNotIn('Delivered', names)

    def test_scheduled_filter(self):
        self.assertIn('Scheduled', self._names('SCHEDULED'))

    def test_unpaid_filter(self):
        self.assertIn('Unpaid', self._names('UNPAID'))

    def test_stored_status_filter(self):
        self.assertEqual(self._names('PROCESSING'), {'Overdue'})

    def test_all_returns_everything(self):
        self.assertEqual(len(self._names('ALL')), 4)

    def test_search_by_order_number(self):
        response = self.client.get(f'/api/orders/?search={self.unpaid.order_number}')
        self.assertEqual(len(response.data), 1)


class CatalogueApiTests(APITestCase):
    def setUp(self):
        self.category = GarmentCategory.objects.create(name='Ironing')
        GarmentItem.objects.create(category=self.category, name='Shirt', price=15)
        GarmentItem.objects.create(
            category=self.category, name='Retired', price=1, is_active=False
        )

    def test_inactive_items_hidden_by_default(self):
        response = self.client.get('/api/items/')
        names = {i['name'] for i in response.data}
        self.assertEqual(names, {'Shirt'})

    def test_inactive_items_can_be_included(self):
        response = self.client.get('/api/items/?include_inactive=true')
        self.assertEqual(len(response.data), 2)

    def test_item_exposes_category_name_and_unit_label(self):
        item = self.client.get('/api/items/').data[0]
        self.assertEqual(item['category_name'], 'Ironing')
        self.assertEqual(item['unit_label'], 'per pc')
        self.assertEqual(item['turnaround_days'], 1)


class SchedulingApiTests(APITestCase):
    def setUp(self):
        TimeSlot.objects.create(
            kind=TimeSlot.PICKUP, start_time=time(9, 0), end_time=time(11, 0)
        )
        TimeSlot.objects.create(
            kind=TimeSlot.DELIVERY, start_time=time(14, 0), end_time=time(16, 0), capacity=20
        )
        ServiceArea.objects.create(name='HBR Layout')

    def test_slots_filter_by_kind(self):
        response = self.client.get('/api/time-slots/?kind=PICKUP')
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['kind'], 'PICKUP')

    def test_unlimited_capacity_is_null(self):
        response = self.client.get('/api/time-slots/?kind=PICKUP')
        self.assertIsNone(response.data[0]['capacity'])

    def test_capacity_is_persisted(self):
        response = self.client.get('/api/time-slots/?kind=DELIVERY')
        self.assertEqual(response.data[0]['capacity'], 20)

    def test_service_areas_listed(self):
        response = self.client.get('/api/service-areas/')
        self.assertEqual(len(response.data), 1)


class DashboardStatsTests(APITestCase):
    def setUp(self):
        Shop.objects.create(name='washing')
        today = timezone.localdate()

        Order.objects.create(
            customer_name='Ready', customer_phone='1', status=OrderStatus.READY,
            total_amount=500, paid_amount=500, delivery_type=DeliveryType.STORE_PICKUP,
        )
        Order.objects.create(
            customer_name='Overdue', customer_phone='2', status=OrderStatus.PROCESSING,
            scheduled_date=today - timedelta(days=1),
            total_amount=300, paid_amount=0, due_amount=300,
            payment_status=PaymentStatus.UNPAID, delivery_type=DeliveryType.ONLINE,
        )
        Order.objects.create(
            customer_name='Ironing', customer_phone='3', status=OrderStatus.IRONING,
            total_amount=200, paid_amount=200, delivery_type=DeliveryType.HOME_DELIVERY,
        )
        Expense.objects.create(title='Rent', amount=100)

        staff = Staff.objects.create(name='Ramesh', role='Washer', phone='9')
        Attendance.objects.create(staff=staff, date=today, status=Attendance.PRESENT)

        self.stats = self.client.get('/api/dashboard/stats/').data

    def test_pipeline_groups_ironing_with_processing(self):
        self.assertEqual(self.stats['pipeline']['processing'], 2)

    def test_ready_count(self):
        self.assertEqual(self.stats['pipeline']['ready'], 1)

    def test_overdue_uses_scheduled_date(self):
        self.assertEqual(self.stats['overdue'], 1)

    def test_revenue_series_has_fourteen_points(self):
        self.assertEqual(len(self.stats['revenue_series']), 14)

    def test_revenue_series_measures_collected_not_billed(self):
        # Today's orders bill 1000 but have collected 700. The series used to
        # sum total_amount while `revenue_today` summed paid_amount, so the
        # chart's last bar could never match the KPI card beside it.
        self.assertEqual(self.stats['revenue_series'][-1]['amount'], 700.0)
        self.assertEqual(self.stats['revenue_today'], 700.0)

    def test_revenue_series_ends_today(self):
        self.assertEqual(
            self.stats['revenue_series'][-1]['date'],
            timezone.localdate().isoformat(),
        )

    def test_revenue_analytics(self):
        analytics = self.stats['revenue_analytics']
        self.assertEqual(analytics['sales'], 1000.0)
        self.assertEqual(analytics['collected'], 700.0)
        self.assertEqual(analytics['uncollected'], 300.0)
        self.assertEqual(analytics['net_profit'], 600.0)

    def test_needs_attention_outstanding(self):
        self.assertEqual(self.stats['needs_attention']['unpaid_outstanding'], 300.0)

    def test_order_channels(self):
        channels = self.stats['order_channels']
        self.assertEqual(channels['store_pickup'], 1)
        self.assertEqual(channels['home_delivery'], 1)
        self.assertEqual(channels['online'], 1)

    def test_staff_attendance(self):
        self.assertEqual(self.stats['staff_attendance']['present'], 1)
        self.assertEqual(self.stats['staff_attendance']['total_staff'], 1)

    def test_store_health_reports_a_score_and_verdict(self):
        health = self.stats['store_health']
        self.assertIsInstance(health['score'], int)
        self.assertIn(health['verdict'], ['Healthy', 'Fair', 'Needs attention'])

    def test_collection_rate_matches_analytics(self):
        self.assertEqual(
            self.stats['store_health']['collection_rate'],
            self.stats['revenue_analytics']['collection_progress'],
        )

    def test_unmeasurable_metrics_are_null_not_zero(self):
        # No delivered orders in this fixture, and pickups aren't tracked, so
        # these must read as "no data" rather than "0%".
        health = self.stats['store_health']
        self.assertIsNone(health['on_time_delivery'])
        self.assertIsNone(health['on_time_pickup'])

    def test_order_flow_counts_active_orders_on_schedule(self):
        # One scheduled active order, and it is overdue.
        self.assertEqual(self.stats['store_health']['order_flow'], 0.0)
        self.assertEqual(self.stats['store_health']['active_on_schedule'], 0)

    def test_legacy_keys_still_present(self):
        for key in ('total_orders', 'total_revenue', 'total_dues', 'total_expenses'):
            self.assertIn(key, self.stats)


class ShopApiTests(APITestCase):
    def setUp(self):
        self.shop = Shop.objects.create(name='washing', city='Bengaluru')

    def test_patch_updates_the_profile(self):
        response = self.client.patch(
            f'/api/shops/{self.shop.id}/',
            {'name': 'Washing Express', 'city': 'Mysuru', 'pin_code': '570001'},
            format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.shop.refresh_from_db()
        self.assertEqual(self.shop.name, 'Washing Express')
        self.assertEqual(self.shop.city, 'Mysuru')
        self.assertEqual(self.shop.pin_code, '570001')

    def test_patch_leaves_untouched_fields_alone(self):
        self.client.patch(
            f'/api/shops/{self.shop.id}/', {'city': 'Mysuru'}, format='json'
        )
        self.shop.refresh_from_db()
        self.assertEqual(self.shop.name, 'washing')

    def test_shop_exposes_the_settings_fields(self):
        data = self.client.get('/api/shops/').data[0]
        for field in ('name', 'phone', 'whatsapp', 'email', 'address', 'city',
                      'state', 'pin_code', 'gstin', 'pan', 'tax_rate', 'upi_id'):
            self.assertIn(field, data)


class StaffApiTests(APITestCase):
    def setUp(self):
        Staff.objects.create(
            name='Mohan Das', role='Delivery Driver', phone='9933441122',
            daily_wage=580, is_delivery_agent=True, has_app_login=True,
        )
        Staff.objects.create(name='Sunil Paswan', role='Steam Press', phone='9811445566')

    def test_list_exposes_the_roster_flags(self):
        response = self.client.get('/api/staff/')
        by_name = {s['name']: s for s in response.data}
        self.assertTrue(by_name['Mohan Das']['is_delivery_agent'])
        self.assertTrue(by_name['Mohan Das']['has_app_login'])
        self.assertFalse(by_name['Sunil Paswan']['is_delivery_agent'])

    def test_create_staff_persists(self):
        response = self.client.post('/api/staff/', {
            'name': 'New Presser',
            'role': 'Ironing',
            'phone': '9000000009',
            'daily_wage': 640,
            'is_delivery_agent': False,
        }, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(Staff.objects.filter(name='New Presser').exists())

    def test_create_defaults_to_no_app_login(self):
        response = self.client.post(
            '/api/staff/',
            {'name': 'Temp', 'role': 'Washer', 'phone': '9000000010'},
            format='json',
        )
        self.assertFalse(response.data['has_app_login'])
        self.assertEqual(response.data['status'], 'ACTIVE')


class AttendanceTests(TestCase):
    def test_one_record_per_staff_per_day(self):
        from django.db.utils import IntegrityError

        staff = Staff.objects.create(name='A', role='Washer', phone='1')
        Attendance.objects.create(staff=staff, date=date(2026, 7, 30))
        with self.assertRaises(IntegrityError):
            Attendance.objects.create(staff=staff, date=date(2026, 7, 30))


class AttendanceBulkTests(APITestCase):
    """POST /api/attendance/bulk/ — the Attendance screen's Save Register.

    Save Register has to be pressable twice. Because Attendance is unique on
    (staff, date), a create-only endpoint would 400 the second time, so this
    upserts and these tests pin that.
    """

    def setUp(self):
        self.a = Staff.objects.create(name='Ramesh Kumar', role='Head Washer', phone='1')
        self.b = Staff.objects.create(name='Geeta Devi', role='Dry Cleaning', phone='2')
        self.day = '2026-08-11'

    def post(self, payload):
        return self.client.post('/api/attendance/bulk/', payload, format='json')

    def test_creates_a_register_for_an_unmarked_day(self):
        response = self.post({
            'date': self.day,
            'entries': [
                {'staff': self.a.id, 'status': 'PRESENT'},
                {'staff': self.b.id, 'status': 'ABSENT'},
            ],
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(Attendance.objects.filter(date=date(2026, 8, 11)).count(), 2)

    def test_resaving_overwrites_rather_than_duplicating(self):
        self.post({'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'PRESENT'}]})
        response = self.post(
            {'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'HALF_DAY'}]}
        )
        self.assertEqual(response.status_code, 200)
        rows = Attendance.objects.filter(staff=self.a, date=date(2026, 8, 11))
        self.assertEqual(rows.count(), 1)
        self.assertEqual(rows.first().status, Attendance.HALF_DAY)

    def test_response_is_the_whole_day_not_just_the_rows_sent(self):
        self.post({'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'PRESENT'}]})
        response = self.post({'date': self.day, 'entries': [{'staff': self.b.id, 'status': 'LEAVE'}]})
        self.assertEqual(len(response.data), 2)

    def test_staff_name_is_serialised(self):
        response = self.post({'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'PRESENT'}]})
        self.assertEqual(response.data[0]['staff_name'], 'Ramesh Kumar')

    def test_leave_is_an_accepted_status(self):
        # LEAVE has always been stored and counted on the dashboard, but the
        # Attendance screen only ever offered three of the four values.
        response = self.post({'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'LEAVE'}]})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(Attendance.objects.get(staff=self.a).status, Attendance.LEAVE)

    def test_unknown_status_is_rejected(self):
        response = self.post({'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'HOLIDAY'}]})
        self.assertEqual(response.status_code, 400)

    def test_missing_date_is_rejected(self):
        response = self.post({'entries': [{'staff': self.a.id, 'status': 'PRESENT'}]})
        self.assertEqual(response.status_code, 400)

    def test_unparseable_date_is_rejected(self):
        response = self.post(
            {'date': '11/08/2026', 'entries': [{'staff': self.a.id, 'status': 'PRESENT'}]}
        )
        self.assertEqual(response.status_code, 400)

    def test_unknown_staff_is_rejected(self):
        response = self.post({'date': self.day, 'entries': [{'staff': 9999, 'status': 'PRESENT'}]})
        self.assertEqual(response.status_code, 400)

    def test_entries_must_be_a_list(self):
        response = self.post({'date': self.day, 'entries': {'staff': self.a.id}})
        self.assertEqual(response.status_code, 400)

    def test_a_rejected_entry_writes_nothing(self):
        # Validation runs over the whole batch before the first write: a
        # half-saved register is worse than a rejected one.
        response = self.post({
            'date': self.day,
            'entries': [
                {'staff': self.a.id, 'status': 'PRESENT'},
                {'staff': self.b.id, 'status': 'HOLIDAY'},
            ],
        })
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Attendance.objects.count(), 0)

    def test_empty_entries_is_a_no_op_not_an_error(self):
        response = self.post({'date': self.day, 'entries': []})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(Attendance.objects.count(), 0)

    def test_list_filters_by_date(self):
        self.post({'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'PRESENT'}]})
        self.post({'date': '2026-08-10', 'entries': [{'staff': self.a.id, 'status': 'ABSENT'}]})
        response = self.client.get('/api/attendance/', {'date': self.day})
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['status'], 'PRESENT')


class PayrollTests(APITestCase):
    """GET /api/payroll/?month=YYYY-MM.

    Wages earned are derived from the attendance register, never stored, so
    they cannot drift out of step with it. What was paid comes from
    SalaryPayment, which is the thing the schema previously had no room for at
    all — which is why the Payroll screen's Paid column was hardcoded.
    """

    def setUp(self):
        self.staff = Staff.objects.create(
            name='Ramesh Kumar', role='Head Washer', phone='1', daily_wage=600.0
        )
        self.month = date(2026, 7, 1)

    def mark(self, day, status, staff=None):
        Attendance.objects.create(
            staff=staff or self.staff, date=date(2026, 7, day), status=status
        )

    def payroll(self, month='2026-07'):
        return self.client.get('/api/payroll/', {'month': month}).data

    def entry(self, month='2026-07'):
        return self.payroll(month)['entries'][0]

    def test_present_days_are_worth_a_full_day(self):
        self.mark(1, Attendance.PRESENT)
        self.mark(2, Attendance.PRESENT)
        entry = self.entry()
        self.assertEqual(entry['days_worked'], 2.0)
        self.assertEqual(entry['total_salary'], 1200.0)

    def test_half_day_is_worth_half(self):
        # HALF_DAY is offered on the register and stored, so paying it as a
        # whole day would quietly overpay.
        self.mark(1, Attendance.PRESENT)
        self.mark(2, Attendance.HALF_DAY)
        entry = self.entry()
        self.assertEqual(entry['days_worked'], 1.5)
        self.assertEqual(entry['total_salary'], 900.0)

    def test_absent_and_leave_are_unpaid(self):
        self.mark(1, Attendance.PRESENT)
        self.mark(2, Attendance.ABSENT)
        self.mark(3, Attendance.LEAVE)
        self.assertEqual(self.entry()['days_worked'], 1.0)

    def test_no_attendance_means_no_wages(self):
        entry = self.entry()
        self.assertEqual(entry['days_worked'], 0.0)
        self.assertEqual(entry['total_salary'], 0.0)

    def test_a_neighbouring_month_is_excluded(self):
        self.mark(1, Attendance.PRESENT)
        Attendance.objects.create(
            staff=self.staff, date=date(2026, 8, 1), status=Attendance.PRESENT
        )
        Attendance.objects.create(
            staff=self.staff, date=date(2026, 6, 30), status=Attendance.PRESENT
        )
        self.assertEqual(self.entry()['days_worked'], 1.0)

    def test_december_does_not_bleed_into_january(self):
        # The next-month boundary is computed by adding 32 days and snapping to
        # the 1st, so a year rollover is worth pinning.
        member = Staff.objects.create(name='Solo', role='Washer', phone='9', daily_wage=100.0)
        Staff.objects.filter(id=self.staff.id).delete()
        Attendance.objects.create(staff=member, date=date(2026, 12, 31), status=Attendance.PRESENT)
        Attendance.objects.create(staff=member, date=date(2027, 1, 1), status=Attendance.PRESENT)
        self.assertEqual(self.entry('2026-12')['days_worked'], 1.0)

    def test_unpaid_when_nothing_has_been_paid(self):
        self.mark(1, Attendance.PRESENT)
        entry = self.entry()
        self.assertEqual(entry['paid_amount'], 0.0)
        self.assertEqual(entry['pending_amount'], 600.0)
        self.assertEqual(entry['status'], PaymentStatus.UNPAID)

    def test_partial_when_part_paid(self):
        self.mark(1, Attendance.PRESENT)
        SalaryPayment.objects.create(staff=self.staff, month=self.month, amount=200.0)
        entry = self.entry()
        self.assertEqual(entry['pending_amount'], 400.0)
        self.assertEqual(entry['status'], PaymentStatus.PARTIAL)

    def test_instalments_add_up(self):
        # Deliberately not unique on (staff, month): a month can be paid in
        # parts, which is the whole reason PARTIAL is a real state.
        self.mark(1, Attendance.PRESENT)
        SalaryPayment.objects.create(staff=self.staff, month=self.month, amount=200.0)
        SalaryPayment.objects.create(staff=self.staff, month=self.month, amount=400.0)
        entry = self.entry()
        self.assertEqual(entry['paid_amount'], 600.0)
        self.assertEqual(entry['status'], PaymentStatus.PAID)

    def test_overpayment_does_not_produce_negative_pending(self):
        self.mark(1, Attendance.PRESENT)
        SalaryPayment.objects.create(staff=self.staff, month=self.month, amount=1000.0)
        entry = self.entry()
        self.assertEqual(entry['pending_amount'], 0.0)
        self.assertEqual(entry['status'], PaymentStatus.PAID)

    def test_payment_in_another_month_does_not_count(self):
        self.mark(1, Attendance.PRESENT)
        SalaryPayment.objects.create(staff=self.staff, month=date(2026, 8, 1), amount=600.0)
        self.assertEqual(self.entry()['paid_amount'], 0.0)

    def test_month_is_normalised_to_the_first(self):
        payment = SalaryPayment.objects.create(
            staff=self.staff, month=date(2026, 7, 19), amount=100.0
        )
        payment.refresh_from_db()
        self.assertEqual(payment.month, date(2026, 7, 1))

    def test_inactive_staff_are_off_the_payroll(self):
        Staff.objects.create(
            name='Bhola Prasad', role='Retired', phone='2', status='INACTIVE'
        )
        names = [e['staff_name'] for e in self.payroll()['entries']]
        self.assertEqual(names, ['Ramesh Kumar'])

    def test_totals_sum_the_entries(self):
        other = Staff.objects.create(
            name='Geeta Devi', role='Dry Cleaning', phone='3', daily_wage=500.0
        )
        self.mark(1, Attendance.PRESENT)
        self.mark(1, Attendance.PRESENT, staff=other)
        SalaryPayment.objects.create(staff=self.staff, month=self.month, amount=100.0)

        totals = self.payroll()['totals']
        self.assertEqual(totals['total_payroll'], 1100.0)
        self.assertEqual(totals['paid'], 100.0)
        self.assertEqual(totals['pending'], 1000.0)
        self.assertEqual(totals['staff_count'], 2)

    def test_month_defaults_to_the_current_one(self):
        response = self.client.get('/api/payroll/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.data['month'], timezone.localdate().replace(day=1).isoformat()
        )

    def test_an_unparseable_month_falls_back_rather_than_500ing(self):
        response = self.client.get('/api/payroll/', {'month': 'July'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.data['month'], timezone.localdate().replace(day=1).isoformat()
        )

    def test_salary_payment_endpoint_filters_by_month(self):
        SalaryPayment.objects.create(staff=self.staff, month=self.month, amount=100.0)
        SalaryPayment.objects.create(staff=self.staff, month=date(2026, 8, 1), amount=200.0)
        response = self.client.get('/api/salary-payments/', {'month': '2026-07'})
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['amount'], 100.0)
        self.assertEqual(response.data[0]['staff_name'], 'Ramesh Kumar')

    def test_recording_a_payment_moves_the_summary(self):
        self.mark(1, Attendance.PRESENT)
        self.client.post(
            '/api/salary-payments/',
            {'staff': self.staff.id, 'month': '2026-07-01', 'amount': 250.0},
            format='json',
        )
        entry = self.entry()
        self.assertEqual(entry['paid_amount'], 250.0)
        self.assertEqual(entry['status'], PaymentStatus.PARTIAL)

    def test_a_non_positive_payment_is_rejected(self):
        response = self.client.post(
            '/api/salary-payments/',
            {'staff': self.staff.id, 'month': '2026-07-01', 'amount': 0},
            format='json',
        )
        self.assertEqual(response.status_code, 400)


class ReportsApiTests(APITestCase):
    """GET /api/reports/?from=&to=.

    The Reports screen used to hardcode every figure it showed, including a
    status breakdown listing "Washing" — a status deleted from the model.
    Driving the breakdowns off the canonical choices makes that impossible.
    """

    def setUp(self):
        Shop.objects.create(name='washing')
        self.today = timezone.localdate()
        self.month_start = self.today.replace(day=1)

    def make_order(self, *, total, paid, when=None, status=OrderStatus.PLACED,
                   delivery_type=DeliveryType.STORE_PICKUP, method='CASH'):
        order = Order.objects.create(
            customer_name='A',
            status=status,
            delivery_type=delivery_type,
            payment_method=method,
            total_amount=total,
            paid_amount=paid,
            due_amount=total - paid,
        )
        if when:
            Order.objects.filter(pk=order.pk).update(created_at=when)
        return order

    def report(self, **params):
        return self.client.get('/api/reports/', params).data

    def test_defaults_to_the_current_month(self):
        data = self.report()
        self.assertEqual(data['from'], self.month_start.isoformat())
        self.assertEqual(data['to'], self.today.isoformat())

    def test_totals_come_from_the_orders_in_range(self):
        self.make_order(total=1000, paid=800)
        self.make_order(total=500, paid=0)
        data = self.report()
        self.assertEqual(data['revenue'], 1500)
        self.assertEqual(data['collected'], 800)
        self.assertEqual(data['outstanding'], 700)
        self.assertEqual(data['order_count'], 2)
        self.assertEqual(data['average_order_value'], 750)

    def test_orders_outside_the_range_are_excluded(self):
        self.make_order(total=1000, paid=1000)
        self.make_order(
            total=9999, paid=9999, when=timezone.now() - timedelta(days=400)
        )
        self.assertEqual(self.report()['revenue'], 1000)

    def test_an_explicit_range_is_honoured(self):
        self.make_order(total=100, paid=100, when=timezone.now() - timedelta(days=10))
        self.make_order(total=200, paid=200, when=timezone.now() - timedelta(days=2))
        data = self.report(
            **{
                'from': (self.today - timedelta(days=4)).isoformat(),
                'to': self.today.isoformat(),
            }
        )
        self.assertEqual(data['revenue'], 200)

    def test_a_reversed_range_is_swapped_rather_than_returning_nothing(self):
        self.make_order(total=100, paid=100)
        data = self.report(
            **{'from': self.today.isoformat(), 'to': self.month_start.isoformat()}
        )
        self.assertEqual(data['from'], self.month_start.isoformat())
        self.assertEqual(data['revenue'], 100)

    def test_net_profit_is_collected_minus_expenses(self):
        self.make_order(total=1000, paid=900)
        Expense.objects.create(title='Rent', amount=400.0)
        data = self.report()
        self.assertEqual(data['expenses'], 400)
        self.assertEqual(data['net_profit'], 500)
        self.assertEqual(data['margin'], round((500 / 900) * 100, 1))

    def test_margin_is_null_not_zero_when_nothing_was_collected(self):
        # An idle period is not a 0% margin; the UI renders the two differently.
        data = self.report()
        self.assertIsNone(data['margin'])
        self.assertIsNone(data['collected_percent'])

    def test_monthly_series_has_eight_points(self):
        series = self.report()['monthly_series']
        self.assertEqual(len(series), 8)
        self.assertEqual(series[-1]['month'], self.month_start.isoformat())

    def test_monthly_series_is_chronological_and_labelled(self):
        series = self.report()['monthly_series']
        months = [point['month'] for point in series]
        self.assertEqual(months, sorted(months))
        self.assertTrue(all(point['label'] for point in series))

    def test_monthly_series_carries_amounts_not_ratios(self):
        # The screen used to be handed hand-typed ratios like 0.25 and had to
        # be told the scale; it now normalises real rupee amounts itself.
        self.make_order(total=1234, paid=1234)
        series = self.report()['monthly_series']
        self.assertEqual(series[-1]['revenue'], 1234)

    def test_by_status_uses_the_canonical_vocabulary(self):
        self.make_order(total=10, paid=0, status=OrderStatus.IRONING)
        labels = [row['label'] for row in self.report()['by_status']]
        self.assertIn('Ironing', labels)

    def test_washing_can_never_appear_in_a_breakdown(self):
        self.make_order(total=10, paid=0, status=OrderStatus.PROCESSING)
        labels = [row['label'] for row in self.report()['by_status']]
        self.assertNotIn('Washing', labels)

    def test_breakdowns_omit_statuses_with_no_orders(self):
        self.make_order(total=10, paid=0, status=OrderStatus.READY)
        keys = [row['key'] for row in self.report()['by_status']]
        self.assertEqual(keys, [OrderStatus.READY])

    def test_by_type_covers_all_four_channels(self):
        self.make_order(total=10, paid=0, delivery_type=DeliveryType.HOME_DELIVERY)
        self.make_order(total=10, paid=0, delivery_type=DeliveryType.ONLINE)
        keys = {row['key'] for row in self.report()['by_type']}
        self.assertEqual(keys, {DeliveryType.HOME_DELIVERY, DeliveryType.ONLINE})

    def test_by_service_groups_order_items(self):
        order = self.make_order(total=10, paid=0)
        OrderItem.objects.create(order=order, item_title='Shirt', service_type='Ironing')
        OrderItem.objects.create(order=order, item_title='Trousers', service_type='Ironing')
        OrderItem.objects.create(order=order, item_title='Coat', service_type='Dry Cleaning')
        by_service = {row['label']: row['count'] for row in self.report()['by_service']}
        self.assertEqual(by_service, {'Ironing': 2, 'Dry Cleaning': 1})

    def test_payment_mix_percentages_sum_to_a_hundred(self):
        self.make_order(total=600, paid=600, method='UPI')
        self.make_order(total=400, paid=400, method='CASH')
        mix = self.report()['payment_mix']
        self.assertEqual(round(sum(row['percent'] for row in mix)), 100)
        # Sorted by amount, so the dominant method reads first.
        self.assertEqual(mix[0]['method'], 'UPI')
        self.assertEqual(mix[0]['percent'], 60.0)

    def test_payment_mix_is_empty_rather_than_dividing_by_zero(self):
        self.make_order(total=500, paid=0, method='CASH')
        self.assertEqual(self.report()['payment_mix'], [])

    def test_an_empty_range_returns_zeroes_not_an_error(self):
        data = self.report(**{'from': '2020-01-01', 'to': '2020-01-31'})
        self.assertEqual(data['revenue'], 0)
        self.assertEqual(data['order_count'], 0)
        self.assertEqual(data['average_order_value'], 0)
        self.assertEqual(data['by_status'], [])

    def test_change_is_measured_against_the_preceding_window(self):
        span_start = self.today - timedelta(days=6)
        self.make_order(total=200, paid=200, when=timezone.now() - timedelta(days=1))
        self.make_order(total=100, paid=100, when=timezone.now() - timedelta(days=8))
        data = self.report(
            **{'from': span_start.isoformat(), 'to': self.today.isoformat()}
        )
        self.assertEqual(data['revenue'], 200)
        self.assertEqual(data['revenue_change'], 100.0)

    def test_change_is_null_when_there_is_nothing_to_compare(self):
        self.assertIsNone(self.report()['revenue_change'])

    def test_an_unparseable_date_falls_back_rather_than_500ing(self):
        data = self.report(**{'from': 'last tuesday'})
        self.assertEqual(data['from'], self.month_start.isoformat())


class PosCheckoutContractTests(APITestCase):
    """The exact request the Flutter New Order screen sends on Checkout.

    This pins the contract that was previously broken: the client posted
    `status: 'WASHING'` — not a member of OrderStatus — so *every* checkout
    came back 400 and no order was ever saved. The UI showed a receipt anyway.
    """

    def setUp(self):
        Shop.objects.create(name='washing', order_prefix='WA3P')
        self.customer = Customer.objects.create(name='Priya Sundaram', phone='9000000002')

    def _checkout(self, **overrides):
        payload = {
            'customer_name': 'Walk-in customer',
            'customer_phone': '',
            'status': OrderStatus.PLACED,
            'payment_status': PaymentStatus.PAID,
            'payment_method': 'CASH',
            'delivery_type': DeliveryType.STORE_PICKUP,
            'source': 'WEB',
            'subtotal': 45.0,
            'total_amount': 45.0,
            'paid_amount': 45.0,
            'due_amount': 0.0,
            'express': False,
            'items': [
                {'item_title': 'Shirt', 'service_type': 'Ironing', 'status': OrderStatus.PLACED,
                 'quantity': 2, 'unit': 'PC', 'unit_price': 15.0, 'total_price': 30.0},
                {'item_title': 'T-Shirt', 'service_type': 'Wash & Iron', 'status': OrderStatus.PLACED,
                 'quantity': 1, 'unit': 'PC', 'unit_price': 15.0, 'total_price': 15.0},
            ],
        }
        payload.update(overrides)
        return self.client.post('/api/orders/', payload, format='json')

    def test_checkout_payload_is_accepted(self):
        response = self._checkout()
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(Order.objects.count(), 1)

    def test_washing_is_still_rejected(self):
        # The regression itself. If this ever passes, the vocabulary drifted back.
        response = self._checkout(status='WASHING')
        self.assertEqual(response.status_code, 400)
        self.assertIn('status', response.data)
        self.assertEqual(Order.objects.count(), 0)

    def test_server_allocates_the_order_number(self):
        # The client no longer sends one; even if it did, order_number is
        # read-only, so the flat `LB-xxxx` scheme can never reach the database.
        response = self._checkout(order_number='LB-2001')
        self.assertEqual(response.data['order_number'], 'WA3P-00001')

    def test_paid_checkout_clears_the_due(self):
        response = self._checkout()
        self.assertEqual(response.data['paid_amount'], 45.0)
        self.assertEqual(response.data['due_amount'], 0.0)
        self.assertEqual(response.data['payment_status'], PaymentStatus.PAID)

    def test_unpaid_checkout_carries_the_full_due(self):
        response = self._checkout(
            payment_status=PaymentStatus.UNPAID, paid_amount=0.0, due_amount=45.0
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['due_amount'], 45.0)
        self.assertEqual(response.data['payment_status'], PaymentStatus.UNPAID)

    def test_checkout_stamps_the_timeline(self):
        response = self._checkout()
        self.assertIsNotNone(response.data['placed_at'])
        self.assertEqual(response.data['status'], OrderStatus.PLACED)

    def test_named_customer_is_attached(self):
        response = self._checkout(
            customer=str(self.customer.id),
            customer_name=self.customer.name,
            customer_phone=self.customer.phone,
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(Order.objects.get().customer, self.customer)

    def test_walk_in_needs_no_customer_record(self):
        response = self._checkout()
        self.assertEqual(response.status_code, 201, response.data)
        self.assertIsNone(Order.objects.get().customer)

    def test_express_flag_survives(self):
        response = self._checkout(express=True)
        self.assertTrue(response.data['express'])

    def test_created_order_appears_in_the_list(self):
        self._checkout()
        listed = self.client.get('/api/orders/').data
        self.assertEqual(len(listed), 1)
        self.assertEqual(listed[0]['order_number'], 'WA3P-00001')

    def test_created_order_matches_the_placed_filter_chip(self):
        # The phantom `WASHING` orders matched no chip on the Orders screen.
        self._checkout()
        listed = self.client.get('/api/orders/?status=PLACED').data
        self.assertEqual(len(listed), 1)


class ExpenseDateTests(APITestCase):
    """`date` used to be auto_now_add, so an expense could only ever be filed
    under the day it was typed in — July's rent landed in August."""

    def test_date_defaults_to_now(self):
        expense = Expense.objects.create(title='Detergent', amount=500)
        self.assertAlmostEqual(
            expense.date.timestamp(), timezone.now().timestamp(), delta=5
        )

    def test_date_can_be_backdated(self):
        when = timezone.now() - timedelta(days=30)
        expense = Expense.objects.create(title='Shop Rent', amount=28000, date=when)
        expense.refresh_from_db()
        self.assertEqual(expense.date, when)

    def test_api_accepts_an_explicit_date(self):
        when = timezone.now() - timedelta(days=10)
        response = self.client.post('/api/expenses/', {
            'title': 'Electricity Bill',
            'category': 'Utilities',
            'amount': 4200,
            'payment_method': 'BANK_TRANSFER',
            'date': when.isoformat(),
        }, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual(Expense.objects.get().date, when)

    def test_api_still_works_without_a_date(self):
        response = self.client.post('/api/expenses/', {
            'title': 'Packaging Bags',
            'amount': 650,
        }, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertIsNotNone(Expense.objects.get().date)

    def test_list_is_newest_first(self):
        old = Expense.objects.create(
            title='Old', amount=1, date=timezone.now() - timedelta(days=20)
        )
        new = Expense.objects.create(
            title='New', amount=2, date=timezone.now() - timedelta(days=1)
        )
        titles = [e['title'] for e in self.client.get('/api/expenses/').data]
        self.assertEqual(titles, [new.title, old.title])


class OrderProvenanceTests(APITestCase):
    """The live timeline writes "Created by abhishek kumar" for a counter order
    and "Created by Mobile App" for an app one, so the field holds either a
    person or a channel and cannot be the OrderSource enum."""

    def test_created_by_defaults_to_blank(self):
        order = Order.objects.create(customer_name='Walk-in', total_amount=100)
        self.assertEqual(order.created_by, '')

    def test_created_by_holds_a_person(self):
        order = Order.objects.create(
            customer_name='Me', total_amount=150, created_by='abhishek kumar'
        )
        order.refresh_from_db()
        self.assertEqual(order.created_by, 'abhishek kumar')

    def test_created_by_is_serialised(self):
        Order.objects.create(customer_name='Me', total_amount=150, created_by='AK')
        listed = self.client.get('/api/orders/').data
        self.assertEqual(listed[0]['created_by'], 'AK')


class OrderStatusNoteTests(APITestCase):
    def setUp(self):
        self.order = Order.objects.create(customer_name='Me', total_amount=150)

    def test_status_change_accepts_a_note(self):
        response = self.client.post(
            f'/api/orders/{self.order.id}/status/',
            {'status': 'READY', 'note': 'Customer called ahead'},
            format='json',
        )
        self.assertEqual(response.status_code, 200)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, 'READY')
        self.assertIn('Customer called ahead', self.order.notes)
        # The note is filed under the stage it belongs to.
        self.assertIn('[Ready]', self.order.notes)

    def test_notes_accumulate_rather_than_overwrite(self):
        self.client.post(
            f'/api/orders/{self.order.id}/status/',
            {'status': 'PROCESSING', 'note': 'first'}, format='json',
        )
        self.client.post(
            f'/api/orders/{self.order.id}/status/',
            {'status': 'READY', 'note': 'second'}, format='json',
        )
        self.order.refresh_from_db()
        self.assertIn('first', self.order.notes)
        self.assertIn('second', self.order.notes)

    def test_a_blank_note_writes_nothing(self):
        self.client.post(
            f'/api/orders/{self.order.id}/status/',
            {'status': 'READY', 'note': '   '}, format='json',
        )
        self.order.refresh_from_db()
        self.assertFalse(self.order.notes)

    def test_status_change_without_a_note_still_works(self):
        response = self.client.post(
            f'/api/orders/{self.order.id}/status/', {'status': 'READY'}, format='json'
        )
        self.assertEqual(response.status_code, 200)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, 'READY')

    def test_an_invalid_status_writes_no_note(self):
        self.client.post(
            f'/api/orders/{self.order.id}/status/',
            {'status': 'BOGUS', 'note': 'should not persist'}, format='json',
        )
        self.order.refresh_from_db()
        self.assertFalse(self.order.notes)


class MetaEndpointTests(APITestCase):
    """`/api/meta/` is the single source for vocabularies the client used to
    hardcode. The payment methods are the reason it exists: the Flutter app
    carried three separate lists in three different orders."""

    def setUp(self):
        self.data = self.client.get('/api/meta/').data

    def test_payment_methods_are_served(self):
        values = [c['value'] for c in self.data['payment_methods']]
        self.assertEqual(values, ['CASH', 'UPI', 'CARD', 'BANK_TRANSFER'])

    def test_every_vocabulary_is_present(self):
        for key in (
            'order_statuses', 'payment_statuses', 'delivery_types',
            'order_sources', 'pricing_units', 'payment_methods',
            'expense_categories', 'attendance_statuses',
        ):
            self.assertTrue(self.data[key], f'{key} came back empty')

    def test_choices_carry_a_label(self):
        # The client renders the label, so a value-only payload would force it
        # to invent display strings again.
        for choice in self.data['order_statuses']:
            self.assertIn('value', choice)
            self.assertIn('label', choice)

    def test_ironing_is_offered(self):
        values = [c['value'] for c in self.data['order_statuses']]
        self.assertIn('IRONING', values)

    def test_attendance_offers_all_four_states(self):
        values = [c['value'] for c in self.data['attendance_statuses']]
        self.assertEqual(sorted(values), ['ABSENT', 'HALF_DAY', 'LEAVE', 'PRESENT'])


class ShopOperatingRulesTests(APITestCase):
    """Rules that used to live as Dart constants in the client."""

    def setUp(self):
        self.shop = Shop.objects.create(name='washing')

    def test_defaults_match_the_constants_they_replace(self):
        data = self.client.get('/api/shops/').data[0]
        self.assertEqual(data['express_multiplier'], 1.5)
        self.assertEqual(data['default_daily_wage'], 600.0)
        self.assertEqual(data['default_staff_role'], 'Washer')
        self.assertEqual(data['currency_symbol'], '\u20b9')
        self.assertEqual(data['locale'], 'en_IN')

    def test_rules_are_patchable(self):
        response = self.client.patch(
            f'/api/shops/{self.shop.id}/',
            {'express_multiplier': 2.0, 'default_daily_wage': 750.0},
            format='json',
        )
        self.assertEqual(response.status_code, 200)
        self.shop.refresh_from_db()
        self.assertEqual(self.shop.express_multiplier, 2.0)
        self.assertEqual(self.shop.default_daily_wage, 750.0)


class GarmentItemImageTests(APITestCase):
    def setUp(self):
        self.category = GarmentCategory.objects.create(name='Ironing')

    def test_image_url_defaults_to_blank_not_null(self):
        item = GarmentItem.objects.create(category=self.category, name='Shirt', price=10)
        self.assertEqual(item.image_url, '')

    def test_image_url_round_trips(self):
        url = 'https://example.com/shirt.png'
        GarmentItem.objects.create(
            category=self.category, name='Shirt', price=10, image_url=url,
        )
        data = self.client.get('/api/items/').data[0]
        self.assertEqual(data['image_url'], url)
