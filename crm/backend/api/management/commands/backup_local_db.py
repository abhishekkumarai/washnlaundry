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
        parser.add_argument(
            '--upload-r2',
            action='store_true',
            help='Upload the generated backup to Cloudflare R2.',
        )
        parser.add_argument(
            '--r2-bucket',
            type=str,
            default=os.getenv('R2_BACKUP_BUCKET', 'washnlaundry-backups'),
            help='Cloudflare R2 bucket name.',
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

        # Optional upload to Cloudflare R2
        if options.get('upload_r2'):
            self._upload_to_r2(backup_file, options['r2_bucket'])

    def _upload_to_r2(self, file_path: Path, bucket_name: str):
        account_id = os.getenv('R2_ACCOUNT_ID')
        access_key = os.getenv('R2_ACCESS_KEY_ID')
        secret_key = os.getenv('R2_SECRET_ACCESS_KEY')

        if not (account_id and access_key and secret_key):
            self.stdout.write(self.style.WARNING('Skipping R2 upload: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, or R2_SECRET_ACCESS_KEY not set.'))
            return

        try:
            import boto3
            from botocore.config import Config
            s3 = boto3.client(
                's3',
                endpoint_url=f'https://{account_id}.r2.cloudflarestorage.com',
                aws_access_key_id=access_key,
                aws_secret_access_key=secret_key,
                config=Config(signature_version='s3v4'),
                region_name='auto',
            )
            key = f"db-backups/{file_path.name}"
            self.stdout.write(f'Uploading {file_path.name} to Cloudflare R2 bucket "{bucket_name}"...')
            s3.upload_file(str(file_path), bucket_name, key)
            self.stdout.write(self.style.SUCCESS(f'Successfully uploaded backup to Cloudflare R2: s3://{bucket_name}/{key}'))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Failed to upload to Cloudflare R2: {e}'))
