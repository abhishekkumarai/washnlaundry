"""Unit and integration tests for Database Backup and Refresh commands (KAN-140)."""
import shutil
import tempfile
from pathlib import Path
from django.core.management import call_command
from django.test import TestCase, override_settings

from api.models import Shop, Order


class DatabaseBackupRefreshTests(TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.shop = Shop.objects.create(name='Backup Test Shop', slug='backup-test')
        self.order = Order.objects.create(
            shop=self.shop,
            customer_name='Backup Customer',
            customer_phone='9998887776',
            order_number='BACK-00001'
        )

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_backup_and_refresh_workflow(self):
        """backup_local_db creates a backup file and refresh_local_db restores from it."""
        # 1. Run backup
        call_command('backup_local_db', output_dir=self.temp_dir, retention_days=1)
        backup_files = list(Path(self.temp_dir).glob('backup_*'))
        self.assertEqual(len(backup_files), 1)
        backup_file = backup_files[0]
        self.assertGreater(backup_file.stat().st_size, 0)

        # 2. Run refresh specifying the backup file
        call_command('refresh_local_db', backup_file=str(backup_file))

        # Check data is intact
        self.assertTrue(Order.objects.filter(order_number='BACK-00001').exists())

    def test_export_backup_endpoints(self):
        """Test API endpoints for full backup and section exports."""
        from rest_framework.test import APIClient
        from api.models import Staff, Attendance, SalaryPayment, Customer
        from datetime import date

        staff = Staff.objects.create(shop=self.shop, name='Test Staff', phone='9876543210', monthly_wage=15000)
        Attendance.objects.create(shop=self.shop, staff=staff, date=date(2026, 10, 1), status='PRESENT')
        SalaryPayment.objects.create(shop=self.shop, staff=staff, month=date(2026, 10, 1), amount=5000)
        Customer.objects.create(shop=self.shop, name='Cust One', phone='9876543211')

        client = APIClient()

        # 1. Full backup XLSX
        r_xlsx = client.get(f'/api/backup/export/?export_format=xlsx&shop={self.shop.id}')
        self.assertEqual(r_xlsx.status_code, 200)
        self.assertIn('application/vnd.openxmlformats', r_xlsx['Content-Type'])
        self.assertGreater(len(r_xlsx.content), 0)

        # 2. Full backup JSON
        r_json = client.get(f'/api/backup/export/?export_format=json&shop={self.shop.id}')
        self.assertEqual(r_json.status_code, 200)
        self.assertIn('sections', r_json.data)
        self.assertIn('staff', r_json.data['sections'])
        self.assertIn('orders', r_json.data['sections'])
        self.assertIn('attendance', r_json.data['sections'])
        self.assertIn('payroll', r_json.data['sections'])

        # 3. Section CSV exports
        for sec in ['staff', 'orders', 'attendance', 'payroll', 'customers', 'expenses', 'credits', 'services']:
            r_sec = client.get(f'/api/backup/export/{sec}/?export_format=csv&shop={self.shop.id}')
            self.assertEqual(r_sec.status_code, 200)
            self.assertIn('text/csv', r_sec['Content-Type'])
            self.assertGreater(len(r_sec.content), 0)

        # 4. Section JSON export
        r_sec_json = client.get(f'/api/backup/export/staff/?export_format=json&shop={self.shop.id}')
        self.assertEqual(r_sec_json.status_code, 200)
        self.assertIsInstance(r_sec_json.data, list)
        self.assertTrue(any(s['name'] == 'Test Staff' for s in r_sec_json.data))
