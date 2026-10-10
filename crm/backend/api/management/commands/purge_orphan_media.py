from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from api import media_storage
from api.models import OrderMedia


class Command(BaseCommand):
    help = (
        'Delete order photos/videos that were uploaded but never attached to an order '
        '(abandoned carts, failed order submits) older than --hours.'
    )

    def add_arguments(self, parser):
        parser.add_argument('--hours', type=int, default=24)
        parser.add_argument('--dry-run', action='store_true')

    def handle(self, *args, hours, dry_run, **options):
        cutoff = timezone.now() - timedelta(hours=hours)
        stale = OrderMedia.all_objects.filter(order__isnull=True, created_at__lt=cutoff)
        count = stale.count()
        if not dry_run:
            storage = media_storage.get_storage()
            for media in stale:
                storage.delete(media)
            stale.delete()
        verb = 'Would delete' if dry_run else 'Deleted'
        self.stdout.write(self.style.SUCCESS(f'{verb} {count} orphaned upload(s) older than {hours}h.'))
