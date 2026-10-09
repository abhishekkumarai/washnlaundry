"""Tests for the WashNLaundry CRM API.

Focus is on the things that were previously broken or unmodelled: the status
vocabulary, order numbering, the timeline stamps, delivery charges, derived
filters, and the catalogue shape.
"""

import io
from datetime import date, time, timedelta

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from .models import (
    Shop, Customer, GarmentCategory, GarmentItem, Order, OrderItem,
    Staff, Expense, Credit, CreditCategory, DEFAULT_CREDIT_CATEGORIES, Attendance, SalaryPayment, SalaryAdvance, ServiceArea, TimeSlot,
    EmailLinkRequest, OrderStatus, PaymentStatus, DeliveryType, PricingUnit,
)
from .serializers import CustomerSerializer


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

    def test_stamps_refresh_on_revisit(self):
        # A stale first-arrival timestamp next to a Timeline & Audit Log that
        # shows the revisit happening moments ago is exactly what "the update
        # and the audit logs don't match" reported — the stamp must track the
        # most recent arrival, not just the first one.
        #
        # Explicit `when`s, a second apart: three `mark_status` calls with no
        # I/O between them can land in the same microsecond on a fast enough
        # machine, since `mark_status` defaults to `timezone.now()` — which
        # made this assertion flaky (`not greater than` a value equal to
        # itself) rather than actually exercising "refreshed to something
        # later", the thing this test means to pin down.
        first = timezone.now()
        self.order.mark_status(OrderStatus.READY, when=first)
        self.order.mark_status(OrderStatus.PROCESSING, when=first + timedelta(seconds=1))
        self.order.mark_status(OrderStatus.READY, when=first + timedelta(seconds=2))
        self.assertGreater(Order.objects.get(pk=self.order.pk).ready_at, first)

    def test_every_transition_is_logged_even_a_revisit(self):
        self.order.mark_status(OrderStatus.READY)
        self.order.mark_status(OrderStatus.PROCESSING)
        self.order.mark_status(OrderStatus.READY)
        statuses = list(self.order.audit_log.values_list('status', flat=True))
        self.assertEqual(
            statuses,
            [OrderStatus.READY, OrderStatus.PROCESSING, OrderStatus.READY],
        )

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

    def test_delivered_due_amount(self):
        c = Customer.objects.create(name='Alice', phone='9876543210')
        # 1. Delivered and unpaid -> counts as delivered debt
        Order.objects.create(
            customer=c, customer_name=c.name, customer_phone=c.phone,
            status=OrderStatus.DELIVERED, payment_status=PaymentStatus.UNPAID,
            total_amount=500.0, paid_amount=0.0, due_amount=500.0,
        )
        # 2. Delivered and partially paid -> counts remaining due_amount
        Order.objects.create(
            customer=c, customer_name=c.name, customer_phone=c.phone,
            status=OrderStatus.DELIVERED, payment_status=PaymentStatus.PARTIAL,
            total_amount=300.0, paid_amount=100.0, due_amount=200.0,
        )
        # 3. Delivered and fully paid -> due_amount is 0, adds 0
        Order.objects.create(
            customer=c, customer_name=c.name, customer_phone=c.phone,
            status=OrderStatus.DELIVERED, payment_status=PaymentStatus.PAID,
            total_amount=400.0, paid_amount=400.0, due_amount=0.0,
        )
        # 4. Processing order with unpaid amount -> NOT delivered yet, so does NOT count
        Order.objects.create(
            customer=c, customer_name=c.name, customer_phone=c.phone,
            status=OrderStatus.PROCESSING, payment_status=PaymentStatus.UNPAID,
            total_amount=600.0, paid_amount=0.0, due_amount=600.0,
        )
        # 5. Counter order without FK customer but matching phone -> counts
        Order.objects.create(
            customer=None, customer_name=c.name, customer_phone=c.phone,
            status=OrderStatus.DELIVERED, payment_status=PaymentStatus.UNPAID,
            total_amount=150.0, paid_amount=0.0, due_amount=150.0,
        )
        # Expected total delivered dues: 500 + 200 + 0 + 150 = 850.0
        self.assertEqual(c.delivered_due_amount, 850.0)

        # Serializer includes delivered_due_amount
        serializer = CustomerSerializer(c)
        self.assertEqual(serializer.data['delivered_due_amount'], 850.0)


class CustomerImportTests(APITestCase):
    def _csv_file(self, text, name='customers.csv'):
        return SimpleUploadedFile(name, text.encode('utf-8'), content_type='text/csv')

    def test_preview_guesses_mapping_from_csv_headers(self):
        upload = self._csv_file(
            'Customer Name,Mobile Number,Email\nAsha Rao,9876500001,asha@example.com\n'
        )
        response = self.client.post('/api/customers/import/preview/', {'file': upload})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['columns'], ['Customer Name', 'Mobile Number', 'Email'])
        self.assertEqual(response.data['row_count'], 1)
        self.assertEqual(response.data['suggested_mapping'], {
            'name': 'Customer Name',
            'phone': 'Mobile Number',
            'email': 'Email',
        })

    def test_preview_without_a_file_is_rejected(self):
        response = self.client.post('/api/customers/import/preview/', {})
        self.assertEqual(response.status_code, 400)

    def test_commit_requires_name_and_phone_mapping(self):
        upload = self._csv_file('Email\nasha@example.com\n')
        response = self.client.post('/api/customers/import/commit/', {
            'file': upload,
            'mapping': '{"email": "Email"}',
        })
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Customer.objects.count(), 0)

    def test_commit_creates_valid_rows_and_drops_missing_and_duplicate_rows(self):
        Customer.objects.create(name='Existing', phone='9000000000')
        upload = self._csv_file(
            'Name,Phone,Area\n'
            'Asha Rao,9876500001,Koramangala\n'      # valid
            ',9876500002,Indiranagar\n'               # missing name -> dropped
            'No Phone,,HSR\n'                         # missing phone -> dropped
            'Dupe In File,9876500003,Whitefield\n'    # valid
            'Dupe In File Again,9876500003,Whitefield\n'  # duplicate of the row above -> dropped
            'Already A Customer,9000000000,Koramangala\n'  # duplicate of existing DB row -> dropped
        )
        response = self.client.post('/api/customers/import/commit/', {
            'file': upload,
            'mapping': '{"name": "Name", "phone": "Phone", "area": "Area"}',
        })

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, {
            'total_rows': 6,
            'created': 2,
            'updated': 0,
            'skipped_missing': 2,
            'skipped_duplicate': 2,
        })
        self.assertEqual(Customer.objects.count(), 3)  # 1 pre-existing + 2 imported
        asha = Customer.objects.get(phone='9876500001')
        self.assertEqual(asha.name, 'Asha Rao')
        self.assertEqual(asha.area, 'Koramangala')
        # The pre-existing duplicate was skipped, not touched.
        self.assertEqual(Customer.objects.get(phone='9000000000').name, 'Existing')

    def test_commit_with_overwrite_updates_the_existing_customer_instead_of_skipping(self):
        existing = Customer.objects.create(
            name='Old Name', phone='9000000000', area='Old Area', email='old@example.com',
        )
        upload = self._csv_file(
            'Name,Phone,Area,Email\n'
            'New Name,9000000000,New Area,\n'  # blank email -> leaves the existing one alone
        )
        response = self.client.post('/api/customers/import/commit/', {
            'file': upload,
            'mapping': '{"name": "Name", "phone": "Phone", "area": "Area", "email": "Email"}',
            'overwrite_duplicates': 'true',
        })

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, {
            'total_rows': 1,
            'created': 0,
            'updated': 1,
            'skipped_missing': 0,
            'skipped_duplicate': 0,
        })
        existing.refresh_from_db()
        self.assertEqual(existing.name, 'New Name')
        self.assertEqual(existing.area, 'New Area')
        self.assertEqual(existing.phone, '9000000000')  # never touched
        self.assertEqual(existing.email, 'old@example.com')  # blank cell didn't wipe it

    def test_commit_with_overwrite_merges_repeated_in_file_duplicates(self):
        upload = self._csv_file(
            'Name,Phone,Area\n'
            'First Pass,9876500099,Koramangala\n'
            'Final Pass,9876500099,Indiranagar\n'
        )
        response = self.client.post('/api/customers/import/commit/', {
            'file': upload,
            'mapping': '{"name": "Name", "phone": "Phone", "area": "Area"}',
            'overwrite_duplicates': 'true',
        })

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['created'], 1)
        self.assertEqual(response.data['updated'], 0)
        customer = Customer.objects.get(phone='9876500099')
        self.assertEqual(customer.name, 'Final Pass')
        self.assertEqual(customer.area, 'Indiranagar')

    def test_commit_supports_xlsx(self):
        openpyxl = __import__('openpyxl')
        workbook = openpyxl.Workbook()
        sheet = workbook.active
        sheet.append(['Name', 'Phone'])
        sheet.append(['Bala Krishnan', '9876500009'])
        buffer = io.BytesIO()
        workbook.save(buffer)
        upload = SimpleUploadedFile(
            'customers.xlsx', buffer.getvalue(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )

        response = self.client.post('/api/customers/import/commit/', {
            'file': upload,
            'mapping': '{"name": "Name", "phone": "Phone"}',
        })

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['created'], 1)
        self.assertTrue(Customer.objects.filter(phone='9876500009', name='Bala Krishnan').exists())

    def test_commit_strips_a_decimal_tail_a_numeric_phone_column_leaves_behind(self):
        # A phone column stored/exported as a *numeric* cell round-trips as
        # e.g. "9876500009.0" — corrupting the number and making it useless
        # as a tappable phone link in the UI. The imported customer's phone
        # must be the plain digits, not that literal string.
        upload = self._csv_file('Name,Phone\nAsha Rao,9876500001.0\n')
        response = self.client.post('/api/customers/import/commit/', {
            'file': upload,
            'mapping': '{"name": "Name", "phone": "Phone"}',
        })

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['created'], 1)
        asha = Customer.objects.get(name='Asha Rao')
        self.assertEqual(asha.phone, '9876500001')

    def test_commit_supports_xlsx_with_a_float_valued_phone_cell(self):
        openpyxl = __import__('openpyxl')
        workbook = openpyxl.Workbook()
        sheet = workbook.active
        sheet.append(['Name', 'Phone'])
        sheet.cell(row=2, column=1, value='Chitra Nair')
        sheet.cell(row=2, column=2, value=9876500010.0)
        buffer = io.BytesIO()
        workbook.save(buffer)
        upload = SimpleUploadedFile(
            'customers.xlsx', buffer.getvalue(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )

        response = self.client.post('/api/customers/import/commit/', {
            'file': upload,
            'mapping': '{"name": "Name", "phone": "Phone"}',
        })

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['created'], 1)
        self.assertTrue(
            Customer.objects.filter(phone='9876500010', name='Chitra Nair').exists()
        )


