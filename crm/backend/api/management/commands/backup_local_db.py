import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = 'Creates a daily timestamped backup of the local database (SQLite or PostgreSQL dump).'

    def add_arguments(self, parser):
        parser.add_argument(
            '--output-dir',
            type=str,
            default=str(settings.BASE_DIR / 'backups'),
            help='Directory where database backups are stored.',
        )
        parser.add_argument(
            '--retention-days',
            type=int,
            default=7,
            help='Number of days of backups to retain (deletes older backups).',
        )

    def handle(self, *args, **options):
        output_dir = Path(options['output_dir'])
        output_dir.mkdir(parents=True, exist_ok=True)
        retention_days = options['retention_days']

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        db_config = settings.DATABASES['default']
        engine = db_config.get('ENGINE', '')

        if 'sqlite3' in engine:
            db_name = str(db_config['NAME'])
            backup_file = output_dir / f'backup_sqlite_{timestamp}.db'

            if 'memory' in db_name or db_name.startswith('file:'):
                from django.db import connection
                import sqlite3
                dest_conn = sqlite3.connect(str(backup_file))
                with dest_conn:
                    connection.connection.backup(dest_conn)
                dest_conn.close()
            else:
                db_path = Path(db_name)
                if not db_path.exists():
                    raise CommandError(f'SQLite database not found at {db_path}')
                shutil.copy2(db_path, backup_file)

            self.stdout.write(self.style.SUCCESS(f'Successfully created SQLite backup: {backup_file} ({backup_file.stat().st_size} bytes)'))

        elif 'postgresql' in engine:
            db_name = db_config.get('NAME')
            user = db_config.get('USER')
            host = db_config.get('HOST', 'localhost')
            port = str(db_config.get('PORT', 5432))
            password = db_config.get('PASSWORD')

            backup_file = output_dir / f'backup_pg_{timestamp}.sql'
            cmd = ['pg_dump', '-h', host, '-p', port, '-U', user, '-d', db_name, '-f', str(backup_file)]
            env = os.environ.copy()
            if password:
                env['PGPASSWORD'] = password

            try:
                subprocess.run(cmd, env=env, check=True)
                self.stdout.write(self.style.SUCCESS(f'Successfully created PostgreSQL backup: {backup_file}'))
            except Exception as e:
                raise CommandError(f'Failed to run pg_dump: {e}')
        else:
            raise CommandError(f'Unsupported database engine: {engine}')

        # Prune old backups
        cutoff_seconds = retention_days * 86400
        now = datetime.now().timestamp()
        for f in output_dir.glob('backup_*'):
            if f.is_file() and (now - f.stat().st_mtime) > cutoff_seconds:
                f.unlink()
                self.stdout.write(self.style.WARNING(f'Pruned old backup: {f.name}'))
