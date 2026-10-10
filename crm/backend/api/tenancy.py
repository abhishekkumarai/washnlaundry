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


def fallback_shop():
    """The shop to assume when a request resolved no tenant.

    Only safe in a single-shop deployment, so it returns the sole shop, and
    None as soon as there are several - callers must then fail loudly instead
    of silently landing data in whichever shop happens to be first.
    """
    from .models import Shop
    shops = list(Shop.objects.all()[:2])
    return shops[0] if len(shops) == 1 else None


def require_shop():
    """The active tenant, else the sole shop of a single-shop deployment, else an error."""
    shop = get_current_tenant() or fallback_shop()
    if shop is None:
        raise ValueError('No tenant is active and the shop cannot be inferred.')
    return shop


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

    _active_tenant_id = None
    _unscoped = False

    def unscoped(self):
        """Returns a clone of the queryset with tenant filtering disabled."""
        clone = self._clone()
        clone._unscoped = True
        return clone

    def filter_current_tenant(self):
        tenant = get_current_tenant()
        if tenant:
            return self.filter(shop=tenant)
        return self

    def all(self):
        """Overrides .all() so that evaluated or module-level querysets (like DRF's
        `queryset = Model.objects.all()`) dynamically scope to the request's
        active tenant when called per-request by DRF's `get_queryset()`."""
        tenant = get_current_tenant()
        if tenant and not getattr(self, '_unscoped', False):
            if getattr(self, '_active_tenant_id', None) == tenant.id:
                return super().all()
            clone = self.filter(shop=tenant)
            clone._active_tenant_id = tenant.id
            return clone
        return super().all()


class TenantManager(models.Manager.from_queryset(TenantQuerySet)):
    """Default model manager that automatically restricts querysets to the active tenant."""

    def get_queryset(self):
        qs = super().get_queryset()
        tenant = get_current_tenant()
        if tenant:
            clone = qs.filter(shop=tenant)
            clone._active_tenant_id = tenant.id
            return clone
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
                default_shop = fallback_shop()
                if default_shop is None:
                    raise ValueError(
                        f'{type(self).__name__} saved without a shop and no tenant is active.')
                self.shop = default_shop
        super().save(*args, **kwargs)
