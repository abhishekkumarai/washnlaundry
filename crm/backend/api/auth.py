"""Server-verified identity and roles for the CRM API.

The CRM and the customer portal share one Google login. The Google ID token
(`Authorization: Bearer <token>`) is verified against GOOGLE_CLIENT_ID, and the
verified email decides the role:

* owner    - an address in the STAFF_EMAILS env allow-list, or an ACTIVE `Staff`
             row with that email whose `role` is Owner or Manager. Everything.
* staff    - any other ACTIVE `Staff` row with `has_app_login` and that email.
             Day-to-day work only: orders, customers, scanning. No payroll,
             reports, expenses, staff management or settings.
* customer - a `Customer` row with that email.
* unlinked - signed in with Google but matches neither.

Enforcement is gated by settings.API_AUTH_ENFORCED so the Flutter app can ship
token-sending first and the API can be locked down afterwards.
"""
from dataclasses import dataclass
from typing import Optional

from django.conf import settings
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import SAFE_METHODS, BasePermission

from .models import Customer, Staff

OWNER = 'owner'
STAFF = 'staff'
CUSTOMER = 'customer'
UNLINKED = 'unlinked'


def verified_email(request):
    """Return the Google-verified, lower-cased email from the Bearer token, else None."""
    header = request.headers.get('Authorization', '')
    if not header.lower().startswith('bearer ') or not settings.GOOGLE_CLIENT_ID:
        return None
    try:
        claims = id_token.verify_oauth2_token(
            header[7:].strip(), google_requests.Request(), settings.GOOGLE_CLIENT_ID)
    except ValueError:
        return None
    if not claims.get('email_verified') or not claims.get('email'):
        return None
    return claims['email'].strip().lower()


def normalize_phone(raw):
    """Last 10 digits of a phone typed any usual way (+91, 0 prefix, spaces), else None."""
    digits = ''.join(ch for ch in str(raw or '') if ch.isdigit())
    return digits[-10:] if len(digits) >= 10 else None


def customer_for_email(email):
    # Customer.email isn't unique, so pick deterministically (oldest record).
    return Customer.objects.filter(email__iexact=email).order_by('created_at').first()


OWNER_JOB_TITLES = ('owner', 'manager')


def _active_staff(email):
    return Staff.objects.filter(email__iexact=email, has_app_login=True, status='ACTIVE')


def is_owner_email(email):
    if email in settings.STAFF_EMAILS:
        return True
    return any(
        s.role.strip().lower() in OWNER_JOB_TITLES for s in _active_staff(email))


def is_staff_email(email):
    return _active_staff(email).exists()


@dataclass
class Principal:
    """What `request.user` is for a verified Google caller (not a Django User)."""
    email: str
    role: str
    customer: Optional[Customer] = None
    is_authenticated: bool = True


def resolve_principal(email):
    if is_owner_email(email):
        return Principal(email, OWNER)
    if is_staff_email(email):
        return Principal(email, STAFF)
    customer = customer_for_email(email)
    if customer:
        return Principal(email, CUSTOMER, customer=customer)
    return Principal(email, UNLINKED)


class GoogleTokenAuthentication(BaseAuthentication):
    def authenticate(self, request):
        if not request.headers.get('Authorization'):
            return None
        email = verified_email(request)
        if not email:
            if settings.API_AUTH_ENFORCED:
                raise AuthenticationFailed('Invalid or expired Google sign-in.')
            return None
        return resolve_principal(email), None

    def authenticate_header(self, request):
        return 'Bearer'


class IsStaff(BasePermission):
    """Day-to-day CRM access for owner and staff. Open when enforcement is off."""

    def has_permission(self, request, view):
        if not settings.API_AUTH_ENFORCED:
            return True
        user = request.user
        return isinstance(user, Principal) and user.role in (OWNER, STAFF)


class IsOwner(BasePermission):
    """Owner-only: money, payroll, reports, staff management, settings."""

    def has_permission(self, request, view):
        if not settings.API_AUTH_ENFORCED:
            return True
        user = request.user
        return isinstance(user, Principal) and user.role == OWNER


class IsOwnerOrStaffReadOnly(BasePermission):
    """Staff may read (e.g. the catalogue, shop details); only the owner may change."""

    def has_permission(self, request, view):
        if not settings.API_AUTH_ENFORCED:
            return True
        user = request.user
        if not isinstance(user, Principal):
            return False
        if user.role == OWNER:
            return True
        return user.role == STAFF and request.method in SAFE_METHODS


class IsSignedIn(BasePermission):
    """Any verified Google caller, whatever their role."""

    def has_permission(self, request, view):
        return isinstance(request.user, Principal)
