import os
import shutil
import subprocess
from pathlib import Path
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = 'Refreshes/restores the local database from a specified backup or the latest local backup.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--backup-file',
            type=str,
            default=None,
            help='Path to a specific backup file to restore. Defaults to the latest backup in backup directory.',
        )
        parser.add_argument(
            '--backup-dir',
            type=str,
            default=str(settings.BASE_DIR / 'backups'),
            help='Directory to search for backups if --backup-file is not specified.',
        )

    def handle(self, *args, **options):
        backup_file_arg = options['backup_file']
        backup_dir = Path(options['backup_dir'])
        db_config = settings.DATABASES['default']
        engine = db_config.get('ENGINE', '')

        if backup_file_arg:
            backup_file = Path(backup_file_arg)
        else:
            if not backup_dir.exists():
                raise CommandError(f'Backup directory does not exist: {backup_dir}')
            backups = sorted(backup_dir.glob('backup_*'), key=lambda p: p.stat().st_mtime, reverse=True)
            if not backups:
                raise CommandError(f'No backups found in {backup_dir}')
            backup_file = backups[0]

        if not backup_file.exists():
            raise CommandError(f'Backup file does not exist: {backup_file}')

        self.stdout.write(f'Restoring from: {backup_file} ...')

        if 'sqlite3' in engine:
            db_name = str(db_config['NAME'])
            if 'memory' in db_name or db_name.startswith('file:'):
                from django.db import connection
                import sqlite3
                src_conn = sqlite3.connect(str(backup_file))
                with connection.connection:
                    src_conn.backup(connection.connection)
                src_conn.close()
                self.stdout.write(self.style.SUCCESS(f'Successfully restored SQLite in-memory database from {backup_file.name}'))
            else:
                db_path = Path(db_name)
                # Create a safety pre-refresh copy if existing db exists
                if db_path.exists():
                    pre_refresh = db_path.with_name(f'{db_path.name}.pre_refresh')
                    shutil.copy2(db_path, pre_refresh)
                    self.stdout.write(f'Created pre-refresh safety copy at {pre_refresh}')

                shutil.copy2(backup_file, db_path)
                self.stdout.write(self.style.SUCCESS(f'Successfully restored SQLite database from {backup_file.name} to {db_path}'))

        elif 'postgresql' in engine:
            db_name = db_config.get('NAME')
            user = db_config.get('USER')
            host = db_config.get('HOST', 'localhost')
            port = str(db_config.get('PORT', 5432))
            password = db_config.get('PASSWORD')

            cmd = ['psql', '-h', host, '-p', port, '-U', user, '-d', db_name, '-f', str(backup_file)]
            env = os.environ.copy()
            if password:
                env['PGPASSWORD'] = password

            try:
                subprocess.run(cmd, env=env, check=True)
                self.stdout.write(self.style.SUCCESS(f'Successfully refreshed PostgreSQL database from {backup_file.name}'))
            except Exception as e:
                raise CommandError(f'Failed to execute psql restore: {e}')
        else:
            raise CommandError(f'Unsupported database engine: {engine}')
