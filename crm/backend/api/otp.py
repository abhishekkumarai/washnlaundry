"""One-time sign-in codes, behind one interface (customer portal, KAN-216).

`get_otp_sender()` picks the delivery channel from settings.OTP_SENDER, the way
media_storage.py picks its backend. Only `email` exists today (the Resend mailer
password_auth.py already uses, so it is free); a phone channel such as MSG91,
Firebase or WhatsApp is a new OtpSender subclass registered in SENDERS, with no
change to the views.

Endpoints (both csrf_exempt: no cookies involved):
  POST /api/auth/email-code/request/ {email}       -> always 200, never says whether the email exists
  POST /api/auth/email-code/verify/  {email, code} -> {token, email}, the same `app.` session token
                                                      email + password sign-in issues
"""
import hmac
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.http import JsonResponse
from django.utils import timezone
from django.utils.crypto import salted_hmac
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from .models import EmailOtp

CODE_DIGITS = 6
CODE_TTL = timedelta(minutes=10)
MAX_ATTEMPTS = 5


class OtpSender:
    """Delivers a code to a destination (an email today; a phone later)."""

    def send(self, destination, code):  # -> bool
        raise NotImplementedError


class EmailOtpSender(OtpSender):
    def send(self, destination, code):
        from .password_auth import _send
        minutes = int(CODE_TTL.total_seconds() // 60)
        return _send(
            destination, f'{code} is your washnlaundry sign-in code',
            f'Your washnlaundry sign-in code is {code}\n\nIt works once, for {minutes} minutes. '
            f'If you did not ask for it, ignore this email.')


SENDERS = {'email': EmailOtpSender}


def get_otp_sender():
    return SENDERS[getattr(settings, 'OTP_SENDER', 'email') or 'email']()


def _hash(email, code):
    return salted_hmac('email-otp', f'{email}:{code}').hexdigest()


def issue_code(email):
    """Replace any open code for `email` with a fresh one; returns the plain code."""
    code = f'{secrets.randbelow(10 ** CODE_DIGITS):0{CODE_DIGITS}d}'
    now = timezone.now()
    EmailOtp.objects.filter(email=email, used_at__isnull=True).update(used_at=now)
    EmailOtp.objects.create(email=email, code_hash=_hash(email, code), expires_at=now + CODE_TTL)
    return code


def _dev_code_matches(email, code):
    """Local testing: settings.DEV_LOGIN_CODE signs in the DEV_LOGIN_EMAILS (both
    empty unless DEBUG; see settings.py)."""
    dev = getattr(settings, 'DEV_LOGIN_CODE', '')
    return bool(dev) and settings.DEBUG and email.lower() in getattr(settings, 'DEV_LOGIN_EMAILS', ()) \
        and hmac.compare_digest(str(code), dev)


def check_code(email, code):
    """True if `code` is the open, unexpired code for `email`; burns it either way
    once MAX_ATTEMPTS wrong guesses have been made."""
    if _dev_code_matches(email, code):
        return True
    now = timezone.now()
    with transaction.atomic():
        otp = EmailOtp.objects.select_for_update().filter(
            email=email, used_at__isnull=True, expires_at__gt=now).first()
        if otp is None:
            return False
        if hmac.compare_digest(otp.code_hash, _hash(email, code)):
            otp.used_at = now
            otp.save(update_fields=['used_at'])
            return True
        otp.attempts += 1
        if otp.attempts >= MAX_ATTEMPTS:
            otp.used_at = now
        otp.save(update_fields=['attempts', 'used_at'])
        return False


@csrf_exempt
@require_POST
def email_code_request(request):
    from .password_auth import _client_ip, _email, _err, _gate, _throttled
    err, body = _gate(request)
    if err:
        return err
    email = _email(body.get('email'))
    if not email:
        return _err('Enter a valid email address.', 400)
    if _throttled(f'otp:ip:{_client_ip(request)}', 10, 3600) or _throttled(f'otp:{email}', 5, 3600):
        return _err('Too many codes requested. Try again later.', 429)
    if not get_otp_sender().send(email, issue_code(email)) and not settings.DEBUG:
        return _err('We could not send the code. Try again later.', 503)
    return JsonResponse({'sent': True})


@csrf_exempt
@require_POST
def email_code_verify(request):
    from .auth import sync_user_groups
    from .password_auth import _client_ip, _email, _err, _gate, _session, _throttled
    err, body = _gate(request)
    if err:
        return err
    email = _email(body.get('email'))
    code = ''.join(ch for ch in str(body.get('code') or '') if ch.isdigit())
    if not email or len(code) != CODE_DIGITS:
        return _err('Enter the 6-digit code from the email.', 400)
    if _throttled(f'otp-verify:ip:{_client_ip(request)}', 30, 3600):
        return _err('Too many attempts. Try again later.', 429)
    if not check_code(email, code):
        return _err('That code is wrong or has expired. Request a new one.', 400)
    User = get_user_model()
    user = User.objects.filter(username__iexact=email).first()
    if user is None:
        user = User(username=email, email=email)
        user.set_unusable_password()
    elif not user.is_active:
        # An unverified password signup may be a squatter's (signup lets anyone
        # set it): activating it must not make their password work.
        user.set_unusable_password()
    user.is_active = True
    user.save()
    sync_user_groups(user)
    return _session(user)
