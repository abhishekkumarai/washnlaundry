from django.core.management.base import BaseCommand, CommandError

from api.models import Shop

# Feature name -> Shop field. Each is off by default and gates both the app's
# menu and the feature's API for that shop.
FEATURES = {
    'social_suite': 'social_suite_enabled',
    'chat': 'chat_enabled',
}


class Command(BaseCommand):
    help = (
        'Switch a per-shop feature on or off, or show who has what. Features: '
        + ', '.join(FEATURES) + '. All are off by default.\n'
        '  shop_feature                      list shops with any feature on\n'
        '  shop_feature <slug>               show one shop\n'
        '  shop_feature <slug> <feature> on|off'
    )

    def add_arguments(self, parser):
        parser.add_argument('slug', nargs='?')
        parser.add_argument('feature', nargs='?', choices=list(FEATURES))
        parser.add_argument('state', nargs='?', choices=['on', 'off'])

    def _describe(self, shop):
        on = [name for name, field in FEATURES.items() if getattr(shop, field)]
        return f'{shop.slug}  ({shop.name}): {", ".join(on) if on else "none"}'

    def handle(self, *args, slug=None, feature=None, state=None, **options):
        if not slug:
            shops = [s for s in Shop.objects.order_by('slug')
                     if any(getattr(s, f) for f in FEATURES.values())]
            if not shops:
                self.stdout.write('No shop has any of these features on: ' + ', '.join(FEATURES))
            for shop in shops:
                self.stdout.write(self._describe(shop))
            return
        try:
            shop = Shop.objects.get(slug=slug)
        except Shop.DoesNotExist:
            raise CommandError(f'No shop with slug "{slug}".')
        if feature is None:
            self.stdout.write(self._describe(shop))
            return
        if state is None:
            raise CommandError('Say "on" or "off".')
        setattr(shop, FEATURES[feature], state == 'on')
        shop.save(update_fields=[FEATURES[feature]])
        self.stdout.write(self.style.SUCCESS(f'{feature} {state} for "{shop.name}" ({slug}).'))
