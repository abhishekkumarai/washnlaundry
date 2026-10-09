"""Email + password sign-in, alongside Google.

Accounts are Django `User` rows (username = lower-cased email, so passwords are
hashed by Django) that stay `is_active=False` until the emailed link proves the
address is theirs. That matters because roles are matched by email: without
verification, anyone could sign up as the owner's address and become owner.

Flow: signup -> verification email -> /verify?token -> session token.
      forgot-password -> reset email -> /reset?token + new password -> session token.
      login -> session token (only once verified).
The session token is `Bearer app.<signed>` (see auth.mint_session_token).

Everything here is csrf_exempt because callers authenticate with a token, never
a cookie. Login and signup are rate limited per IP and per email.
"""
import json
import logging
import re

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.core import signing
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.http import JsonResponse
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from .auth import (
    customer_for_email, is_owner_email, is_staff_email,
    mint_session_token, sync_user_groups,
)
from .customer_views import clean_phone, register_customer
from .services.email_service import EmailService

logger = logging.getLogger(__name__)

VERIFY_SALT = 'email-verify'
VERIFY_MAX_AGE = 3 * 24 * 3600
MIN_PASSWORD = 8
MAX_PASSWORD = 128
LOCAL_ORIGIN = re.compile(r'^http://(localhost|127\.0\.0\.1)(:\d+)?$')

_DUMMY_HASH = None


def _err(detail, status):
    return JsonResponse({'detail': detail}, status=status)


def _body(request):
    try:
        data = json.loads(request.body or b'{}')
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def _email(raw):
    email = str(raw or '').strip().lower()
    try:
        validate_email(email)
    except ValidationError:
        return None
    return email if len(email) <= 150 else None


def _client_ip(request):
    fwd = request.META.get('HTTP_X_FORWARDED_FOR', '')
    return (fwd.split(',')[0].strip() if fwd else request.META.get('REMOTE_ADDR', '')) or 'unknown'


def _throttled(key, limit, window=900):
    """True once `key` has been hit more than `limit` times within `window` seconds."""
    cache.add(key, 0, window)
    try:
        return cache.incr(key) > limit
    except ValueError:  # expired between add and incr
        cache.set(key, 1, window)
        return False


def _failures(key):
    return cache.get(key, 0)


def _record_failure(key, window=900):
    cache.add(key, 0, window)
    try:
        cache.incr(key)
    except ValueError:
        cache.set(key, 1, window)


def _origin(body, request):
    """Where the emailed link should land: the caller's own app if it is an allowed
    origin, else settings.APP_BASE_URL."""
    asked = str(body.get('return_to') or request.headers.get('Origin') or '').rstrip('/')
    if asked in settings.APP_ORIGINS or (settings.DEBUG and LOCAL_ORIGIN.match(asked)):
        return asked
    return settings.APP_BASE_URL.rstrip('/')


def _send(email, subject, text):
    ok, error = EmailService.send(email, subject, text)
    if not ok:
        logger.warning('Auth email to %s not delivered: %s', email, error)
        if settings.DEBUG:
            logger.warning('DEBUG auth email for %s:\n%s', email, text)
    return ok


def _gate(request):
    """(error_response, body). Common checks for every endpoint here."""
    if not settings.PASSWORD_AUTH_ENABLED:
        return _err('Email sign-in is not available yet.', 503), None
    body = _body(request)
    if body is None:
        return _err('Invalid JSON body.', 400), None
    return None, body


def _session(user):
    return JsonResponse({'token': mint_session_token(user), 'email': user.email})


def _send_verification(user, origin, phone=''):
    token = signing.dumps({'e': user.email, 'p': phone}, salt=VERIFY_SALT)
    return _send(
        user.email, 'Confirm your washnlaundry email',
        f'Welcome to washnlaundry!\n\nConfirm your email to finish creating your account:\n'
        f'{origin}/verify?token={token}\n\nThis link works for 3 days. If you did not sign '
        f'up, ignore this email.')


@csrf_exempt
@require_POST
def signup(request):
    err, body = _gate(request)
    if err:
        return err
    email = _email(body.get('email'))
    password = str(body.get('password') or '')
    if not email:
        return _err('Enter a valid email address.', 400)
    if not MIN_PASSWORD <= len(password) <= MAX_PASSWORD:
        return _err(f'Password must be {MIN_PASSWORD}-{MAX_PASSWORD} characters.', 400)
    phone = clean_phone(body.get('phone'))
    if not phone:
        return _err('Enter a valid phone number (10-15 digits).', 400)
    if _throttled(f'signup:ip:{_client_ip(request)}', 10, 3600) or _throttled(f'signup:{email}', 5, 3600):
        return _err('Too many attempts. Try again later.', 429)

    User = get_user_model()
    origin = _origin(body, request)
    user = User.objects.filter(username=email).first()
    if user is not None and user.is_active:
        # Same answer as a fresh signup (no way to probe which emails exist);
        # the real owner gets a nudge instead.
        _send(email, 'You already have a washnlaundry account',
              f'Someone tried to sign up with this email, but you already have an account.\n'
              f'Sign in at {origin} (use "Forgot password?" if needed).')
        return JsonResponse({'verify_sent': True}, status=201)
    if user is None:
        user = User(username=email, email=email, is_active=False)
    # An unverified signup can be overwritten: it can't sign in until the
    # mailbox owner clicks the link, so a squatter gains nothing.
    user.set_password(password)
    user.first_name = str(body.get('name') or '').strip()[:30]
    user.is_active = False
    user.save()
    if not _send_verification(user, origin, phone) and not settings.DEBUG:
        return _err('We could not send the confirmation email. Try again later.', 503)
    return JsonResponse({'verify_sent': True}, status=201)