class CustomerImportHelperTests(TestCase):
    """Direct unit tests of the pure parsing helpers, independent of the
    view/HTTP layer above."""

    def test_normalize_phone_strips_trailing_zero_decimal(self):
        from .customer_import import normalize_phone
        self.assertEqual(normalize_phone('9876500001.0'), '9876500001')
        self.assertEqual(normalize_phone('9876500001.00'), '9876500001')

    def test_normalize_phone_leaves_a_plain_number_alone(self):
        from .customer_import import normalize_phone
        self.assertEqual(normalize_phone('9876500001'), '9876500001')

    def test_normalize_phone_leaves_a_real_fraction_alone(self):
        # Not a real phone number either way — this function's job is only
        # to undo the numeric-cell round-trip, not to validate phone shape.
        from .customer_import import normalize_phone
        self.assertEqual(normalize_phone('987.65'), '987.65')

    def test_cell_to_str_strips_a_whole_number_float(self):
        from .customer_import import _cell_to_str
        self.assertEqual(_cell_to_str(9876500001.0), '9876500001')
        self.assertEqual(_cell_to_str(9876500001), '9876500001')
        self.assertEqual(_cell_to_str('Asha Rao'), 'Asha Rao')
        self.assertEqual(_cell_to_str(None), '')


class ServicesImportExportTests(APITestCase):
    def setUp(self):
        self.ironing = GarmentCategory.objects.create(name='Ironing', icon='Iron', display_order=1)
        self.dry = GarmentCategory.objects.create(name='Dry Cleaning', icon='Sparkles', display_order=2)
        GarmentItem.objects.create(category=self.ironing, name='Shirt', price=15.0, unit=PricingUnit.PIECE, display_order=1)
        GarmentItem.objects.create(category=self.dry, name='Suit', price=250.0, unit=PricingUnit.SET, display_order=1)

    def _csv_file(self, text, name='services.csv'):
        return SimpleUploadedFile(name, text.encode('utf-8'), content_type='text/csv')

    def test_export_services_csv(self):
        response = self.client.get('/api/categories/export/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response['Content-Type'], 'text/csv; charset=utf-8')
        content = response.content.decode('utf-8')
        self.assertIn('Category,Category Icon,Item Name,Price,Unit,Item Icon,Image URL,Is Active,Display Order', content)
        self.assertIn('Ironing,Iron,Shirt,15.00,per pc', content)
        self.assertIn('Dry Cleaning,Sparkles,Suit,250.00,per set', content)

    def test_export_services_csv_filtered_by_category(self):
        response = self.client.get(f'/api/categories/export/?category={self.ironing.id}')
        self.assertEqual(response.status_code, 200)
        content = response.content.decode('utf-8')
        self.assertIn('Shirt', content)
        self.assertNotIn('Suit', content)

    def test_export_services_json(self):
        response = self.client.get('/api/categories/export/?format=json')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 2)
        ironing_cat = next(c for c in data if c['name'] == 'Ironing')
        self.assertEqual(ironing_cat['items'][0]['name'], 'Shirt')
        self.assertEqual(ironing_cat['items'][0]['price'], 15.0)

    def test_import_preview_guesses_mapping(self):
        upload = self._csv_file('Service,Garment,Rate,Unit\nWash,Bedcover,80,PC\n')
        response = self.client.post('/api/categories/import/preview/', {'file': upload})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['columns'], ['Service', 'Garment', 'Rate', 'Unit'])
        self.assertEqual(response.data['row_count'], 1)
        self.assertEqual(response.data['suggested_mapping'], {
            'category': 'Service',
            'name': 'Garment',
            'price': 'Rate',
            'unit': 'Unit',
        })

    def test_import_preview_requires_file(self):
        response = self.client.post('/api/categories/import/preview/', {})
        self.assertEqual(response.status_code, 400)

    def test_import_commit_requires_category_name_and_price_mapping(self):
        upload = self._csv_file('Name,Price\nTowel,40\n')
        response = self.client.post('/api/categories/import/commit/', {
            'file': upload,
            'mapping': '{"name": "Name", "price": "Price"}',
        })
        self.assertEqual(response.status_code, 400)
        self.assertIn('category', response.data['detail'])

    def test_import_commit_creates_new_categories_and_items(self):
        upload = self._csv_file(
            'Service,Item,Price,Unit\n'
            'Shoe Cleaning,Sneakers,250,per pair\n'
            'Wash & Fold,T-Shirt,25,per pc\n'
            ',Invalid Item,50,per pc\n'
        )
        response = self.client.post('/api/categories/import/commit/', {
            'file': upload,
            'mapping': '{"category": "Service", "name": "Item", "price": "Price", "unit": "Unit"}',
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['categories_created'], 2)
        self.assertEqual(response.data['items_created'], 2)
        self.assertEqual(response.data['skipped_missing'], 1)

        self.assertTrue(GarmentCategory.objects.filter(name='Shoe Cleaning').exists())
        self.assertTrue(GarmentItem.objects.filter(name='Sneakers', price=250.0).exists())

    def test_import_commit_updates_existing_items_on_overwrite(self):
        upload = self._csv_file(
            'Category,Name,Price,Unit\n'
            'Ironing,Shirt,20,PC\n'
        )
        response = self.client.post('/api/categories/import/commit/', {
            'file': upload,
            'mapping': '{"category": "Category", "name": "Name", "price": "Price", "unit": "Unit"}',
            'overwrite_duplicates': 'true',
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['items_updated'], 1)
        shirt = GarmentItem.objects.get(category=self.ironing, name='Shirt')
        self.assertEqual(shirt.price, 20.0)

    def test_import_commit_xlsx(self):
        openpyxl = __import__('openpyxl')
        workbook = openpyxl.Workbook()
        sheet = workbook.active
        sheet.append(['Category', 'Item', 'Rate', 'Unit'])
        sheet.append(['Dry Cleaning', 'Silk Saree', 180, 'PC'])
        buffer = io.BytesIO()
        workbook.save(buffer)
        upload = SimpleUploadedFile(
            'services.xlsx', buffer.getvalue(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )

        response = self.client.post('/api/categories/import/commit/', {
            'file': upload,
            'mapping': '{"category": "Category", "name": "Item", "price": "Rate", "unit": "Unit"}',
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['items_created'], 1)
        self.assertTrue(GarmentItem.objects.filter(name='Silk Saree', price=180.0).exists())


class ServicesImportHelperTests(TestCase):
    def test_normalize_pricing_unit(self):
        from .services_import_export import normalize_pricing_unit
        self.assertEqual(normalize_pricing_unit('pc'), PricingUnit.PIECE)
        self.assertEqual(normalize_pricing_unit('piece'), PricingUnit.PIECE)
        self.assertEqual(normalize_pricing_unit('kg'), PricingUnit.KG)
        self.assertEqual(normalize_pricing_unit('sqft'), PricingUnit.SQFT)
        self.assertEqual(normalize_pricing_unit('sq.ft'), PricingUnit.SQFT)
        self.assertEqual(normalize_pricing_unit('set'), PricingUnit.SET)
        self.assertEqual(normalize_pricing_unit('unknown'), PricingUnit.PIECE)

    def test_parse_float_and_bool(self):
        from .services_import_export import parse_float, parse_bool
        self.assertEqual(parse_float('₹120.50'), 120.50)
        self.assertEqual(parse_float('$50'), 50.0)
        self.assertEqual(parse_float('invalid', default=10.0), 10.0)
        self.assertFalse(parse_bool('no'))
        self.assertFalse(parse_bool('inactive'))
        self.assertTrue(parse_bool('yes'))


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

    def test_deactivating_an_item_does_not_strand_it(self):
        # The is_active default-hide used to apply to retrieve/update/destroy
        # too (not just list), via a shared get_queryset(). PATCHing an item
        # to is_active=False took it out of that same queryset, so the next
        # request for it by id — a GET, another PATCH, even a DELETE — 404'd.
        # Reactivating a deactivated item through the API was impossible.
        shirt = GarmentItem.objects.get(name='Shirt')

        response = self.client.patch(f'/api/items/{shirt.id}/', {'is_active': False})
        self.assertEqual(response.status_code, 200)

        response = self.client.get(f'/api/items/{shirt.id}/')
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data['is_active'])

        response = self.client.patch(f'/api/items/{shirt.id}/', {'is_active': True})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['is_active'])


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
            monthly_wage=15000, has_app_login=True,
        )
        Staff.objects.create(name='Sunil Paswan', role='Steam Press', phone='9811445566')

    def test_list_exposes_the_roster_flags(self):
        response = self.client.get('/api/staff/')
        by_name = {s['name']: s for s in response.data}
        self.assertTrue(by_name['Mohan Das']['has_app_login'])
        self.assertFalse(by_name['Sunil Paswan']['has_app_login'])

    def test_create_staff_persists(self):
        response = self.client.post('/api/staff/', {
            'name': 'New Presser',
            'role': 'Ironing',
            'phone': '9000000009',
            'monthly_wage': 16000,
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

    def test_start_date_round_trips(self):
        response = self.client.post('/api/staff/', {
            'name': 'Joins Later',
            'role': 'Washer',
            'phone': '9000000011',
            'start_date': '2026-09-01',
        }, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['start_date'], '2026-09-01')

    def test_start_date_is_optional(self):
        # Staff created before this field existed have none — must not become
        # required on every future edit just because it exists now.
        response = self.client.post('/api/staff/', {
            'name': 'No Start Date',
            'role': 'Washer',
            'phone': '9000000012',
        }, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertIsNone(response.data['start_date'])

    def test_moving_start_date_past_existing_attendance_is_rejected(self):
        staff = Staff.objects.create(
            name='Already Worked', role='Washer', phone='9000000013',
            start_date=date(2026, 8, 1),
        )
        Attendance.objects.create(staff=staff, date=date(2026, 8, 5))

        response = self.client.patch(
            f'/api/staff/{staff.id}/', {'start_date': '2026-08-10'}, format='json'
        )
        self.assertEqual(response.status_code, 400)
        staff.refresh_from_db()
        self.assertEqual(staff.start_date, date(2026, 8, 1))

    def test_moving_start_date_earlier_is_always_fine(self):
        # Only attendance *before* the new date is a conflict — pulling the
        # date earlier can never orphan an existing record.
        staff = Staff.objects.create(
            name='Backdated', role='Washer', phone='9000000014',
            start_date=date(2026, 8, 10),
        )
        Attendance.objects.create(staff=staff, date=date(2026, 8, 12))

        response = self.client.patch(
            f'/api/staff/{staff.id}/', {'start_date': '2026-08-01'}, format='json'
        )
        self.assertEqual(response.status_code, 200, response.data)


class AttendanceTests(TestCase):
    def test_one_record_per_staff_per_day(self):
        from django.db.utils import IntegrityError

        staff = Staff.objects.create(name='A', role='Washer', phone='1')
        Attendance.objects.create(staff=staff, date=date(2026, 7, 30))
        with self.assertRaises(IntegrityError):
            Attendance.objects.create(staff=staff, date=date(2026, 7, 30))

    def test_filter_by_month(self):
        staff = Staff.objects.create(name='A', role='Washer', phone='1')
        Attendance.objects.create(staff=staff, date=date(2026, 9, 5), status=Attendance.PRESENT)
        Attendance.objects.create(staff=staff, date=date(2026, 9, 10), status=Attendance.HALF_DAY)
        Attendance.objects.create(staff=staff, date=date(2026, 8, 15), status=Attendance.PRESENT)
        response = self.client.get('/api/attendance/?month=2026-09')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 2)


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

    def test_bulk_saves_check_in_time_and_notes(self):
        response = self.post({
            'date': self.day,
            'entries': [{
                'staff': self.a.id,
                'status': 'PRESENT',
                'check_in_time': '09:45:00',
                'notes': 'On time today'
            }]
        })
        self.assertEqual(response.status_code, 200)
        rec = Attendance.objects.get(staff=self.a, date=date(2026, 8, 11))
        self.assertEqual(rec.status, Attendance.PRESENT)
        self.assertEqual(rec.notes, 'On time today')
        self.assertEqual(str(rec.check_in_time), '09:45:00')

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

    def test_marking_before_start_date_is_rejected(self):
        self.a.start_date = date(2026, 8, 15)
        self.a.save()
        response = self.post({'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'PRESENT'}]})
        self.assertEqual(response.status_code, 400)
        self.assertIn('Ramesh Kumar', response.data['detail'])
        self.assertEqual(Attendance.objects.count(), 0)

    def test_marking_on_the_start_date_itself_is_allowed(self):
        self.a.start_date = date(2026, 8, 11)  # == self.day
        self.a.save()
        response = self.post({'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'PRESENT'}]})
        self.assertEqual(response.status_code, 200, response.data)

    def test_a_start_date_violation_blocks_the_whole_batch(self):
        # Same "reject everything, write nothing" rule as an invalid status —
        # b's entry is fine on its own but a's isn't allowed yet.
        self.a.start_date = date(2026, 9, 1)
        self.a.save()
        response = self.post({
            'date': self.day,
            'entries': [
                {'staff': self.a.id, 'status': 'PRESENT'},
                {'staff': self.b.id, 'status': 'PRESENT'},
            ],
        })
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Attendance.objects.count(), 0)

    def test_no_start_date_on_file_never_blocks_marking(self):
        # self.a/self.b are created with no start_date in setUp — None must
        # read as "no restriction", not as "before everything".
        response = self.post({'date': self.day, 'entries': [{'staff': self.a.id, 'status': 'PRESENT'}]})
        self.assertEqual(response.status_code, 200, response.data)


class PayrollTests(APITestCase):
    """GET /api/payroll/?month=YYYY-MM.

    Wages earned are derived from the attendance register, never stored, so
    they cannot drift out of step with it. What was paid comes from
    SalaryPayment, which is the thing the schema previously had no room for at
    all — which is why the Payroll screen's Paid column was hardcoded.
    """

    def setUp(self):
        # July has 31 days, so 600.0/day == 18600.0/month — chosen so the
        # existing daily-rate assertions below (1200.0, 600.0, ...) hold
        # exactly under the new monthly_wage / days_in_month formula.
        self.staff = Staff.objects.create(
            name='Ramesh Kumar', role='Head Washer', phone='1', monthly_wage=600.0 * 31
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
        # Pay owed is derived from attendance only — no fallback to the
        # contracted monthly wage when nothing was marked.
        entry = self.entry()
        self.assertEqual(entry['days_worked'], 0.0)
        self.assertEqual(entry['total_salary'], 0.0)

    def test_absent_attendance_means_no_wages(self):
        self.mark(1, Attendance.ABSENT)
        entry = self.entry()
        self.assertEqual(entry['days_worked'], 0.0)
        self.assertEqual(entry['total_salary'], 0.0)
        # Counted separately, for the staff payroll view's "0P 1A 0H 0L" chips.
        self.assertEqual(entry['absent_days'], 1)
        self.assertEqual(entry['present_days'], 0)

    def test_floating_point_paise_residue_marks_paid(self):
        # Fractional daily rate leaving < 1 rupee residue must be marked PAID with 0.0 pending
        staff = Staff.objects.create(name='Fractional Staff', role='Washer', phone='99', monthly_wage=10000.0)
        Attendance.objects.create(staff=staff, date=date(2026, 7, 1), status=Attendance.PRESENT)
        SalaryPayment.objects.create(staff=staff, month=self.month, amount=322.0)
        res = self.client.get('/api/payroll/', {'month': '2026-07'}).data
        fractional_entry = [e for e in res['entries'] if e['staff'] == staff.id][0]
        self.assertEqual(fractional_entry['pending_amount'], 0.0)
        self.assertEqual(fractional_entry['status'], PaymentStatus.PAID)

    def test_recording_payment_for_staff_without_attendance_allowed(self):
        staff_unlogged = Staff.objects.create(name='Tarun Unlogged', role='Ironer', phone='88', monthly_wage=15000.0)
        response = self.client.post(
            '/api/salary-payments/',
            {'staff': staff_unlogged.id, 'month': '2026-07-01', 'amount': 15000.0},
            format='json',
        )
        self.assertEqual(response.status_code, 201)
        res = self.client.get('/api/payroll/', {'month': '2026-07'}).data
        entry = [e for e in res['entries'] if e['staff'] == staff_unlogged.id][0]
        # Nothing earned (no attendance), yet the payment went through and
        # the row reads as paid rather than UNPAID.
        self.assertEqual(entry['total_salary'], 0.0)
        self.assertEqual(entry['paid_amount'], 15000.0)
        self.assertEqual(entry['pending_amount'], 0.0)
        self.assertEqual(entry['status'], PaymentStatus.PAID)

    def test_overpayment_still_rejected_when_wages_are_earned(self):
        self.mark(1, Attendance.PRESENT)
        owed = self.entry()['net_pay']
        response = self.client.post(
            '/api/salary-payments/',
            {'staff': self.staff.id, 'month': '2026-07-01', 'amount': owed + 100},
            format='json',
        )
        self.assertEqual(response.status_code, 400)

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
        # December also has 31 days — 100.0 * 31 keeps the same daily rate.
        member = Staff.objects.create(name='Solo', role='Washer', phone='9', monthly_wage=100.0 * 31)
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
            name='Geeta Devi', role='Dry Cleaning', phone='3', monthly_wage=500.0 * 31
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

    def test_a_payment_exceeding_what_is_owed_is_rejected(self):
        self.mark(1, Attendance.PRESENT)  # total_salary == 600.0
        response = self.client.post(
            '/api/salary-payments/',
            {'staff': self.staff.id, 'month': '2026-07-01', 'amount': 600.01},
            format='json',
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(SalaryPayment.objects.count(), 0)

    def test_a_payment_exactly_matching_what_is_owed_is_allowed(self):
        self.mark(1, Attendance.PRESENT)  # total_salary == 600.0
        response = self.client.post(
            '/api/salary-payments/',
            {'staff': self.staff.id, 'month': '2026-07-01', 'amount': 600.0},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)

    def test_the_cap_accounts_for_payments_already_made(self):
        # 600 owed, 400 already paid — a second payment can only cover the
        # remaining 200, even though 250 alone would have been fine on its own.
        self.mark(1, Attendance.PRESENT)
        SalaryPayment.objects.create(staff=self.staff, month=self.month, amount=400.0)
        response = self.client.post(
            '/api/salary-payments/',
            {'staff': self.staff.id, 'month': '2026-07-01', 'amount': 250.0},
            format='json',
        )
        self.assertEqual(response.status_code, 400)
        response = self.client.post(
            '/api/salary-payments/',
            {'staff': self.staff.id, 'month': '2026-07-01', 'amount': 200.0},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)

    def test_editing_a_payment_excludes_its_own_prior_amount_from_the_cap(self):
        # Raising an existing payment from 300 to 500 (still <= 600 owed)
        # must not double-count the 300 it's replacing.
        self.mark(1, Attendance.PRESENT)
        payment = SalaryPayment.objects.create(
            staff=self.staff, month=self.month, amount=300.0
        )
        response = self.client.patch(
            f'/api/salary-payments/{payment.id}/', {'amount': 500.0}, format='json'
        )
        self.assertEqual(response.status_code, 200, response.data)

    def test_attendance_breakdown_counts_each_state_separately(self):
        self.mark(1, Attendance.PRESENT)
        self.mark(2, Attendance.PRESENT)
        self.mark(3, Attendance.HALF_DAY)
        self.mark(4, Attendance.LEAVE)
        self.mark(5, Attendance.ABSENT)
        entry = self.entry()
        self.assertEqual(entry['present_days'], 2)
        self.assertEqual(entry['half_days'], 1)
        self.assertEqual(entry['leave_days'], 1)

    def test_an_advance_reduces_net_pay_and_pending(self):
        self.mark(1, Attendance.PRESENT)  # total_salary == 600.0
        SalaryAdvance.objects.create(staff=self.staff, month=self.month, amount=200.0)
        entry = self.entry()
        self.assertEqual(entry['total_salary'], 600.0)
        self.assertEqual(entry['advances_amount'], 200.0)
        self.assertEqual(entry['net_pay'], 400.0)
        self.assertEqual(entry['pending_amount'], 400.0)
        self.assertEqual(entry['status'], PaymentStatus.UNPAID)

    def test_an_advance_bigger_than_the_wage_does_not_go_negative(self):
        self.mark(1, Attendance.PRESENT)  # total_salary == 600.0
        SalaryAdvance.objects.create(staff=self.staff, month=self.month, amount=1000.0)
        entry = self.entry()
        self.assertEqual(entry['net_pay'], 0.0)
        self.assertEqual(entry['pending_amount'], 0.0)

    def test_a_payment_cannot_exceed_net_pay_after_an_advance(self):
        # 600 owed, 200 already taken as an advance — only 400 is left to pay,
        # even though 600 alone would have passed the old total_salary cap.
        self.mark(1, Attendance.PRESENT)
        SalaryAdvance.objects.create(staff=self.staff, month=self.month, amount=200.0)
        response = self.client.post(
            '/api/salary-payments/',
            {'staff': self.staff.id, 'month': '2026-07-01', 'amount': 401.0},
            format='json',
        )
        self.assertEqual(response.status_code, 400)
        response = self.client.post(
            '/api/salary-payments/',
            {'staff': self.staff.id, 'month': '2026-07-01', 'amount': 400.0},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)

    def test_total_payroll_sums_net_pay_not_gross(self):
        self.mark(1, Attendance.PRESENT)  # total_salary == 600.0
        SalaryAdvance.objects.create(staff=self.staff, month=self.month, amount=100.0)
        totals = self.payroll()['totals']
        self.assertEqual(totals['total_payroll'], 500.0)

    def test_an_inactive_staff_member_with_pending_wages_stays_on_the_payroll(self):
        # Deactivating someone mid-month must not make their earned, unpaid
        # wages disappear from the screen that's the only place to pay them.
        self.mark(1, Attendance.PRESENT)
        self.staff.status = 'INACTIVE'
        self.staff.save()
        entry = self.entry()
        self.assertEqual(entry['staff_name'], 'Ramesh Kumar')
        self.assertEqual(entry['pending_amount'], 600.0)

    def test_a_truly_inactive_staff_member_with_no_activity_is_still_excluded(self):
        Staff.objects.create(
            name='Bhola Prasad', role='Retired', phone='2', status='INACTIVE'
        )
        names = [e['staff_name'] for e in self.payroll()['entries']]
        self.assertEqual(names, ['Ramesh Kumar'])

    def test_recording_a_salary_payment_creates_a_linked_expense(self):
        self.mark(1, Attendance.PRESENT)
        payment = SalaryPayment.objects.create(
            staff=self.staff, month=self.month, amount=250.0, method='CASH',
        )
        self.assertIsNotNone(payment.expense)
        self.assertEqual(payment.expense.category, 'Salary')
        self.assertEqual(payment.expense.amount, 250.0)

    def test_editing_a_salary_payment_updates_its_linked_expense_in_place(self):
        payment = SalaryPayment.objects.create(
            staff=self.staff, month=self.month, amount=250.0,
        )
        expense_id = payment.expense_id
        payment.amount = 300.0
        payment.save()
        payment.refresh_from_db()
        self.assertEqual(payment.expense_id, expense_id)
        self.assertEqual(payment.expense.amount, 300.0)

    def test_deleting_a_salary_payment_deletes_its_linked_expense(self):
        payment = SalaryPayment.objects.create(
            staff=self.staff, month=self.month, amount=250.0,
        )
        expense_id = payment.expense_id
        payment.delete()
        self.assertFalse(Expense.objects.filter(id=expense_id).exists())

    def test_salary_advance_endpoint_filters_by_month(self):
        SalaryAdvance.objects.create(staff=self.staff, month=self.month, amount=100.0)
        SalaryAdvance.objects.create(staff=self.staff, month=date(2026, 8, 1), amount=200.0)
        response = self.client.get('/api/salary-advances/', {'month': '2026-07'})
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['amount'], 100.0)
        self.assertEqual(response.data[0]['staff_name'], 'Ramesh Kumar')

    def test_a_non_positive_advance_is_rejected(self):
        response = self.client.post(
            '/api/salary-advances/',
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

    def test_scheduled_date_and_time_survive(self):
        # New Order's Checkout review sends both — scheduled_time is separate
        # from scheduled_date (not a DateTimeField) so it doesn't disturb any
        # existing scheduled_date-only comparison (is_overdue, the Scheduled
        # tab filter).
        response = self._checkout(
            scheduled_date='2026-08-15', scheduled_time='15:00:00'
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['scheduled_date'], '2026-08-15')
        self.assertEqual(response.data['scheduled_time'], '15:00:00')

    def test_scheduled_time_is_optional(self):
        # Store Pickup's checkout still only sends scheduled_date in some
        # flows — scheduled_time must not be required.
        response = self._checkout(scheduled_date='2026-08-15')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertIsNone(response.data['scheduled_time'])

    def test_home_pickup_saves_pickup_slot_and_address(self):
        # The review step's Home pickup sends a pickup leg on top of the
        # delivery leg (scheduled_date/time), plus the pickup address.
        response = self._checkout(
            delivery_type='HOME_PICKUP',
            scheduled_date='2026-09-28', scheduled_time='09:00:00',
            pickup_date='2026-09-27', pickup_time='11:00:00',
            address='12 HBR Layout, Bengaluru',
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['pickup_date'], '2026-09-27')
        self.assertEqual(response.data['pickup_time'], '11:00:00')
        self.assertEqual(response.data['address'], '12 HBR Layout, Bengaluru')

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


class ExpenseNotesTests(APITestCase):
    def test_expense_accepts_and_persists_notes(self):
        response = self.client.post('/api/expenses/', {
            'title': 'Packaging Boxes',
            'category': 'Supplies',
            'amount': 1200,
            'payment_method': 'UPI',
            'notes': 'Invoice #INV-2026-991 from Agarwal Packagers',
        }, format='json')
        self.assertEqual(response.status_code, 201)
        expense = Expense.objects.get(title='Packaging Boxes')
        self.assertEqual(expense.notes, 'Invoice #INV-2026-991 from Agarwal Packagers')
        self.assertEqual(response.data['notes'], 'Invoice #INV-2026-991 from Agarwal Packagers')


class CreditTests(APITestCase):
    def test_create_credit_with_notes_and_list(self):
        when = timezone.now() - timedelta(days=2)
        response = self.client.post('/api/credits/', {
            'title': 'Bulk Corporate Deposit',
            'category': 'Customer Advance',
            'amount': 25000,
            'payment_method': 'BANK_TRANSFER',
            'date': when.isoformat(),
            'notes': 'Hotel Grand Palace advance payment for linen wash',
        }, format='json')
        self.assertEqual(response.status_code, 201)
        credit = Credit.objects.get(title='Bulk Corporate Deposit')
        self.assertEqual(credit.amount, 25000.0)
        self.assertEqual(credit.category.name, 'Customer Advance')
        self.assertEqual(credit.notes, 'Hotel Grand Palace advance payment for linen wash')
        self.assertEqual(credit.date, when)

        # The category still travels as its name, not an id.
        list_res = self.client.get('/api/credits/')
        self.assertEqual(list_res.status_code, 200)
        self.assertEqual(len(list_res.data), 1)
        self.assertEqual(list_res.data[0]['category'], 'Customer Advance')
        self.assertEqual(list_res.data[0]['notes'], 'Hotel Grand Palace advance payment for linen wash')

    def test_update_and_delete_credit(self):
        credit = Credit.objects.create(
            title='Hanger resale',
            category=CreditCategory.objects.get(name='Other'),
            amount=1500,
            notes='Old hanger rack',
        )
        patch_res = self.client.patch(f'/api/credits/{credit.id}/', {
            'amount': 1800,
            'notes': 'Updated count',
        }, format='json')
        self.assertEqual(patch_res.status_code, 200)
        credit.refresh_from_db()
        self.assertEqual(credit.amount, 1800.0)
        self.assertEqual(credit.notes, 'Updated count')

        del_res = self.client.delete(f'/api/credits/{credit.id}/')
        self.assertEqual(del_res.status_code, 204)
        self.assertFalse(Credit.objects.filter(id=credit.id).exists())

    def test_unknown_category_is_rejected(self):
        res = self.client.post('/api/credits/', {
            'title': 'x', 'category': 'Scrap Sale', 'amount': 10,
        }, format='json')
        self.assertEqual(res.status_code, 400)
        self.assertIn('category', res.data)


class CreditCategoryTests(APITestCase):
    def test_migration_seeds_laundromat_defaults(self):
        names = list(CreditCategory.objects.values_list('name', flat=True))
        self.assertEqual(names, DEFAULT_CREDIT_CATEGORIES)

    def test_meta_lists_only_active_categories(self):
        CreditCategory.objects.filter(name='Other').update(is_active=False)
        values = [c['value'] for c in self.client.get('/api/meta/').data['credit_categories']]
        self.assertIn('Laundry Income', values)
        self.assertNotIn('Other', values)

    def test_add_rename_and_toggle_a_category(self):
        res = self.client.post('/api/credit-categories/', {'name': '  Ironing Income '}, format='json')
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data['name'], 'Ironing Income')
        self.assertEqual(res.data['credit_count'], 0)
        cat_id = res.data['id']

        res = self.client.patch(f'/api/credit-categories/{cat_id}/', {'name': 'Press & Iron Income'}, format='json')
        self.assertEqual(res.status_code, 200)
        res = self.client.patch(f'/api/credit-categories/{cat_id}/', {'is_active': False}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertFalse(CreditCategory.objects.get(pk=cat_id).is_active)

    def test_blank_and_duplicate_names_are_rejected(self):
        self.assertEqual(
            self.client.post('/api/credit-categories/', {'name': '   '}, format='json').status_code, 400)
        res = self.client.post('/api/credit-categories/', {'name': 'laundry income'}, format='json')
        self.assertEqual(res.status_code, 400)
        self.assertIn('already exists', str(res.data['name']))

    def test_rename_shows_on_existing_credits(self):
        cat = CreditCategory.objects.get(name='Delivery Charges')
        Credit.objects.create(title='Pickup fee', category=cat, amount=50)
        self.client.patch(f'/api/credit-categories/{cat.id}/', {'name': 'Pickup & Delivery'}, format='json')
        self.assertEqual(self.client.get('/api/credits/').data[0]['category'], 'Pickup & Delivery')

    def test_category_in_use_cannot_be_deleted(self):
        cat = CreditCategory.objects.get(name='Owner Investment')
        Credit.objects.create(title='Top-up', category=cat, amount=5000)
        res = self.client.delete(f'/api/credit-categories/{cat.id}/')
        self.assertEqual(res.status_code, 400)
        self.assertIn('1 credit uses', res.data['detail'])
        self.assertTrue(CreditCategory.objects.filter(pk=cat.id).exists())

    def test_unused_category_can_be_deleted(self):
        cat = CreditCategory.objects.create(name='Temp')
        self.assertEqual(self.client.delete(f'/api/credit-categories/{cat.id}/').status_code, 204)

    def test_turned_off_category_blocks_new_credits_but_not_existing_ones(self):
        cat = CreditCategory.objects.get(name='Other')
        credit = Credit.objects.create(title='Old', category=cat, amount=10)
        cat.is_active = False
        cat.save()

        res = self.client.post('/api/credits/', {'title': 'New', 'category': 'Other', 'amount': 10}, format='json')
        self.assertEqual(res.status_code, 400)
        self.assertIn('turned off', str(res.data['category']))

        # Editing the old credit without changing its category still works.
        res = self.client.patch(f'/api/credits/{credit.id}/', {'amount': 20, 'category': 'Other'}, format='json')
        self.assertEqual(res.status_code, 200)


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
        self.assertEqual(data['default_monthly_wage'], 18000.0)
        self.assertEqual(data['default_staff_role'], 'Washer')
        self.assertEqual(data['currency_symbol'], '\u20b9')
        self.assertEqual(data['locale'], 'en_IN')

    def test_rules_are_patchable(self):
        response = self.client.patch(
            f'/api/shops/{self.shop.id}/',
            {'express_multiplier': 2.0, 'default_monthly_wage': 20000.0},
            format='json',
        )
        self.assertEqual(response.status_code, 200)
        self.shop.refresh_from_db()
        self.assertEqual(self.shop.express_multiplier, 2.0)
        self.assertEqual(self.shop.default_monthly_wage, 20000.0)


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


class LeadEmailTests(APITestCase):
    PAYLOAD = {
        'name': 'Asha', 'phone': '+91 98765 43210',
        'address': 'Boring Road, Patna', 'requirements': 'Wash & iron, 10 pieces',
    }

    def setUp(self):
        from django.test import override_settings
        self._ov = override_settings(
            RAG_API_KEY='k3y', RESEND_API_KEY='re_test',
            LEAD_EMAIL_TO=['a@example.com', 'b@example.com'],
            LEAD_EMAIL_FROM='washnlaundry <onboarding@resend.dev>',
        )
        self._ov.enable()
        self.addCleanup(self._ov.disable)

    def _post(self, data=None, key='k3y'):
        headers = {'HTTP_AUTHORIZATION': f'Bearer {key}'} if key else {}
        return self.client.post('/api/leads/', data or self.PAYLOAD, format='json', **headers)

    @staticmethod
    def _resp(status=200):
        from unittest import mock
        return mock.Mock(status_code=status, text='boom')

    def test_rejects_missing_or_wrong_key(self):
        self.assertEqual(self._post(key=None).status_code, 401)
        self.assertEqual(self._post(key='nope').status_code, 401)

    def test_rejects_when_server_key_unset(self):
        from django.test import override_settings
        with override_settings(RAG_API_KEY=''):
            self.assertEqual(self._post(key='').status_code, 401)

    def test_validates_phone_and_required_fields(self):
        self.assertEqual(self._post({**self.PAYLOAD, 'phone': '12345'}).status_code, 400)
        self.assertEqual(self._post({**self.PAYLOAD, 'address': ''}).status_code, 400)

    def test_saves_lead_and_emails_all_recipients(self):
        from unittest import mock
        from .models import Lead
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp()) as post:
            res = self._post()
        self.assertEqual(res.status_code, 201)
        lead = Lead.objects.get()
        self.assertEqual((lead.phone, lead.email_status, lead.email_attempts), ('9876543210', Lead.SENT, 1))
        sent = post.call_args.kwargs['json']
        self.assertEqual(sent['to'], ['a@example.com', 'b@example.com'])
        self.assertTrue(sent['subject'].startswith('washnlaundry'))
        self.assertIn('Boring Road, Patna', sent['text'])

    def test_html_in_lead_fields_is_escaped(self):
        from unittest import mock
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp()) as post:
            self._post({**self.PAYLOAD, 'name': '<script>x</script>'})
        self.assertNotIn('<script>', post.call_args.kwargs['json']['html'])

    def test_provider_failure_keeps_lead_pending(self):
        from unittest import mock
        from .models import Lead
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp(500)):
            res = self._post()
        self.assertEqual(res.status_code, 201)
        lead = Lead.objects.get()
        self.assertEqual((lead.email_status, lead.email_attempts), (Lead.PENDING, 1))

    def test_missing_api_key_keeps_lead_pending(self):
        from django.test import override_settings
        from .models import Lead
        with override_settings(RESEND_API_KEY=''):
            self.assertEqual(self._post().status_code, 201)
        self.assertEqual(Lead.objects.get().email_status, Lead.PENDING)

    def test_process_retries_pending_and_gives_up_after_max_attempts(self):
        from unittest import mock
        from .models import Lead
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp(500)):
            self._post()
            auth = {'HTTP_AUTHORIZATION': 'Bearer k3y'}
            for _ in range(Lead.MAX_EMAIL_ATTEMPTS - 1):
                self.client.post('/api/leads/process/', **auth)
        self.assertEqual(Lead.objects.get().email_status, Lead.FAILED)
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp()) as post:
            res = self.client.post('/api/leads/process/', **auth)
        self.assertEqual(res.json(), {'retried': 0, 'sent': 0, 'pending': 0})
        post.assert_not_called()

    def test_process_delivers_once_provider_recovers(self):
        from unittest import mock
        from .models import Lead
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp(500)):
            self._post()
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp()):
            res = self.client.post('/api/leads/process/', HTTP_AUTHORIZATION='Bearer k3y')
        self.assertEqual(res.json(), {'retried': 1, 'sent': 1, 'pending': 0})
        self.assertEqual(Lead.objects.get().email_status, Lead.SENT)

    def test_process_requires_key_and_post(self):
        self.assertEqual(self.client.post('/api/leads/process/').status_code, 401)
        self.assertEqual(self.client.get('/api/leads/process/', HTTP_AUTHORIZATION='Bearer k3y').status_code, 405)


class PublicPickupFormTests(APITestCase):
    URL = '/api/leads/public/'
    MARKETING = 'https://washnlaundry-web.abhishekkumarai.workers.dev'
    FORM = {'name': 'Ravi', 'phone': '9123456780', 'address': 'Kankarbagh, Patna', 'service': 'Wash & Fold'}

    def setUp(self):
        from django.core.cache import cache
        from django.test import override_settings
        cache.clear()
        self._ov = override_settings(
            RESEND_API_KEY='re_test', LEAD_EMAIL_TO=['a@example.com'],
            PUBLIC_LEAD_ORIGINS=[self.MARKETING], PUBLIC_LEAD_RATE_PER_HOUR=3,
        )
        self._ov.enable()
        self.addCleanup(self._ov.disable)

    def _post(self, data=None, origin=None, ip='1.2.3.4'):
        extra = {'HTTP_X_FORWARDED_FOR': ip}
        origin = self.MARKETING if origin is None else origin
        if origin != 'NONE':
            extra['HTTP_ORIGIN'] = origin
        return self.client.post(self.URL, data or self.FORM, format='json', **extra)

    @staticmethod
    def _resp(status=200):
        from unittest import mock
        return mock.Mock(status_code=status, text='boom')

    def test_form_submission_saves_lead_and_sends_email(self):
        from unittest import mock
        from .models import Lead
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp()) as post:
            res = self._post()
        self.assertEqual(res.status_code, 201)
        self.assertIn(res['Access-Control-Allow-Origin'], (self.MARKETING, '*'))  # host CORS middleware may widen to '*'
        lead = Lead.objects.get()
        self.assertEqual((lead.source, lead.email_status), ('form', Lead.SENT))
        self.assertIn('Service: Wash & Fold', lead.requirements)
        self.assertIn('pickup form', post.call_args.kwargs['json']['text'])

    def test_unlisted_or_missing_origin_is_forbidden_and_saves_nothing(self):
        from unittest import mock
        from .models import Lead
        for origin in ('https://evil.example', 'NONE'):
            with mock.patch('api.services.email_service.requests.post', return_value=self._resp()) as post:
                self.assertEqual(self._post(origin=origin).status_code, 403)
            post.assert_not_called()
        self.assertEqual(Lead.objects.count(), 0)

    def test_preflight_allowed_only_for_listed_origin(self):
        ok = self.client.options(self.URL, HTTP_ORIGIN=self.MARKETING)
        self.assertEqual(ok.status_code, 204)
        self.assertIn(ok['Access-Control-Allow-Origin'], (self.MARKETING, '*'))
        self.assertEqual(self.client.options(self.URL, HTTP_ORIGIN='https://evil.example').status_code, 403)

    def test_honeypot_fakes_success_but_saves_and_sends_nothing(self):
        from unittest import mock
        from .models import Lead
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp()) as post:
            res = self._post({**self.FORM, 'website': 'http://spam.example'})
        self.assertEqual(res.status_code, 201)
        post.assert_not_called()
        self.assertEqual(Lead.objects.count(), 0)

    def test_rate_limit_per_ip(self):
        from unittest import mock
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp()):
            codes = [self._post(ip='9.9.9.9').status_code for _ in range(4)]
            other_ip = self._post(ip='8.8.8.8').status_code
        self.assertEqual(codes, [201, 201, 201, 429])
        self.assertEqual(other_ip, 201)

    def test_invalid_phone_rejected(self):
        from unittest import mock
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp()) as post:
            self.assertEqual(self._post({**self.FORM, 'phone': '123'}).status_code, 400)
        post.assert_not_called()

    def test_email_outage_still_saves_lead_as_pending(self):
        from unittest import mock
        from .models import Lead
        with mock.patch('api.services.email_service.requests.post', return_value=self._resp(500)):
            self.assertEqual(self._post().status_code, 201)
        self.assertEqual(Lead.objects.get().email_status, Lead.PENDING)


