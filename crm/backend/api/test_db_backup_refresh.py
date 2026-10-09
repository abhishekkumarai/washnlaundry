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