@csrf_exempt
@require_POST
def verify_email(request):
    err, body = _gate(request)
    if err:
        return err
    try:
        data = signing.loads(str(body.get('token') or ''), salt=VERIFY_SALT, max_age=VERIFY_MAX_AGE)
    except signing.BadSignature:
        return _err('This confirmation link is invalid or has expired. Sign up again.', 400)
    user = get_user_model().objects.filter(username=data.get('e')).first()
    if user is None:
        return _err('This confirmation link is invalid or has expired. Sign up again.', 400)
    if not user.is_active:
        user.is_active = True
        user.save(update_fields=['is_active'])
    # The phone given at signup becomes their customer record (or a link request
    # if the store already has that number). Owner/staff emails keep their roles.
    phone = clean_phone(data.get('p'))
    if (phone and not is_owner_email(user.email) and not is_staff_email(user.email)
            and not customer_for_email(user.email)):
        register_customer(user.email, user.first_name or user.email.split('@')[0], phone)
    sync_user_groups(user)
    return _session(user)


@csrf_exempt
@require_POST
def login(request):
    global _DUMMY_HASH
    err, body = _gate(request)
    if err:
        return err
    email = _email(body.get('email'))
    password = str(body.get('password') or '')
    bad = _err('Incorrect email or password.', 401)
    if not email or not password or len(password) > MAX_PASSWORD:
        return bad
    ip_key, email_key = f'loginfail:ip:{_client_ip(request)}', f'loginfail:{email}'
    # Only failed attempts count, so signing in normally never locks anyone out.
    if _failures(ip_key) >= 30 or _failures(email_key) >= 8:
        return _err('Too many attempts. Try again in a few minutes.', 429)

    from django.contrib.auth.hashers import check_password, make_password
    user = get_user_model().objects.filter(username=email).first()
    if user is None:
        # Burn the same time as a real check so response time doesn't reveal accounts.
        if _DUMMY_HASH is None:
            _DUMMY_HASH = make_password('dummy-password')
        check_password(password, _DUMMY_HASH)
        _record_failure(ip_key), _record_failure(email_key)
        return bad
    if not user.check_password(password):
        _record_failure(ip_key), _record_failure(email_key)
        return bad
    if not user.is_active:
        return _err('Confirm your email first: check your inbox for the link.', 403)
    cache.delete(email_key)
    sync_user_groups(user)
    return _session(user)


@csrf_exempt
@require_POST
def forgot_password(request):
    err, body = _gate(request)
    if err:
        return err
    email = _email(body.get('email'))
    done = JsonResponse({'ok': True})
    if not email:
        return done
    if _throttled(f'forgot:ip:{_client_ip(request)}', 10, 3600) or _throttled(f'forgot:{email}', 3, 3600):
        return _err('Too many attempts. Try again later.', 429)
    user = get_user_model().objects.filter(username=email).first()
    if user is not None:
        # Django's own reset token: tied to the password hash and last login, so
        # it dies once used, and expires after settings.PASSWORD_RESET_TIMEOUT.
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        token = f'{uid}.{default_token_generator.make_token(user)}'
        _send(email, 'Reset your washnlaundry password',
              f'Reset your password here (valid for 1 hour):\n'
              f'{_origin(body, request)}/reset?token={token}\n\nIf you did not ask for this, ignore this email.')
    return done


@csrf_exempt
@require_POST
def reset_password(request):
    err, body = _gate(request)
    if err:
        return err
    password = str(body.get('password') or '')
    if not MIN_PASSWORD <= len(password) <= MAX_PASSWORD:
        return _err(f'Password must be {MIN_PASSWORD}-{MAX_PASSWORD} characters.', 400)
    invalid = _err('This reset link is invalid or has expired. Request a new one.', 400)
    uid, _, token = str(body.get('token') or '').partition('.')
    try:
        user = get_user_model().objects.filter(pk=force_str(urlsafe_base64_decode(uid))).first()
    except (ValueError, TypeError, OverflowError):
        user = None
    if user is None or not default_token_generator.check_token(user, token):
        return invalid
    user.set_password(password)
    user.is_active = True  # they just proved they own the mailbox
    user.save()
    return _session(user)
