from django.core.management.base import BaseCommand

from api.item_tags import category_tags, item_tags
from api.models import GarmentCategory, GarmentItem


class Command(BaseCommand):
    help = (
        'Give starter tags to catalogue items and categories that have none (all shops, '
        'or one with --shop). Tags an owner has already set are never changed.'
    )

    def add_arguments(self, parser):
        parser.add_argument('--shop', help='Only this shop slug.')
        parser.add_argument('--dry-run', action='store_true', help='Report, change nothing.')

    def handle(self, *args, shop=None, dry_run=False, **options):
        items = GarmentItem.all_objects.select_related('category')
        cats = GarmentCategory.all_objects.all()
        if shop:
            items, cats = items.filter(shop__slug=shop), cats.filter(shop__slug=shop)
        n_items = n_cats = 0
        for item in items:
            if item.tags:
                continue
            n_items += 1
            if not dry_run:
                item.tags = item_tags(item.category.name if item.category else '', item.name, item.unit)
                item.save(update_fields=['tags'])
        for cat in cats:
            tags = category_tags(cat.name)
            if cat.tags or not tags:
                continue
            n_cats += 1
            if not dry_run:
                cat.tags = tags
                cat.save(update_fields=['tags'])
        verb = 'Would tag' if dry_run else 'Tagged'
        self.stdout.write(self.style.SUCCESS(f'{verb} {n_items} items and {n_cats} categories.'))
