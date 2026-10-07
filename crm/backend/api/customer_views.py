"""Customer-portal API (customer.washnlaundry.com).

Unlike the rest of /api/, these endpoints are scoped to one signed-in customer.
The caller sends a Google ID token as `Authorization: Bearer <token>`; it is
verified against GOOGLE_CLIENT_ID and the customer is matched by verified email.
Stateless: no sessions, nothing stored. Responses are deliberately minimal
(no notes, agent, or audit log) so staff-only data never leaves the CRM.
"""
import json
import re

from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods

from google.oauth2 import id_token  # noqa: F401  (tests patch api.customer_views.id_token)

from .auth import customer_for_email, normalize_phone, verified_email
from .models import Customer, EmailLinkRequest, GarmentCategory, Order

_STATUS_TIMESTAMPS = (
    'placed_at', 'processing_at', 'ironing_at', 'ready_at',
    'out_for_delivery_at', 'delivered_at', 'cancelled_at',
)


def _customer_for(request):
    """(customer, error_response). Exactly one is None."""
    email = verified_email(request)
    if not email:
        return None, JsonResponse({'detail': 'Sign in required.'}, status=401)
    customer = customer_for_email(email)
    if customer is None:
        pending = EmailLinkRequest.objects.filter(
            email__iexact=email, status=EmailLinkRequest.PENDING).exists()
        return None, JsonResponse(
            {'detail': 'No account is linked to this email.', 'email': email,
             'pending': pending}, status=404)
    return customer, None


def _iso(value):
    return value.isoformat() if value else None


def _order_json(order):
    data = {
        'id': str(order.id),
        'order_number': order.order_number,
        'customer': str(order.customer_id or ''),
        'customer_name': order.customer_name,
        'customer_phone': order.customer_phone,
        'status': order.status,
        'payment_status': order.payment_status,
        'payment_method': order.payment_method,
        'delivery_type': order.delivery_type,
        'source': order.source,
        'express': order.express,
        'subtotal': order.subtotal,
        'delivery_charge': order.delivery_charge,
        'discount_amount': order.discount_amount,
        'total_amount': order.total_amount,
        'paid_amount': order.paid_amount,
        'due_amount': order.due_amount,
        'scheduled_date': _iso(order.scheduled_date),
        'scheduled_time': _iso(order.scheduled_time),
        'pickup_date': _iso(order.pickup_date),
        'pickup_time': _iso(order.pickup_time),
        'created_at': _iso(order.created_at),
        'items': [
            {
                'item_title': i.item_title,
                'title': i.item_title,
                'service_type': i.service_type,
                'quantity': i.quantity,
                'unit': i.unit,
                'unit_price': i.unit_price,
                'total_price': i.total_price,
            }
            for i in order.items.all()
        ],
    }
    for field in _STATUS_TIMESTAMPS:
        data[field] = _iso(getattr(order, field))
    return data


def _me_json(customer):
    return {
        'name': customer.name,
        'email': customer.email,
        'total_orders': customer.total_orders,
        'total_spent': customer.total_spent,
        'due_amount': customer.due_amount,
    }


def clean_phone(raw):
    """The phone with spaces/dashes removed if it looks valid (10-15 digits, optional +), else None."""
    phone = re.sub(r'[\s-]', '', str(raw or ''))
    return phone if re.fullmatch(r'\+?\d{10,15}', phone) else None


def register_customer(email, name, phone):
    """(customer, pending). A phone the store already has queues an EmailLinkRequest
    for staff to approve instead of linking; otherwise a new Customer is created."""
    existing = Customer.objects.filter(phone__endswith=normalize_phone(phone)).first()
    if existing:
        EmailLinkRequest.objects.get_or_create(
            customer=existing, email=email, status=EmailLinkRequest.PENDING)
        return existing, True
    return Customer.objects.create(name=name, phone=phone, email=email), False


# csrf_exempt: auth is a Bearer token, never a cookie, so there is nothing for
# CSRF to protect (and a browser client has no CSRF cookie to send).
@csrf_exempt
@require_http_methods(['GET', 'POST'])
def customer_me(request):
    """GET: the signed-in customer. POST {name, phone}: first-time signup.

    Signup creates a Customer for the verified email. A phone that already
    belongs to a customer queues an EmailLinkRequest for staff to approve (202)
    instead of linking: without an OTP, linking directly would let anyone claim
    a stranger's order history by typing their number.
    """
    if request.method == 'GET':
        customer, err = _customer_for(request)
        return err or JsonResponse(_me_json(customer))

    email = verified_email(request)
    if not email:
        return JsonResponse({'detail': 'Sign in required.'}, status=401)
    if customer_for_email(email):
        return JsonResponse({'detail': 'Account already exists.'}, status=409)
    try:
        body = json.loads(request.body or b'{}')
    except json.JSONDecodeError:
        return JsonResponse({'detail': 'Invalid JSON body.'}, status=400)
    name = str(body.get('name') or '').strip()[:255]
    phone = clean_phone(body.get('phone'))
    if not name or not phone:
        return JsonResponse({'detail': 'Enter your name and a valid phone number.'}, status=400)
    customer, pending = register_customer(email, name, phone)
    if pending:
        return JsonResponse({
            'pending': True,
            'detail': 'That number is already registered with the store. We have asked the '
                      'store to link your email; your orders appear once it is approved.'},
            status=202)
    return JsonResponse(_me_json(customer), status=201)


@require_GET
def customer_orders(request):
    customer, err = _customer_for(request)
    if err:
        return err
    orders = customer.orders.prefetch_related('items').order_by('-created_at')
    return JsonResponse({'orders': [_order_json(o) for o in orders]})


@require_GET
def customer_order_detail(request, order_number):
    customer, err = _customer_for(request)
    if err:
        return err
    # Scoped to the caller's own orders: someone else's number is a plain 404.
    order = customer.orders.prefetch_related('items').filter(order_number=order_number).first()
    if order is None:
        return JsonResponse({'detail': 'Order not found.'}, status=404)
    return JsonResponse(_order_json(order))


@require_GET
def customer_rate_card(request):
    """Public, read-only price list: active categories with their active items."""
    categories = GarmentCategory.objects.filter(is_active=True).order_by('display_order', 'id')
    payload = []
    for cat in categories:
        items = [
            {'name': i.name, 'price': i.price, 'unit': i.unit}
            for i in cat.items.filter(is_active=True)
        ]
        if items:
            payload.append({'name': cat.name, 'items': items})
    return JsonResponse({'categories': payload})
