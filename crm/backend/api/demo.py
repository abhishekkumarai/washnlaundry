"""Throwaway Demo Mode sandboxes.

`POST /api/demo/start/` clones the sample data into a private shop (slug
`demo-...`) with its own demo-only owner account and returns a short-lived
`Bearer demo.<token>`. The token only ever resolves to that one account, whose
single OWNER membership is that one shop, so nothing real is reachable.
`POST /api/demo/end/` (logout) deletes the shop and the account; anything
abandoned without logging out is purged once it is older than DEMO_TTL.
"""
import contextlib
import io
import json
import secrets
import sys
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core import signing
from django.core.cache import cache
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from .models import Credit, Shop, ShopMembership, ShopRole
from .netutils import client_ip

DEMO_DOMAIN = '@demo.invalid'
DEMO_SLUG_PREFIX = 'demo-'
DEMO_TOKEN_PREFIX = 'demo.'
DEMO_SALT = 'demo-session'
DEMO_TTL = timedelta(hours=3)
MAX_ACTIVE_DEMOS = 25
STARTS_PER_HOUR = 8

# Anything that can reach the outside world (WhatsApp, Instagram/Facebook, new
# tenants, bulk imports) is off limits to a demo account.
BLOCKED_PREFIXES = (
    '/api/meta', '/api/whatsapp/', '/api/shops/provision', '/api/link-requests/',
    '/api/backup/', '/api/auth/',
)


def is_demo_email(email):
    return (email or '').lower().endswith(DEMO_DOMAIN)


def mint_demo_token(user):
    return DEMO_TOKEN_PREFIX + signing.dumps({'e': user.email}, salt=DEMO_SALT)


def demo_token_email(token):
    """Email behind a `demo.` token, or None if bad, expired or already purged."""
    if not getattr(settings, 'DEMO_ENABLED', True):
        return None
    try:
        data = signing.loads(token, salt=DEMO_SALT, max_age=int(DEMO_TTL.total_seconds()))
    except signing.BadSignature:
        return None
    email = data.get('e')
    if not is_demo_email(email):
        return None
    exists = get_user_model().objects.filter(username=email, is_active=True).exists()
    return email if exists else None


def _demo_users():
    return get_user_model().objects.filter(username__endswith=DEMO_DOMAIN)


def _delete_shop(shop):
    # Credit.category is PROTECT, so credits must go before the shop's categories.
    Credit.all_objects.filter(shop=shop).delete()
    shop.delete()


def purge_demo_user(user):
    """Delete a demo account and every demo shop it owns (cascades to all shop data)."""
    shop_ids = list(ShopMembership.objects.filter(user=user, role=ShopRole.OWNER)
                    .values_list('shop_id', flat=True))
    for shop in Shop.objects.filter(pk__in=shop_ids, slug__startswith=DEMO_SLUG_PREFIX):
        _delete_shop(shop)
    user.delete()


def purge_expired_demos():
    """Remove demo sandboxes past their TTL. Returns how many were removed."""
    cutoff = timezone.now() - DEMO_TTL
    count = 0
    for user in _demo_users().filter(date_joined__lt=cutoff):
        purge_demo_user(user)
        count += 1
    # Demo shops whose account vanished (e.g. a crash mid-create).
    owned = ShopMembership.objects.filter(
        user__username__endswith=DEMO_DOMAIN).values_list('shop_id', flat=True)
    for shop in Shop.objects.filter(slug__startswith=DEMO_SLUG_PREFIX).exclude(pk__in=list(owned)):
        _delete_shop(shop)
        count += 1
    return count


def _seed_sandbox(slug):
    # backend/seed_db.py sits beside manage.py; make sure that folder is importable
    # under gunicorn too, and import lazily because it needs Django ready.
    if str(settings.BASE_DIR) not in sys.path:
        sys.path.insert(0, str(settings.BASE_DIR))
    import seed_db
    cfg = dict(seed_db.SHOPS[1])
    cfg['shop'] = dict(cfg['shop'], name='Demo Laundry', slug=slug, subdomain=slug,
                       email='demo@example.com')
    cfg.update(customers=slice(10, 32), staff=slice(0, 8), orders=36, expenses=12, credits=6)
    with contextlib.redirect_stdout(io.StringIO()):
        seed_db.seed_shop(cfg)
    return Shop.objects.get(slug=slug)


def _throttled(ip):
    key = f'demo_start:{ip}'
    cache.add(key, 0, 3600)
    try:
        return cache.incr(key) > STARTS_PER_HOUR
    except ValueError:
        cache.set(key, 1, 3600)
        return False


@csrf_exempt
@require_POST
def demo_start(request):
    """POST /api/demo/start/ -> {token, shop: {id, slug, name}}"""
    if not getattr(settings, 'DEMO_ENABLED', True):
        return JsonResponse({'detail': 'Demo Mode is disabled.'}, status=404)
    if _throttled(client_ip(request)):
        return JsonResponse({'detail': 'Too many demo sessions. Try again later.'}, status=429)
    purge_expired_demos()
    if _demo_users().count() >= MAX_ACTIVE_DEMOS:
        return JsonResponse({'detail': 'Demo is busy right now. Try again in a few minutes.'}, status=503)

    suffix = secrets.token_hex(5)
    slug = f'{DEMO_SLUG_PREFIX}{suffix}'
    email = f'{suffix}{DEMO_DOMAIN}'
    user = get_user_model().objects.create_user(username=email, email=email)
    user.set_unusable_password()
    user.save()
    try:
        shop = _seed_sandbox(slug)
        ShopMembership.objects.create(user=user, shop=shop, role=ShopRole.OWNER, is_default=True)
    except Exception:
        for leftover in Shop.objects.filter(slug=slug):
            _delete_shop(leftover)
        user.delete()
        raise
    return JsonResponse({
        'token': mint_demo_token(user),
        'shop': {'id': shop.pk, 'slug': shop.slug, 'name': shop.name},
        'expires_in': int(DEMO_TTL.total_seconds()),
    }, status=201)


@csrf_exempt
@require_POST
def demo_end(request):
    """POST /api/demo/end/ - deletes the caller's sandbox. Token in the Authorization
    header, or in the JSON body as `token` (so `navigator.sendBeacon` can use it)."""
    header = request.headers.get('Authorization', '')
    token = header[7:].strip() if header.lower().startswith('bearer ') else ''
    if not token:
        try:
            body = json.loads(request.body or b'{}')
            token = str(body.get('token') or '') if isinstance(body, dict) else ''
        except json.JSONDecodeError:
            token = ''
    if token.startswith(DEMO_TOKEN_PREFIX):
        email = demo_token_email(token[len(DEMO_TOKEN_PREFIX):])
        user = _demo_users().filter(username=email).first() if email else None
        if user:
            purge_demo_user(user)
    return JsonResponse({'ok': True})
