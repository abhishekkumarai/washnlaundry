import contextvars
from contextlib import contextmanager
from django.db import models


_current_tenant = contextvars.ContextVar('current_tenant', default=None)


def get_current_tenant():
    """Returns the currently active Shop instance or None."""
    return _current_tenant.get()


def set_current_tenant(tenant):
    """Sets the currently active Shop instance for the current context."""
    return _current_tenant.set(tenant)


@contextmanager
def tenant_context(tenant):
    """Context manager to temporarily run code in the context of a given Shop."""
    token = _current_tenant.set(tenant)
    try:
        yield tenant
    finally:
        _current_tenant.reset(token)


class TenantQuerySet(models.QuerySet):
    """QuerySet that supports automatic tenant filtering."""

    def filter_current_tenant(self):
        tenant = get_current_tenant()
        if tenant:
            return self.filter(shop=tenant)
        return self


class TenantManager(models.Manager.from_queryset(TenantQuerySet)):
    """Default model manager that automatically restricts querysets to the active tenant."""

    def get_queryset(self):
        qs = super().get_queryset()
        tenant = get_current_tenant()
        if tenant:
            return qs.filter(shop=tenant)
        return qs


class TenantModel(models.Model):
    """Abstract base class ensuring all queries & saves are automatically tenant-scoped.
    
    Provides defense-in-depth at the ORM layer:
    - Default manager `objects` filters by `get_current_tenant()` when set.
    - `all_objects` allows unscoped access for migrations, admin superusers, and cross-shop queries.
    - `.save()` auto-populates `shop` from current tenant or first available shop.
    """
    shop = models.ForeignKey(
        'api.Shop',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='%(app_label)s_%(class)s_set',
        db_index=True
    )

    objects = TenantManager()
    all_objects = models.Manager()

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        if not getattr(self, 'shop_id', None):
            tenant = get_current_tenant()
            if tenant:
                self.shop = tenant
            else:
                from .models import Shop
                default_shop = Shop.objects.first()
                if default_shop:
                    self.shop = default_shop
        super().save(*args, **kwargs)
