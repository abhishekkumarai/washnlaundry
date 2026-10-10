from datetime import timedelta

from django.core.management.base import BaseCommand
from django.db.models import Q
from django.utils import timezone

from api import media_storage
from api.models import OrderMedia


class Command(BaseCommand):
    help = (
        'Delete photos/videos of orders that were delivered or cancelled more than '
        '--days ago. Keeps database storage from growing without bound.'
    )

    def add_arguments(self, parser):
        parser.add_argument('--days', type=int, default=30)
        parser.add_argument('--dry-run', action='store_true')

    def handle(self, *args, days, dry_run, **options):
        cutoff = timezone.now() - timedelta(days=days)
        old = OrderMedia.all_objects.filter(
            Q(order__delivered_at__lt=cutoff) | Q(order__cancelled_at__lt=cutoff))
        count = old.count()
        if not dry_run:
            storage = media_storage.get_storage()
            for media in old:
                storage.delete(media)
            old.delete()
        verb = 'Would delete' if dry_run else 'Deleted'
        self.stdout.write(self.style.SUCCESS(
            f'{verb} {count} file(s) from orders closed more than {days} days ago.'))