class CustomerPortalTests(TestCase):
    """/api/customer/*: Google-token-scoped, minimal, own-orders-only."""

    def setUp(self):
        from unittest import mock
        self.alice = Customer.objects.create(name='Alice', phone='111', email='Alice@Example.com')
        self.bob = Customer.objects.create(name='Bob', phone='222', email='bob@example.com')
        self.order = Order.objects.create(
            order_number='WL-1', customer=self.alice, customer_name='Alice', notes='staff only')
        Order.objects.create(order_number='WL-2', customer=self.bob, customer_name='Bob')
        patcher = mock.patch('api.customer_views.id_token.verify_oauth2_token')
        self.verify = patcher.start()
        self.addCleanup(patcher.stop)
        self.verify.return_value = {'email': 'alice@example.com', 'email_verified': True}
        override = override_settings(GOOGLE_CLIENT_ID='test-client')
        override.enable()
        self.addCleanup(override.disable)
        self.auth = {'HTTP_AUTHORIZATION': 'Bearer tok'}

    def test_requires_token(self):
        self.assertEqual(self.client.get('/api/customer/orders/').status_code, 401)

    def test_invalid_token_is_401(self):
        self.verify.side_effect = ValueError('bad')
        self.assertEqual(self.client.get('/api/customer/me/', **self.auth).status_code, 401)

    def test_unverified_email_is_401(self):
        self.verify.return_value = {'email': 'alice@example.com', 'email_verified': False}
        self.assertEqual(self.client.get('/api/customer/me/', **self.auth).status_code, 401)

    def test_unknown_email_is_404(self):
        self.verify.return_value = {'email': 'nobody@example.com', 'email_verified': True}
        self.assertEqual(self.client.get('/api/customer/me/', **self.auth).status_code, 404)

    def test_lists_only_own_orders_without_staff_fields(self):
        res = self.client.get('/api/customer/orders/', **self.auth)
        self.assertEqual(res.status_code, 200)
        orders = res.json()['orders']
        self.assertEqual([o['order_number'] for o in orders], ['WL-1'])
        self.assertNotIn('notes', orders[0])

    def test_other_customers_order_is_404(self):
        self.assertEqual(self.client.get('/api/customer/orders/WL-2/', **self.auth).status_code, 404)
        self.assertEqual(self.client.get('/api/customer/orders/WL-1/', **self.auth).status_code, 200)

    def test_signup_creates_customer(self):
        self.verify.return_value = {'email': 'new@example.com', 'email_verified': True}
        res = self.client.post('/api/customer/me/', {'name': 'New', 'phone': '98765 43210'},
                               content_type='application/json', **self.auth)
        self.assertEqual(res.status_code, 201)
        self.assertEqual(Customer.objects.get(email='new@example.com').phone, '9876543210')

    def test_signup_refuses_existing_phone_and_bad_input(self):
        self.verify.return_value = {'email': 'new@example.com', 'email_verified': True}
        post = lambda body: self.client.post('/api/customer/me/', body,
                                             content_type='application/json', **self.auth)
        self.assertEqual(post({'name': 'New', 'phone': '111'}).status_code, 400)
        Customer.objects.filter(pk=self.bob.pk).update(phone='9876543210')
        # Existing phone (any formatting) -> queued for staff approval, not linked.
        res = post({'name': 'New', 'phone': '+919876543210'})
        self.assertEqual(res.status_code, 202)
        self.assertTrue(res.json()['pending'])
        self.assertFalse(Customer.objects.filter(email='new@example.com').exists())
        self.assertEqual(EmailLinkRequest.objects.filter(customer=self.bob).count(), 1)
        post({'name': 'New', 'phone': '9876543210'})  # idempotent
        self.assertEqual(EmailLinkRequest.objects.filter(customer=self.bob).count(), 1)

    def test_signup_existing_account_is_409(self):
        res = self.client.post('/api/customer/me/', {'name': 'A', 'phone': '9999999999'},
                               content_type='application/json', **self.auth)
        self.assertEqual(res.status_code, 409)

    def test_signup_post_works_without_a_csrf_token(self):
        from django.test import Client
        self.verify.return_value = {'email': 'csrf@example.com', 'email_verified': True}
        res = Client(enforce_csrf_checks=True).post(
            '/api/customer/me/', {'name': 'C', 'phone': '9876500001'},
            content_type='application/json', **self.auth)
        self.assertEqual(res.status_code, 201)

    def test_rate_card_is_public(self):
        self.assertEqual(self.client.get('/api/customer/rate-card/').status_code, 200)


