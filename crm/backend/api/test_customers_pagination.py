"""Customers list: 10-per-page pagination, search across every page, KPI filters and stats."""
from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from api.models import Customer, Order, OrderStatus, Shop


def rows(res):
    body = res.json()
    return body['results'] if isinstance(body, dict) else body


class CustomersPaginationTests(TestCase):
    def setUp(self):
        self.shop = Shop.objects.create(name='Pager Shop', slug='pager-shop')
        self.other = Shop.objects.create(name='Other Shop', slug='other-pager')
        self.h = {'HTTP_X_TENANT_ID': 'pager-shop'}
        self.client = APIClient()
        # 25 customers; names sort-friendly so we can find them
        for i in range(25):
            Customer.all_objects.create(shop=self.shop, name=f'Cust {i:02d}', phone=f'90000000{i:02d}',
                                        email=f'c{i}@x.com', area='Indiranagar' if i == 7 else 'Koramangala')
        Customer.all_objects.create(shop=self.other, name='Other Shop Person', phone='9111111111')

    def get(self, **params):
        return self.client.get('/api/customers/', params, **self.h)

    def test_page_size_10_envelope_and_page_count(self):
        res = self.get(page=1, page_size=10)
        body = res.json()
        self.assertEqual(len(body['results']), 10)
        self.assertEqual((body['count'], body['total_pages'], body['current_page']), (25, 3, 1))
        last = self.get(page=3, page_size=10).json()
        self.assertEqual(len(last['results']), 5)

    def test_pages_do_not_overlap_or_skip(self):
        seen = []
        for page in (1, 2, 3):
            seen += [c['id'] for c in rows(self.get(page=page, page_size=10))]
        self.assertEqual(len(seen), 25)
        self.assertEqual(len(set(seen)), 25)

    def test_tenant_isolation_in_the_list_and_count(self):
        body = self.get(page=1, page_size=10).json()
        self.assertEqual(body['count'], 25)
        self.assertFalse(any('Other Shop' in c['name'] for c in body['results']))

    def test_search_reaches_customers_on_other_pages(self):
        # Cust 00 is the oldest => last page when sorted newest-first
        page1_names = {c['name'] for c in rows(self.get(page=1, page_size=10))}
        self.assertNotIn('Cust 00', page1_names)
        found = rows(self.get(search='Cust 00', page=1, page_size=10))
        self.assertEqual([c['name'] for c in found], ['Cust 00'])

    def test_search_matches_name_phone_email_and_area(self):
        self.assertEqual(len(rows(self.get(search='9000000012'))), 1)
        self.assertEqual(len(rows(self.get(search='c13@x.com'))), 1)
        self.assertEqual([c['name'] for c in rows(self.get(search='indiranagar'))], ['Cust 07'])

    def test_search_results_are_paginated_and_counted(self):
        body = self.get(search='Cust', page=2, page_size=10).json()
        self.assertEqual((body['count'], len(body['results']), body['current_page']), (25, 10, 2))
        self.assertEqual(self.get(search='nobody-matches', page=1, page_size=10).json()['count'], 0)

    def test_blank_search_is_ignored(self):
        self.assertEqual(self.get(search='   ', page=1, page_size=10).json()['count'], 25)

    def test_unpaginated_request_still_returns_the_plain_list(self):
        self.assertEqual(len(rows(self.client.get('/api/customers/', **self.h))), 25)

    # ── KPI filters ─────────────────────────────────────────────────────────
    def test_filters_active_new_owing_and_stats(self):
        c = list(Customer.all_objects.filter(shop=self.shop).order_by('name'))
        # active: has orders
        for x in c[:3]:
            Customer.all_objects.filter(pk=x.pk).update(total_orders=2)
        # not new: created last year
        old = timezone.now() - timedelta(days=400)
        for x in c[3:8]:
            Customer.all_objects.filter(pk=x.pk).update(created_at=old)
        # owing: unpaid delivered order (one by FK, one only by phone, one paid, one not delivered)
        Order.all_objects.create(shop=self.shop, customer=c[10], customer_name='x', customer_phone='',
                                 status=OrderStatus.DELIVERED, due_amount=50)
        Order.all_objects.create(shop=self.shop, customer_name='y', customer_phone=c[11].phone,
                                 status=OrderStatus.DELIVERED, due_amount=20)
        Order.all_objects.create(shop=self.shop, customer=c[12], customer_name='z', customer_phone='',
                                 status=OrderStatus.DELIVERED, due_amount=0)
        Order.all_objects.create(shop=self.shop, customer=c[13], customer_name='w', customer_phone='',
                                 status=OrderStatus.PLACED, due_amount=99)

        self.assertEqual(self.get(filter='active', page=1, page_size=10).json()['count'], 3)
        self.assertEqual(self.get(filter='new', page=1, page_size=10).json()['count'], 20)
        owing = self.get(filter='owing', page=1, page_size=10).json()
        self.assertEqual(sorted(x['name'] for x in owing['results']), sorted([c[10].name, c[11].name]))

        stats = self.client.get('/api/customers/stats/', **self.h).json()
        self.assertEqual(stats, {'total': 25, 'active': 3, 'new': 20, 'owing': 2})

    def test_filter_and_search_combine(self):
        Customer.all_objects.filter(shop=self.shop, name__in=['Cust 01', 'Cust 02']).update(total_orders=1)
        res = self.get(filter='active', search='Cust 02', page=1, page_size=10).json()
        self.assertEqual([c['name'] for c in res['results']], ['Cust 02'])

    def test_stats_ignore_search_and_other_shops(self):
        stats = self.client.get('/api/customers/stats/', {'search': 'zzz'}, **self.h).json()
        self.assertEqual(stats['total'], 25)  # not narrowed by search, not including the other shop

    def test_unknown_filter_is_ignored(self):
        self.assertEqual(self.get(filter='bogus', page=1, page_size=10).json()['count'], 25)
