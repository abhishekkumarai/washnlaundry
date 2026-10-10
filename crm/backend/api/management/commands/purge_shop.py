from django.core.management.base import BaseCommand, CommandError

from api.models import Shop, ShopStatus


class Command(BaseCommand):
    help = (
        'Permanently delete an ARCHIVED shop and all of its data (orders, customers, '
        'staff, payments, memberships). Irreversible: take a backup/export first.'
    )

    def add_arguments(self, parser):
        parser.add_argument('slug')
        parser.add_argument('--confirm', required=True,
                            help='Repeat the slug to confirm the purge.')

    def handle(self, *args, slug, confirm, **options):
        if confirm != slug:
            raise CommandError('--confirm must repeat the slug exactly.')
        try:
            shop = Shop.objects.get(slug=slug)
        except Shop.DoesNotExist:
            raise CommandError(f'No shop with slug "{slug}".')
        if shop.status != ShopStatus.ARCHIVED:
            raise CommandError('Only an ARCHIVED shop can be purged. Archive it first.')
        name = shop.name
        shop.delete()
        self.stdout.write(self.style.SUCCESS(f'Purged shop "{name}" ({slug}).'))
