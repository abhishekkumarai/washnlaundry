from rest_framework.test import APITestCase
from .models import Order, Customer, Staff


class PaginationTests(APITestCase):
    def setUp(self):
        # Create sample orders
        for i in range(25):
            Order.objects.create(
                customer_name=f'Customer {i}',
                customer_phone=f'98765432{i:02d}',
                total_amount=100 + i,
            )
        # Create sample customers
        for i in range(15):
            Customer.objects.create(
                name=f'Cust {i}',
                phone=f'91234567{i:02d}',
            )
        # Create sample staff
        for i in range(8):
            Staff.objects.create(
                name=f'Staff {i}',
                phone=f'99887766{i:02d}',
                role='Washer',
            )

    def test_orders_unpaginated_by_default(self):
        res = self.client.get('/api/orders/')
        self.assertEqual(res.status_code, 200)
        self.assertIsInstance(res.data, list)
        self.assertEqual(len(res.data), 25)

    def test_orders_paginated_with_page_param(self):
        res = self.client.get('/api/orders/?page=1&page_size=10')
        self.assertEqual(res.status_code, 200)
        self.assertIsInstance(res.data, dict)
        self.assertEqual(res.data['count'], 25)
        self.assertEqual(res.data['total_pages'], 3)
        self.assertEqual(res.data['current_page'], 1)
        self.assertEqual(res.data['page_size'], 10)
        self.assertIsNotNone(res.data['next'])
        self.assertIsNone(res.data['previous'])
        self.assertEqual(len(res.data['results']), 10)

    def test_orders_second_page(self):
        res = self.client.get('/api/orders/?page=2&page_size=10')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['current_page'], 2)
        self.assertIsNotNone(res.data['previous'])
        self.assertIsNotNone(res.data['next'])
        self.assertEqual(len(res.data['results']), 10)

    def test_orders_third_page(self):
        res = self.client.get('/api/orders/?page=3&page_size=10')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['current_page'], 3)
        self.assertIsNotNone(res.data['previous'])
        self.assertIsNone(res.data['next'])
        self.assertEqual(len(res.data['results']), 5)

    def test_customers_pagination(self):
        res = self.client.get('/api/customers/?page=1&page_size=5')
        self.assertEqual(res.status_code, 200)
        self.assertIsInstance(res.data, dict)
        self.assertEqual(res.data['count'], 15)
        self.assertEqual(res.data['total_pages'], 3)
        self.assertEqual(len(res.data['results']), 5)

    def test_staff_pagination(self):
        res = self.client.get('/api/staff/?page=1&page_size=5')
        self.assertEqual(res.status_code, 200)
        self.assertIsInstance(res.data, dict)
        self.assertEqual(res.data['count'], 8)
        self.assertEqual(res.data['total_pages'], 2)
        self.assertEqual(len(res.data['results']), 5)