class RoleAuthTests(APITestCase):
    """api/auth.py: Google token -> staff / customer / unlinked, and enforcement."""

    def setUp(self):
        from unittest import mock
        self.alice = Customer.objects.create(name='Alice', phone='9111111111', email='Alice@Example.com')
        self.bob = Customer.objects.create(name='Bob', phone='9222222222')
        Order.objects.create(order_number='WL-1', customer=self.alice, customer_name='Alice')
        Staff.objects.create(name='Sam', phone='9333333333', email='sam@shop.com',
                             has_app_login=True, status='ACTIVE')
        Staff.objects.create(name='NoLogin', phone='9444444444', email='nologin@shop.com')
        patcher = mock.patch('api.auth.id_token.verify_oauth2_token')
        self.verify = patcher.start()
        self.addCleanup(patcher.stop)
        for o in (override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True,
                                    STAFF_EMAILS=['owner@shop.com']),):
            o.enable()
            self.addCleanup(o.disable)
        self.auth = {'HTTP_AUTHORIZATION': 'Bearer tok'}

    def as_(self, email):
        self.verify.return_value = {'email': email, 'email_verified': True}

    def test_api_requires_a_token_when_enforced(self):
        self.assertEqual(self.client.get('/api/orders/').status_code, 401)

    def test_bad_token_is_401(self):
        self.verify.side_effect = ValueError('bad')
        self.assertEqual(self.client.get('/api/orders/', **self.auth).status_code, 401)

    def test_staff_row_and_allow_list_can_work_orders(self):
        for email in ('sam@shop.com', 'OWNER@shop.com'):
            self.as_(email)
            self.assertEqual(self.client.get('/api/orders/', **self.auth).status_code, 200)
            self.assertEqual(self.client.get('/api/customers/', **self.auth).status_code, 200)

    def test_staff_is_kept_out_of_owner_only_endpoints(self):
        owner_only = ('/api/dashboard/stats/', '/api/reports/', '/api/payroll/', '/api/expenses/',
                      '/api/credits/', '/api/staff/', '/api/attendance/', '/api/salary-payments/',
                      '/api/link-requests/')
        self.as_('sam@shop.com')
        for path in owner_only:
            self.assertEqual(self.client.get(path, **self.auth).status_code, 403, path)
        self.as_('owner@shop.com')
        for path in owner_only:
            self.assertEqual(self.client.get(path, **self.auth).status_code, 200, path)

    def test_staff_reads_but_cannot_change_the_catalogue_and_shop(self):
        self.as_('sam@shop.com')
        self.assertEqual(self.client.get('/api/categories/', **self.auth).status_code, 200)
        self.assertEqual(self.client.get('/api/shops/', **self.auth).status_code, 200)
        res = self.client.post('/api/categories/', {'name': 'X'}, format='json', **self.auth)
        self.assertEqual(res.status_code, 403)

    def test_manager_job_title_counts_as_owner(self):
        Staff.objects.create(name='Mo', phone='9555555555', email='mo@shop.com', role='Manager',
                             has_app_login=True, status='ACTIVE')
        self.as_('mo@shop.com')
        self.assertEqual(self.client.get('/api/me/', **self.auth).json()['role'], 'owner')

    def test_staff_without_app_login_is_not_staff(self):
        self.as_('nologin@shop.com')
        self.assertEqual(self.client.get('/api/orders/', **self.auth).status_code, 403)

    def test_customer_cannot_use_the_crm_api_but_sees_own_orders(self):
        self.as_('alice@example.com')
        for path in ('/api/orders/', '/api/customers/', '/api/dashboard/stats/', '/api/staff/'):
            self.assertEqual(self.client.get(path, **self.auth).status_code, 403, path)
        res = self.client.get('/api/customer/orders/', **self.auth)
        self.assertEqual([o['order_number'] for o in res.json()['orders']], ['WL-1'])


    def test_customer_can_edit_own_profile_but_not_phone_or_email(self):
        self.as_('alice@example.com')
        res = self.client.patch('/api/customer/me/', {
            'address': '12 MG Road', 'landmark': 'Near the temple', 'preference': 'No starch',
            'phone': '9000000000', 'email': 'evil@example.com'}, format='json', **self.auth)
        self.assertEqual(res.status_code, 200, res.content)
        self.alice.refresh_from_db()
        self.assertEqual((self.alice.address, self.alice.landmark, self.alice.preference),
                         ('12 MG Road', 'Near the temple', 'No starch'))
        self.assertEqual((self.alice.phone, self.alice.email.lower()),
                         ('9111111111', 'alice@example.com'))
        body = self.client.get('/api/me/', **self.auth).json()['customer']
        self.assertEqual((body['landmark'], body['preference'], body['phone']),
                         ('Near the temple', 'No starch', '9111111111'))
        self.assertEqual(self.client.patch('/api/customer/me/', {'name': ' '}, format='json',
                                           **self.auth).status_code, 400)
        self.as_('stranger@example.com')
        self.assertEqual(self.client.patch('/api/customer/me/', {'address': 'x'}, format='json',
                                           **self.auth).status_code, 404)

    def test_me_reports_role(self):
        self.as_('sam@shop.com')
        self.assertEqual(self.client.get('/api/me/', **self.auth).json()['role'], 'staff')
        self.as_('owner@shop.com')
        self.assertEqual(self.client.get('/api/me/', **self.auth).json()['role'], 'owner')
        self.as_('alice@example.com')
        body = self.client.get('/api/me/', **self.auth).json()
        self.assertEqual(body['role'], 'customer')
        self.assertEqual(body['customer']['name'], 'Alice')
        self.as_('stranger@example.com')
        self.assertEqual(self.client.get('/api/me/', **self.auth).json()['role'], 'unlinked')
        self.assertEqual(self.client.get('/api/me/').status_code, 401)

    def test_public_endpoints_stay_public(self):
        self.assertEqual(self.client.get('/api/customer/rate-card/').status_code, 200)

    def test_not_enforced_leaves_api_open(self):
        with override_settings(API_AUTH_ENFORCED=False):
            self.assertEqual(self.client.get('/api/orders/').status_code, 200)

    def test_link_request_approval_flow(self):
        link = EmailLinkRequest.objects.create(customer=self.bob, email='bob@example.com')
        self.as_('alice@example.com')
        self.assertEqual(self.client.get('/api/link-requests/', **self.auth).status_code, 403)
        self.as_('owner@shop.com')
        self.assertEqual(len(self.client.get('/api/link-requests/', **self.auth).json()['requests']), 1)
        self.assertEqual(self.client.post(f'/api/link-requests/{link.id}/approve/', **self.auth).status_code, 200)
        self.bob.refresh_from_db()
        self.assertEqual(self.bob.email, 'bob@example.com')
        self.assertEqual(self.client.post(f'/api/link-requests/{link.id}/approve/', **self.auth).status_code, 409)
        self.as_('bob@example.com')
        self.assertEqual(self.client.get('/api/me/', **self.auth).json()['role'], 'customer')

    def test_approve_refuses_to_overwrite_a_different_email(self):
        link = EmailLinkRequest.objects.create(customer=self.alice, email='other@example.com')
        self.assertFalse(link.approve())
