from django.apps import apps
from django.core.management.base import BaseCommand

from api.models import Shop
from api.tenancy import TenantModel


class Command(BaseCommand):
    help = (
        'Read-only audit: rows with no shop, and rows whose shop differs from the shop '
        'of a parent they point at. Run on production and get it to zero before making '
        'the shop columns NOT NULL.'
    )

    def handle(self, *args, **options):
        problems = 0
        if Shop.objects.count() > 1:
            self.stdout.write(f'{Shop.objects.count()} shops')
        tenant_models = [m for m in apps.get_app_config('api').get_models()
                         if issubclass(m, TenantModel)]
        tenant_models += [apps.get_model('api', 'MetaSettings')]
        for model in tenant_models:
            nulls = model._base_manager.filter(shop__isnull=True).count()
            if nulls:
                problems += nulls
                self.stdout.write(self.style.ERROR(f'{model.__name__}: {nulls} row(s) with no shop'))
            # shop must match the shop of every tenant-scoped FK parent
            for field in model._meta.get_fields():
                if not (field.many_to_one and field.name != 'shop'
                        and issubclass(field.related_model, TenantModel)):
                    continue
                bad = model._base_manager.exclude(**{f'{field.name}__isnull': True}).exclude(
                    shop__isnull=True).exclude(shop=models_f(field.name)).count()
                if bad:
                    problems += bad
                    self.stdout.write(self.style.ERROR(
                        f'{model.__name__}.{field.name}: {bad} row(s) in a different shop than their parent'))
        self.stdout.write(self.style.SUCCESS('Tenant integrity OK.') if not problems
                          else self.style.ERROR(f'{problems} problem row(s).'))


def models_f(name):
    from django.db.models import F
    return F(f'{name}__shop')
