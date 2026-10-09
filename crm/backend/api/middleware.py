from django.db import connection
from django.http import JsonResponse
from .models import Shop
from .tenancy import set_current_tenant


class TenantMiddleware:
    """Resolves and enforces the active tenant for each HTTP request.

    Tenant Resolution Strategy (in priority order):
    1. HTTP header `X-Tenant-ID` (shop ID, slug, or subdomain)
    2. Query param `?shop=<slug_or_id>`
    3. Host subdomain (e.g. `cp.washnlaundry.com` -> 'cp'), ignoring standard platform hosts
    4. Authenticated user's default/first active ShopMembership
    5. Fallback to default Shop (first shop in database)
    """

    EXCLUDED_SUBDOMAINS = {'app', 'customer', 'www', 'api', 'localhost', '127', 'admin', 'testserver'}

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        shop = self.resolve_tenant(request)

        # If a specific tenant was requested but could not be resolved
        if shop is False:
            return JsonResponse({'detail': 'Tenant shop not found.'}, status=404)

        if shop and getattr(shop, 'status', None) != 'ACTIVE':
            return JsonResponse({'detail': 'Tenant shop is inactive or suspended.'}, status=403)

        request.shop = shop
        token = set_current_tenant(shop)

        # PostgreSQL RLS session setting (Tier 2 defense-in-depth)
        if shop and connection.vendor == 'postgresql':
            with connection.cursor() as cursor:
                cursor.execute("SET LOCAL app.current_tenant = %s", [str(shop.id)])

        try:
            response = self.get_response(request)
            if shop and hasattr(response, '__setitem__'):
                response['X-Tenant-ID'] = str(shop.slug or shop.id)
            return response
        finally:
            set_current_tenant(None)

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

        # 5. Default fallback shop
        return Shop.objects.first()

    def get_shop_by_id_or_slug(self, identifier):
        if not identifier:
            return None
        # Try pk first if integer
        if identifier.isdigit():
            shop = Shop.objects.filter(pk=int(identifier)).first()
            if shop:
                return shop
        # Try slug
        shop = Shop.objects.filter(slug__iexact=identifier).first()
        if shop:
            return shop
        # Try subdomain
        shop = Shop.objects.filter(subdomain__iexact=identifier).first()
        if shop:
            return shop
        # Try name
        return Shop.objects.filter(name__iexact=identifier).first()
