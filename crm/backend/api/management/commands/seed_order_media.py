from django.core.management.base import BaseCommand, CommandError

from api.models import Shop, ShopStatus
from api.sample_media import attach_sample_media


class Command(BaseCommand):
    help = (
        'Attach demo photos and a short video to the most recent orders that have none. '
        'Non-destructive and repeatable: orders that already have media are skipped.'
    )

    def add_arguments(self, parser):
        parser.add_argument('--shop', help='Shop slug (default: every active shop).')
        parser.add_argument('--orders', type=int, default=10,
                            help='Orders to give media to, per shop (default 10).')

    def handle(self, *args, shop, orders, **options):
        shops = Shop.objects.filter(status=ShopStatus.ACTIVE)
        if shop:
            shops = shops.filter(slug=shop)
            if not shops.exists():
                raise CommandError(f'No active shop with slug "{shop}".')
        total_orders = total_files = 0
        for s in shops:
            touched, files = attach_sample_media(s, limit=orders)
            total_orders += touched
            total_files += files
            self.stdout.write(f'{s.slug}: {touched} order(s), {files} file(s)')
        self.stdout.write(self.style.SUCCESS(
            f'Seeded {total_files} file(s) onto {total_orders} order(s).'))
