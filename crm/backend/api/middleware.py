from django.db import connection
from django.http import JsonResponse
from .media_views import FILE_PATH_RE
from .models import Shop
from .tenancy import fallback_shop, set_current_tenant


class TenantMiddleware:
    """Resolves and enforces the active tenant for each HTTP request.

    Tenant Resolution Strategy (in priority order):
    1. HTTP header `X-Tenant-ID` (shop ID, slug, or subdomain)
    2. Query param `?shop=<slug_or_id>`
    3. Host subdomain (e.g. `cp.washnlaundry.com` -> 'cp'), ignoring standard platform hosts
    4. Authenticated user's default/first active ShopMembership
    5. The sole shop, if the deployment has exactly one. With several shops and
       no tenant, tenant-scoped API paths are rejected rather than guessed.
    """

    # Paths that work without a tenant: they look at the caller's memberships.
    # (The customer portal is cross-shop: a customer's rows are bound to them, not a tenant.)
    TENANTLESS_PREFIXES = ('/api/me/', '/api/shops/', '/api/auth/', '/api/customer/', '/api/link-requests/')

    EXCLUDED_SUBDOMAINS = {'app', 'customer', 'www', 'api', 'localhost', '127', 'admin', 'testserver'}

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        shop = self.resolve_tenant(request)

        # If a specific tenant was requested but could not be resolved
        if shop is False:
            return JsonResponse({'detail': 'Tenant shop not found.'}, status=404)

        if shop and getattr(shop, 'status', None) != 'ACTIVE':
            return JsonResponse({'detail': 'Tenant shop is inactive, suspended or archived.'}, status=403)

        if (shop is None and request.path.startswith('/api/')
                and not request.path.startswith(self.TENANTLESS_PREFIXES)
                and not FILE_PATH_RE.match(request.path)):
            return JsonResponse(
                {'detail': 'No shop selected. Send the X-Tenant-ID header.'}, status=400)

        request.shop = shop
        token = set_current_tenant(shop)

        # PostgreSQL RLS session setting. Session-scoped (is_local=false) because
        # requests run in autocommit, where SET LOCAL is a no-op that only logs a
        # warning. Reset in `finally` so a pooled connection never carries it over.
        # NB: RLS only binds a role that does not own the tables (or tables set to
        # FORCE ROW LEVEL SECURITY); the app's usual owner role bypasses it.
        rls_set = bool(shop and connection.vendor == 'postgresql')
        if rls_set:
            with connection.cursor() as cursor:
                cursor.execute("SELECT set_config('app.current_tenant', %s, false)", [str(shop.id)])

        try:
            response = self.get_response(request)
            if shop and hasattr(response, '__setitem__'):
                response['X-Tenant-ID'] = str(shop.slug or shop.id)
            return response
        finally:
            set_current_tenant(None)
            if rls_set:
                with connection.cursor() as cursor:
                    cursor.execute("SELECT set_config('app.current_tenant', '', false)")

    def resolve_tenant(self, request):
        # 1. Header `X-Tenant-ID`
        tenant_header = request.headers.get('X-Tenant-ID') or request.META.get('HTTP_X_TENANT_ID')
        if tenant_header:
            tenant_header = str(tenant_header).strip()
            shop = self.get_shop_by_id_or_slug(tenant_header)
            if not shop:
                return False  # explicitly not found
            return shop

        # 2. Query param `?shop=`
        tenant_param = request.GET.get('shop')
        if tenant_param:
            tenant_param = str(tenant_param).strip()
            shop = self.get_shop_by_id_or_slug(tenant_param)
            if not shop:
                return False
            return shop

        # 3. Subdomain from Host header
        try:
            host = request.get_host().split(':')[0].lower()
            parts = host.split('.')
            if len(parts) >= 3:
                subdomain = parts[0]
                if subdomain not in self.EXCLUDED_SUBDOMAINS:
                    shop = Shop.objects.filter(subdomain__iexact=subdomain).first()
                    if not shop:
                        shop = Shop.objects.filter(slug__iexact=subdomain).first()
                    if shop:
                        return shop
        except Exception:
            pass

        # 4. Authenticated user active membership
        user = getattr(request, 'user', None)
        if user and getattr(user, 'is_authenticated', False) and hasattr(user, 'shop_memberships'):
            active_m = user.shop_memberships.filter(is_active=True).first()
            if active_m:
                return active_m.shop

        # 5. Single-shop deployments keep working without a header
        return fallback_shop()

    def get_shop_by_id_or_slug(self, identifier):
        if not identifier:
            return None
        # Slug first: it is unique and is what the API echoes back
        shop = Shop.objects.filter(slug__iexact=identifier).first()
        if shop:
            return shop
        if identifier.isdigit():
            shop = Shop.objects.filter(pk=int(identifier)).first()
            if shop:
                return shop
        # Try subdomain (unique when set)
        return Shop.objects.filter(subdomain__iexact=identifier).first()
