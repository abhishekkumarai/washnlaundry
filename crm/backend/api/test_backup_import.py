"""Per-shop import for the Backup & Data Export sections."""
import json
from datetime import date

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from rest_framework.test import APIClient

from api import backup_export_service as exporter
from api.models import Attendance, Credit, Order, SalaryPayment, Shop, Staff
from api.tenancy import tenant_context


def upload(text, name='f.csv'):
    return SimpleUploadedFile(name, text.encode('utf-8'))


class BackupImportTests(TestCase):
    def setUp(self):
        self.shop = Shop.objects.create(name='A', slug='shop-a')
        self.other = Shop.objects.create(name='B', slug='shop-b')
        self.client = APIClient()

    def post(self, section, text, name='f.csv', shop=None, **extra):
        shop = shop or self.shop
        return self.client.post(
            f'/api/backup/import/{section}/?shop={shop.id}',
            {'file': upload(text, name), **extra}, format='multipart')

    def test_staff_import_is_per_shop_and_idempotent(self):
        csv_text = ('ID,Name,Role,Phone,Email,Monthly Wage,Status,App Login,Start Date\n'
                    ',Asha,Washer,9876543210,,12000,ACTIVE,Yes,2026-01-05\n')
        r = self.post('staff', csv_text)
        self.assertEqual(r.status_code, 200, r.data)
        self.assertEqual(r.data['created'], 1)
        # The file saying "App Login: Yes" must never grant sign-in.
        self.assertFalse(Staff.objects.get(shop=self.shop).has_app_login)
        again = self.post('staff', csv_text)
        self.assertEqual((again.data['created'], again.data['skipped_existing']), (0, 1))
        self.assertEqual(Staff.objects.filter(shop=self.other).count(), 0)

    def test_attendance_needs_existing_staff_and_reports_row_errors(self):
        text = 'Staff Name,Date,Status,Check-in Time,Notes\nGhost,2026-10-01,PRESENT,,\n'
        r = self.post('attendance', text)
        self.assertEqual(r.data['failed'], 1)
        self.assertEqual(r.data['errors'][0]['row'], 2)
        Staff.objects.create(shop=self.shop, name='Ghost', phone='9000000001')
        r = self.post('attendance', text)
        self.assertEqual(r.data['created'], 1)
        self.assertTrue(Attendance.objects.filter(shop=self.shop).exists())

    def test_payroll_expenses_credits_orders(self):
        Staff.objects.create(shop=self.shop, name='Asha', phone='9876543210')
        r = self.post('payroll', 'Staff Name,Month,Amount,Paid On,Payment Method,Type,Notes\n'
                      'Asha,2026-10-01,5000,2026-10-05 10:00:00,CASH,Salary Payout,\n')
        self.assertEqual(r.data['created'], 1, r.data)
        self.assertEqual(SalaryPayment.objects.filter(shop=self.shop).count(), 1)
        r = self.post('expenses', 'Title,Category,Amount,Payment Method,Date,Notes\n'
                      'Detergent,Supplies,900,CASH,2026-10-02 09:00:00,\n')
        self.assertEqual(r.data['created'], 1, r.data)
        r = self.post('credits', 'Title,Category,Amount,Payment Method,Date,Notes\n'
                      'Advance,Advances,300,UPI,2026-10-02 09:00:00,\n')
        self.assertEqual(r.data['created'], 1, r.data)
        self.assertEqual(Credit.objects.filter(shop=self.shop).count(), 1)
        r = self.post('orders', 'Order Number,Customer Name,Customer Phone,Status,Total Amount,Paid Amount\n'
                      'X-1,Ravi,9811111111,DELIVERED,500,500\n')
        self.assertEqual(r.data['created'], 1, r.data)
        self.assertEqual(Order.objects.get(shop=self.shop).order_number, 'X-1')

    def test_bad_value_is_a_row_error_not_a_crash(self):
        r = self.post('expenses', 'Title,Category,Amount,Payment Method,Date,Notes\n'
                      'Oops,Supplies,abc,CASH,2026-10-02,\n')
        self.assertEqual(r.status_code, 200)
        self.assertEqual((r.data['created'], r.data['failed']), (0, 1))

    def test_dry_run_writes_nothing(self):
        r = self.post('staff', 'Name,Phone\nAsha,9876543210\n', dry_run='true')
        self.assertEqual(r.data['created'], 1)
        self.assertEqual(Staff.objects.count(), 0)

    def test_unknown_section_and_missing_file(self):
        self.assertEqual(self.post('customers', 'a\n1\n').status_code, 400)
        r = self.client.post(f'/api/backup/import/staff/?shop={self.shop.id}', {}, format='multipart')
        self.assertEqual(r.status_code, 400)

    def test_export_then_import_round_trips_into_another_shop(self):
        staff = Staff.objects.create(shop=self.shop, name='Asha', phone='9876543210', monthly_wage=9000)
        Attendance.objects.create(shop=self.shop, staff=staff, date=date(2026, 10, 1), status='PRESENT')
        with tenant_context(self.shop):
            staff_csv = exporter.export_section_csv('staff')
            att_json = json.dumps(exporter.export_section_json('attendance'))
        self.assertEqual(self.post('staff', staff_csv, shop=self.other).data['created'], 1)
        r = self.post('attendance', att_json, 'a.json', shop=self.other)
        self.assertEqual(r.data['created'], 1, r.data)
        self.assertEqual(Attendance.objects.filter(shop=self.other).count(), 1)
