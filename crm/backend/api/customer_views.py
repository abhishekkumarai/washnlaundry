"""Customer-portal API (customer.washnlaundry.com).

Unlike the rest of /api/, these endpoints are scoped to one signed-in customer.
The caller sends a Google ID token as `Authorization: Bearer <token>`; it is
verified against GOOGLE_CLIENT_ID and the customer is matched by verified email.
Stateless: no sessions, nothing stored. Responses are deliberately minimal
(no notes, agent, or audit log) so staff-only data never leaves the CRM.
"""
import json
import re
from datetime import date, timedelta

from django.conf import settings
from django.db import IntegrityError, transaction
from django.db.models import Count, Q
from django.db.models.functions import TruncDate
from django.http import HttpResponse, JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods

from google.oauth2 import id_token  # noqa: F401  (tests patch api.customer_views.id_token)

from .auth import customer_for_email, normalize_phone, verified_email
from .models import (
    Customer, CustomerAddress, DeliveryType, EmailLinkRequest, GarmentCategory, GarmentItem, Order, OrderIssue,
    OrderItem, OrderSource, OrderStatus, PaymentStatus, ServiceArea, Shop, ShopMembership, ShopRole, TimeSlot,
)

_STATUS_TIMESTAMPS = (
    'placed_at', 'processing_at', 'ironing_at', 'ready_at',
    'out_for_delivery_at', 'delivered_at', 'cancelled_at',
)


def shop_customer(email, shop=None):
    """The Customer row `email` acts as. With a shop (the active tenant), only that
    shop's row; without one, the shop of their default CUSTOMER membership, falling
    back to the oldest matching row (single-shop deployments)."""
    from .tenancy import get_current_tenant
    shop = shop or get_current_tenant()
    if shop:
        return Customer.all_objects.filter(shop=shop, email__iexact=email).order_by('created_at').first()
    m = ShopMembership.objects.filter(
        user__username__iexact=email, role=ShopRole.CUSTOMER, is_active=True,
        shop__status='ACTIVE').select_related('shop').first()  # Meta ordering: default first
    if m:
        found = Customer.all_objects.filter(shop=m.shop, email__iexact=email).order_by('created_at').first()
        if found:
            return found
    return customer_for_email(email)


def _customer_for(request):
    """(customer, error_response). Exactly one is None."""
    email = verified_email(request)
    if not email:
        return None, JsonResponse({'detail': 'Sign in required.'}, status=401)
    customer = shop_customer(email)
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
        'address': order.address,
        'pin_code': order.pin_code,
        'latitude': order.latitude,
        'longitude': order.longitude,
        # Not `notes`: staff append their own (status reasons) to it.
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


def profile_json(customer):
    """The customer's own details, as /api/me/ and /api/customer/me/ report them."""
    return {
        'id': str(customer.id),
        'name': customer.name,
        'email': customer.email,
        'phone': customer.phone,
        'address': customer.address or '',
        'area': customer.area,
        'landmark': customer.landmark,
        'preference': customer.preference,
    }


def _me_json(customer):
    return {
        **profile_json(customer),
        'total_orders': customer.total_orders,
        'total_spent': customer.total_spent,
        'due_amount': customer.due_amount,
    }


def clean_phone(raw):
    """The phone with spaces/dashes removed if it is strictly 10 digits (starting 6-9, optional 91 or +91 country code), else None."""
    digits = re.sub(r'\D', '', str(raw or ''))
    if len(digits) == 12 and digits.startswith('91'):
        digits = digits[2:]
    return digits if re.fullmatch(r'[6-9]\d{9}', digits) else None


def register_customer(email, name, phone):
    """(customer, pending). A phone the store already has queues an EmailLinkRequest
    for staff to approve instead of linking; otherwise a new Customer is created."""
    existing = Customer.objects.filter(phone__endswith=normalize_phone(phone)).first()
    if existing:
        EmailLinkRequest.objects.get_or_create(
            customer=existing, email=email, status=EmailLinkRequest.PENDING)
        return existing, True
    return Customer.objects.create(name=name, phone=phone, email=email), False


# Fields a customer may edit about themselves, with their max lengths. Email is
# deliberately not here (the sign-in is matched on it); phone is validated apart.
_PROFILE_FIELDS = {'name': 255, 'address': 1000, 'area': 120, 'landmark': 255,
                   'preference': 1000}


def _update_profile(request):
    customer, err = _customer_for(request)
    if err:
        return err
    try:
        body = json.loads(request.body or b'{}')
    except json.JSONDecodeError:
        return JsonResponse({'detail': 'Invalid JSON body.'}, status=400)
    if not isinstance(body, dict):
        return JsonResponse({'detail': 'Invalid JSON body.'}, status=400)
    changed = []
    if 'phone' in body:
        # Safe to edit now that orders are matched by the Customer FK (KAN-220),
        # but it must stay unique within the shop.
        phone = clean_phone(body['phone'])
        if not phone:
            return JsonResponse({'detail': 'Enter a valid 10-digit mobile number.'}, status=400)
        taken = Customer.objects.filter(shop=customer.shop, phone__endswith=phone).exclude(pk=customer.pk)
        if taken.exists():
            return JsonResponse({'detail': 'That number is already registered with this shop.'}, status=409)
        customer.phone = phone
        changed.append('phone')
    for field, limit in _PROFILE_FIELDS.items():
        if field in body:
            value = str(body[field] or '').strip()[:limit]
            if field == 'name' and not value:
                return JsonResponse({'detail': 'Name cannot be empty.'}, status=400)
            setattr(customer, field, value)
            changed.append(field)
    if changed:
        customer.save(update_fields=changed)
    return JsonResponse(_me_json(customer))


# csrf_exempt: auth is a Bearer token, never a cookie, so there is nothing for
# CSRF to protect (and a browser client has no CSRF cookie to send).
@csrf_exempt
@require_http_methods(['GET', 'POST', 'PATCH'])
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

    if request.method == 'PATCH':
        return _update_profile(request)

    # Customer self-registration is switched off for now (restore the block below to
    # re-enable, together with password_auth.verify_email).
    return JsonResponse({'detail': 'Customer sign-up is not available right now.'}, status=403)
    # email = verified_email(request)
    # if not email:
    #     return JsonResponse({'detail': 'Sign in required.'}, status=401)
    # if customer_for_email(email):
    #     return JsonResponse({'detail': 'Account already exists.'}, status=409)
    # try:
    #     body = json.loads(request.body or b'{}')
    # except json.JSONDecodeError:
    #     return JsonResponse({'detail': 'Invalid JSON body.'}, status=400)
    # name = str(body.get('name') or '').strip()[:255]
    # phone = clean_phone(body.get('phone'))
    # if not name or not phone:
    #     return JsonResponse({'detail': 'Enter your name and a valid phone number.'}, status=400)
    # try:
    #     customer, pending = register_customer(email, name, phone)
    # except ValueError:  # several shops and none to file this customer under
    #     return JsonResponse({'detail': 'Sign-up is not available for this store yet. Please call us.'}, status=503)
    # if pending:
    #     return JsonResponse({
    #         'pending': True,
    #         'detail': 'That number is already registered with the store. We have asked the '
    #                   'store to link your email; your orders appear once it is approved.'},
    #         status=202)
    # return JsonResponse(_me_json(customer), status=201)


BOOKING_DAYS = 7          # how far ahead pickup slots are offered
MAX_BOOKING_LINES = 50
MAX_LINE_QUANTITY = 100


def _slot_label(slot):
    return f'{slot.start_time:%I:%M %p} - {slot.end_time:%I:%M %p}'


def _slot_booked(slot, day):
    """Live orders already taking `slot` on `day` (cancelled ones free their place)."""
    return Order.objects.filter(
        shop=slot.shop, pickup_date=day, pickup_time=slot.start_time,
    ).exclude(status=OrderStatus.CANCELLED).count()


def _slot_closed(slot, day):
    """True once `slot` on `day` is past the shop's booking cutoff
    (Shop.pickup_buffer_minutes before it starts)."""
    from datetime import datetime
    starts = timezone.make_aware(datetime.combine(day, slot.start_time))
    return starts - timedelta(minutes=slot.shop.pickup_buffer_minutes or 0) <= timezone.now()


def _served_pincodes(shop):
    return sorted({a.pin_code.strip() for a in ServiceArea.objects.filter(shop=shop, is_active=True)
                   if a.pin_code.strip()})


@require_GET
def customer_booking_options(request):
    """What a signed-in customer can book: items with ids and server prices, pickup
    slots with remaining capacity for the next BOOKING_DAYS days, served pincodes."""
    customer, err = _customer_for(request)
    if err:
        return err
    shop = customer.shop
    categories = []
    for cat in GarmentCategory.objects.filter(shop=shop, is_active=True).order_by('display_order', 'id'):
        items = [{'id': i.id, 'name': i.name, 'price': i.price, 'unit': i.unit,
                  'image_url': i.image_url}
                 for i in cat.items.filter(is_active=True)]
        if items:
            categories.append({'id': cat.id, 'name': cat.name, 'items': items})
    slots = list(TimeSlot.objects.select_related('shop').filter(
        shop=shop, kind=TimeSlot.PICKUP, is_active=True))
    today = timezone.localdate()
    days = []
    for offset in range(BOOKING_DAYS):
        day = today + timedelta(days=offset)
        day_slots = []
        for slot in slots:
            if _slot_closed(slot, day):
                continue  # too late to book today
            remaining = None if slot.capacity is None else max(slot.capacity - _slot_booked(slot, day), 0)
            day_slots.append({'id': slot.id, 'label': _slot_label(slot),
                              'start_time': _iso(slot.start_time), 'end_time': _iso(slot.end_time),
                              'remaining': remaining})
        days.append({'date': day.isoformat(), 'slots': day_slots})
    return JsonResponse({'categories': categories, 'days': days,
                         'pincodes': _served_pincodes(shop)})


def _alert_shop(order_pk):
    """Email the shop a new online booking (KAN-224). Best effort: a mail failure is
    logged and never fails the booking; the CRM's orders/changes poll still shows it."""
    import logging
    from .services.email_service import EmailService
    order = Order.all_objects.select_related('shop').prefetch_related('items').filter(pk=order_pk).first()
    if order is None or not order.shop.email:
        return
    lines = '\n'.join(f'  {i.quantity} x {i.item_title} ({i.service_type}) - {i.total_price:g}'
                      for i in order.items.all())
    where = order.address + (f' - {order.pin_code}' if order.pin_code else '')
    if order.latitude is not None:
        where += f'\n  Map: https://www.google.com/maps?q={order.latitude},{order.longitude}'
    text = (f'New online booking {order.order_number} from {order.customer_name} '
            f'({order.customer_phone}).\n\nPickup: {order.pickup_date:%a %d %b} at '
            f'{order.pickup_time:%I:%M %p}\nAddress: {where}\n\nItems:\n{lines}\n'
            f'Total: {order.shop.currency_symbol}{order.total_amount:g}\n'
            + (f'\nNotes: {order.notes}\n' if order.notes else '')
            + '\nOpen it in the CRM: https://app.washnlaundry.com/orders')
    ok, error = EmailService.send(order.shop.email, f'New booking {order.order_number}', text)
    if not ok:
        logging.getLogger(__name__).warning('Booking alert for %s not sent: %s', order.order_number, error)


def _bad(detail, status=400):
    return JsonResponse({'detail': detail}, status=status)


def _read_json(request):
    """(dict, error_response)."""
    try:
        body = json.loads(request.body or b'{}')
    except json.JSONDecodeError:
        return None, _bad('Invalid JSON body.')
    if not isinstance(body, dict):
        return None, _bad('Invalid JSON body.')
    return body, None


def _clean_address(body):
    """({address, landmark, area, pin_code, latitude, longitude}, error_response)."""
    place = {
        'address': str(body.get('address') or '').strip()[:1000],
        'landmark': str(body.get('landmark') or '').strip()[:255],
        'area': str(body.get('area') or '').strip()[:120],
        'pin_code': re.sub(r'\D', '', str(body.get('pin_code') or '')),
    }
    if not place['address']:
        return None, _bad('Enter the pickup address.')
    if not re.fullmatch(r'\d{6}', place['pin_code']):
        return None, _bad('Enter a 6-digit pincode.')
    for name, limit in (('latitude', 90), ('longitude', 180)):
        raw = body.get(name)
        try:
            value = None if raw in (None, '') else float(raw)
        except (TypeError, ValueError):
            return None, _bad('Invalid map location.')
        if value is not None and not -limit <= value <= limit:
            return None, _bad('Invalid map location.')
        place[name] = value
    if (place['latitude'] is None) != (place['longitude'] is None):
        return None, _bad('Invalid map location.')
    return place, None


def _address_json(a):
    return {'id': a.id, 'label': a.label, 'address': a.address, 'landmark': a.landmark,
            'area': a.area, 'pin_code': a.pin_code, 'latitude': a.latitude,
            'longitude': a.longitude, 'is_default': a.is_default}


MAX_ADDRESSES = 10


def _make_default(address):
    address.customer.addresses.exclude(pk=address.pk).filter(is_default=True).update(is_default=False)
    if not address.is_default:
        address.is_default = True
        address.save(update_fields=['is_default'])


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def customer_addresses(request):
    """GET: the customer's address book. POST: add an address (the first one, or
    one sent with is_default, becomes the default)."""
    customer, err = _customer_for(request)
    if err:
        return err
    if request.method == 'GET':
        return JsonResponse({'addresses': [_address_json(a) for a in customer.addresses.all()]})
    body, err = _read_json(request)
    if err:
        return err
    if customer.addresses.count() >= MAX_ADDRESSES:
        return _bad(f'At most {MAX_ADDRESSES} saved addresses.')
    place, err = _clean_address(body)
    if err:
        return err
    label = body.get('label') if body.get('label') in dict(CustomerAddress.LABEL_CHOICES) else CustomerAddress.HOME
    address = CustomerAddress.objects.create(customer=customer, shop=customer.shop, label=label, **place)
    if body.get('is_default') or customer.addresses.count() == 1:
        _make_default(address)
    return JsonResponse(_address_json(address), status=201)


@csrf_exempt
@require_http_methods(['PATCH', 'DELETE'])
def customer_address_detail(request, address_id):
    customer, err = _customer_for(request)
    if err:
        return err
    # Scoped to the caller's own book: someone else's id is a plain 404.
    address = customer.addresses.filter(pk=address_id).first()
    if address is None:
        return _bad('Address not found.', status=404)
    if request.method == 'DELETE':
        was_default = address.is_default
        address.delete()
        nxt = customer.addresses.order_by('created_at').first()
        if was_default and nxt:
            _make_default(nxt)
        return HttpResponse(status=204)
    body, err = _read_json(request)
    if err:
        return err
    place, err = _clean_address({**_address_json(address), **body})
    if err:
        return err
    for field, value in place.items():
        setattr(address, field, value)
    if body.get('label') in dict(CustomerAddress.LABEL_CHOICES):
        address.label = body['label']
    address.save()
    if body.get('is_default'):
        _make_default(address)
    return JsonResponse(_address_json(address))


def _create_customer_order(request, customer):
    """POST /api/customer/orders/. Only whitelisted fields are read; prices, totals,
    customer, delivery type, status and payment are all decided here, never by the client."""
    from .password_auth import _throttled  # local import: password_auth imports this module

    shop = customer.shop
    key = (request.headers.get('Idempotency-Key') or '').strip()[:64] or None
    if key:
        existing = Order.objects.filter(shop=shop, idempotency_key=key, customer=customer).first()
        if existing:
            return JsonResponse(_order_json(existing), status=200)
    if _throttled(f'customer-order:{customer.id}', limit=10, window=3600):
        return _bad('Too many bookings. Please try again later.', status=429)
    try:
        body = json.loads(request.body or b'{}')
    except json.JSONDecodeError:
        return _bad('Invalid JSON body.')
    if not isinstance(body, dict):
        return _bad('Invalid JSON body.')

    # Items: [{item_id, quantity}] -> this shop's active GarmentItems at their own prices.
    lines = body.get('items')
    if not isinstance(lines, list) or not lines:
        return _bad('Add at least one item.')
    if len(lines) > MAX_BOOKING_LINES:
        return _bad(f'At most {MAX_BOOKING_LINES} items per booking.')
    wanted = []
    for line in lines:
        try:
            item_id, qty = int(line['item_id']), int(line.get('quantity', 1))
        except (KeyError, TypeError, ValueError):
            return _bad('Each item needs an item_id and a whole-number quantity.')
        if not 1 <= qty <= MAX_LINE_QUANTITY:
            return _bad(f'Quantity must be between 1 and {MAX_LINE_QUANTITY}.')
        wanted.append((item_id, qty))
    catalogue = {i.id: i for i in GarmentItem.objects.select_related('category').filter(
        shop=shop, is_active=True, category__is_active=True, id__in=[i for i, _ in wanted])}
    if any(item_id not in catalogue for item_id, _ in wanted):
        return _bad('Some items are no longer available. Refresh and try again.')

    # Pickup slot, enforced against its capacity.
    try:
        day = date.fromisoformat(str(body.get('pickup_date') or ''))
        slot = TimeSlot.objects.get(shop=shop, kind=TimeSlot.PICKUP, is_active=True,
                                    id=int(body.get('slot_id')))
    except (ValueError, TypeError, TimeSlot.DoesNotExist):
        return _bad('Choose a pickup date and time slot.')
    today = timezone.localdate()
    if not today <= day < today + timedelta(days=BOOKING_DAYS) or _slot_closed(slot, day):
        return _bad('That pickup slot is not available. Choose another.')

    # Address (a saved one by id, or typed in), copied onto the order; the
    # pincode must be one the shop serves.
    if body.get('address_id') not in (None, ''):
        saved = customer.addresses.filter(pk=body.get('address_id')).first() \
            if str(body.get('address_id')).isdigit() else None
        if saved is None:
            return _bad('That saved address no longer exists.')
        body = {**body, **_address_json(saved)}
    place, err = _clean_address(body)
    if err:
        return err
    served = _served_pincodes(shop)
    if served and place['pin_code'] not in served:
        return _bad('Sorry, we do not pick up from that pincode yet.')
    address = ', '.join(p for p in (place['address'], place['landmark'], place['area']) if p)
    coords = (place['latitude'], place['longitude'])
    pin_code = place['pin_code']
    notes = str(body.get('notes') or '').strip()[:1000] or None

    with transaction.atomic():
        # Lock the slot row so two customers cannot both take its last place.
        slot = TimeSlot.objects.select_for_update().get(pk=slot.pk)
        if slot.capacity is not None and _slot_booked(slot, day) >= slot.capacity:
            return _bad('That pickup slot just filled up. Choose another.', status=409)
        now = timezone.now()
        order = Order(
            shop=shop, customer=customer, customer_name=customer.name,
            customer_phone=customer.phone, status=OrderStatus.PLACED,
            payment_status=PaymentStatus.UNPAID, delivery_type=DeliveryType.HOME_PICKUP,
            source=OrderSource.MOBILE_APP, created_by=customer.email or customer.name,
            pickup_date=day, pickup_time=slot.start_time, address=address,
            pin_code=pin_code, latitude=coords[0], longitude=coords[1],
            notes=notes, idempotency_key=key, placed_at=now)
        try:
            with transaction.atomic():
                order.save()
        except IntegrityError:
            # Same key raced in from a parallel request: hand back the winner.
            existing = Order.objects.filter(shop=shop, idempotency_key=key, customer=customer).first()
            if existing:
                return JsonResponse(_order_json(existing), status=200)
            raise
        order.audit_log.create(status=OrderStatus.PLACED, title=OrderStatus.PLACED.label,
                               detail='Booked by the customer online', created_at=now, shop=shop)
        subtotal = 0.0
        for item_id, qty in wanted:
            item = catalogue[item_id]
            total = round(item.price * qty, 2)
            subtotal += total
            OrderItem.objects.create(
                order=order, shop=shop, item=item, item_title=item.name,
                service_type=item.category.name, quantity=qty, unit=item.unit,
                unit_price=item.price, total_price=total)
        order.subtotal = order.total_amount = order.due_amount = round(subtotal, 2)
        order.save(update_fields=['subtotal', 'total_amount', 'due_amount'])
        # After commit, so a rolled-back booking never emails the shop.
        transaction.on_commit(lambda pk=order.pk: _alert_shop(pk))
    order = Order.objects.prefetch_related('items').get(pk=order.pk)
    return JsonResponse(_order_json(order), status=201)


# csrf_exempt: Bearer-token auth, as for customer_me.
@csrf_exempt
@require_http_methods(['GET', 'POST'])
def customer_orders(request):
    customer, err = _customer_for(request)
    if err:
        return err
    if request.method == 'POST':
        return _create_customer_order(request, customer)
    orders = customer.orders.prefetch_related('items').order_by('-created_at')
    params = request.GET

    # ?state=current|past: the Orders page's two tabs. Current is anything still
    # moving; past is delivered or cancelled.
    state = params.get('state')
    if state:
        closed = [OrderStatus.DELIVERED, OrderStatus.CANCELLED]
        if state == 'current':
            orders = orders.exclude(status__in=closed)
        elif state == 'past':
            orders = orders.filter(status__in=closed)
        else:
            return _bad('state must be current or past.')

    # ?calendar=YYYY-MM: orders booked on each day of that month (the history
    # calendar's dots), in the shop's time zone.
    if params.get('calendar'):
        try:
            year, month = (int(x) for x in str(params['calendar']).split('-'))
            first = date(year, month, 1)
        except (TypeError, ValueError):
            return _bad('calendar must be YYYY-MM.')
        nxt = date(year + month // 12, month % 12 + 1, 1)
        counts = orders.filter(created_at__date__gte=first, created_at__date__lt=nxt)             .order_by().annotate(day=TruncDate('created_at')).values('day').annotate(n=Count('id'))
        return JsonResponse({'month': first.strftime('%Y-%m'),
                             'days': {str(r['day']): r['n'] for r in counts}})

    # ?date=YYYY-MM-DD: only orders booked that day.
    if params.get('date'):
        try:
            day = date.fromisoformat(str(params['date']))
        except ValueError:
            return _bad('date must be YYYY-MM-DD.')
        orders = orders.filter(created_at__date=day)

    # ?page=N[&page_size=M]: one page plus totals; without it, everything (as before).
    if params.get('page'):
        try:
            page = max(1, int(params['page']))
            size = min(50, max(1, int(params.get('page_size') or 10)))
        except ValueError:
            return _bad('page and page_size must be numbers.')
        total = orders.count()
        pages = max(1, -(-total // size))
        page = min(page, pages)
        rows = orders[(page - 1) * size:page * size]
        return JsonResponse({'orders': [_order_json(o) for o in rows], 'page': page,
                             'pages': pages, 'total': total})
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


def _alert_issue(issue_pk):
    """Email the shop a problem reported on an order. Best effort, like _alert_shop."""
    import logging
    from .services.email_service import EmailService
    issue = OrderIssue.all_objects.select_related('shop', 'order', 'customer').filter(pk=issue_pk).first()
    if issue is None or not issue.shop or not issue.shop.email:
        return
    c = issue.customer
    text = (f'{c.name} ({c.phone}{", " + c.email if c.email else ""}) reported a problem with '
            f'order {issue.order.order_number}.\n\n{issue.get_category_display()}:\n{issue.message}\n\n'
            'Reply to the customer directly. Mark it resolved in admin when done.')
    ok, error = EmailService.send(issue.shop.email,
                                  f'Problem reported on {issue.order.order_number}', text)
    if not ok:
        logging.getLogger(__name__).warning('Issue alert for %s not sent: %s',
                                            issue.order.order_number, error)


# csrf_exempt: Bearer-token auth, as for customer_me.
@csrf_exempt
@require_http_methods(['POST'])
def customer_order_issues(request, order_number):
    """POST /api/customer/orders/<no>/issues/ {category, message}: report a problem
    with one of the caller's own orders (Help → Report an issue)."""
    from .password_auth import _throttled
    customer, err = _customer_for(request)
    if err:
        return err
    order = customer.orders.filter(order_number=order_number).first()
    if order is None:
        return JsonResponse({'detail': 'Order not found.'}, status=404)
    body, err = _read_json(request)
    if err:
        return err
    category = str(body.get('category') or '').upper()
    message = str(body.get('message') or '').strip()
    if category not in dict(OrderIssue.CATEGORY_CHOICES):
        return _bad('Pick what went wrong.')
    if not message:
        return _bad('Tell the laundry what happened.')
    if len(message) > 500:
        return _bad('Keep it under 500 characters.')
    if _throttled(f'order-issue:{customer.id}', limit=5, window=3600):
        return _bad('Too many reports. Please try again later.', status=429)
    issue = OrderIssue.objects.create(order=order, customer=customer, category=category,
                                      message=message, shop=order.shop)
    transaction.on_commit(lambda pk=issue.pk: _alert_issue(pk))
    return JsonResponse({'id': issue.id, 'category': issue.category, 'status': issue.status,
                         'created_at': _iso(issue.created_at)}, status=201)


def _public_shop_json(shop):
    return {'id': shop.id, 'slug': shop.slug, 'name': shop.name, 'address': shop.address,
            'city': shop.city, 'pin_code': shop.pin_code, 'phone': shop.phone,
            'whatsapp': shop.whatsapp, 'email': shop.email,
            'currency_symbol': shop.currency_symbol,
            'accepts_online_customers': shop.accepts_online_customers}


def _online_shops():
    """Shops a customer can find and join: opted in, active, not a demo sandbox."""
    return Shop.objects.filter(accepts_online_customers=True, status='ACTIVE') \
        .exclude(slug__startswith='demo-')


@require_GET
def customer_shop_search(request):
    """GET /api/customer/shops/?q= - public "Find your laundry": by name, city or pincode."""
    from .password_auth import _client_ip, _throttled
    if _throttled(f'shop-search:{_client_ip(request)}', limit=120, window=3600):
        return _bad('Too many searches. Please try again later.', status=429)
    q = str(request.GET.get('q') or '').strip()[:60]
    shops = _online_shops()
    if q:
        shops = shops.filter(Q(name__icontains=q) | Q(city__icontains=q) | Q(pin_code__startswith=q)
                             | Q(service_areas__pin_code=q, service_areas__is_active=True)).distinct()
    here = _point(request.GET.get('lat'), request.GET.get('lng'))
    if here is None:
        return JsonResponse({'shops': [_public_shop_json(s) for s in shops.order_by('name')[:20]]})
    # With the customer's location: nearest first, each with its distance; shops
    # that have not set a map location go last, by name.
    rows = []
    for s in shops.order_by('name')[:200]:
        row = _public_shop_json(s)
        if s.latitude is not None and s.longitude is not None:
            row['distance_km'] = round(_km(here, (s.latitude, s.longitude)), 1)
        rows.append(row)
    rows.sort(key=lambda r: (r.get('distance_km') is None, r.get('distance_km') or 0))
    return JsonResponse({'shops': rows[:20]})


def _point(lat, lng):
    """(lat, lng) from query strings, or None when missing or out of range."""
    try:
        lat, lng = float(lat), float(lng)
    except (TypeError, ValueError):
        return None
    return (lat, lng) if -90 <= lat <= 90 and -180 <= lng <= 180 else None


def _km(a, b):
    """Great-circle distance in km (haversine): plenty for "which laundry is near"."""
    from math import asin, cos, radians, sin, sqrt
    lat1, lng1, lat2, lng2 = map(radians, (*a, *b))
    h = sin((lat2 - lat1) / 2) ** 2 + cos(lat1) * cos(lat2) * sin((lng2 - lng1) / 2) ** 2
    return 2 * 6371 * asin(sqrt(h))


@require_GET
def customer_shop_detail(request, slug):
    """GET /api/customer/shops/<slug>/ - the shop behind a /s/<slug> booking link."""
    shop = _online_shops().filter(slug__iexact=slug).first()
    if shop is None:
        return _bad('This laundry is not taking online bookings.', status=404)
    # The laundry page also lists what it cleans and where it picks up. all_objects:
    # the caller's X-Tenant-ID may be another laundry they already booked with.
    services = [c.name for c in GarmentCategory.all_objects.filter(shop=shop, is_active=True)
                .order_by('display_order', 'id')
                if GarmentItem.all_objects.filter(category=c, is_active=True).exists()]
    pincodes = sorted({a.pin_code.strip() for a in ServiceArea.all_objects.filter(shop=shop, is_active=True)
                       if a.pin_code.strip()})
    return JsonResponse({**_public_shop_json(shop), 'services': services, 'pincodes': pincodes})


@csrf_exempt
@require_http_methods(['POST'])
def customer_join(request):
    """POST /api/customer/join/ {name, phone} with X-Tenant-ID: join that shop as a customer.

    New phone for the shop: a Customer + CUSTOMER membership are created (201). A
    phone the shop already has queues an EmailLinkRequest for the owner (202):
    without a phone OTP, linking directly would let anyone claim a stranger's orders.
    """
    from django.contrib.auth import get_user_model
    from .password_auth import _throttled
    from .tenancy import get_current_tenant

    from .demo import is_demo_email

    email = verified_email(request)
    if not email:
        return _bad('Sign in required.', status=401)
    if is_demo_email(email):  # a throwaway sandbox account never joins a real shop
        return _bad('Sign in with your own account to book.', status=403)
    shop = get_current_tenant()
    if shop is None or not _online_shops().filter(pk=shop.pk).exists():
        return _bad('This laundry is not taking online bookings.', status=404)
    if _throttled(f'customer-join:{email}', limit=10, window=3600):
        return _bad('Too many attempts. Please try again later.', status=429)
    body, err = _read_json(request)
    if err:
        return err
    # A customer of another laundry joins with the details they gave there:
    # the newest such record supplies whatever the body leaves out.
    previous = Customer.all_objects.filter(email__iexact=email).exclude(shop=shop) \
        .order_by('-created_at').first()
    name = str(body.get('name') or '').strip()[:255] or (previous.name if previous else '')
    phone = clean_phone(body.get('phone')) or (clean_phone(previous.phone) if previous else None)
    if not name or not phone:
        return _bad('Enter your name and a valid 10-digit mobile number.')

    User = get_user_model()
    user = User.objects.filter(username__iexact=email).first()
    if user is None:  # first Google sign-in: the token already proved the email
        user = User.objects.create_user(username=email, email=email, first_name=name[:150])
        user.set_unusable_password()
        user.save(update_fields=['password'])

    with transaction.atomic():
        existing = shop_customer(email, shop)
        if existing:
            _ensure_customer_membership(user, shop)
            return JsonResponse(_me_json(existing), status=200)
        by_phone = Customer.all_objects.filter(shop=shop, phone__endswith=phone).first()
        if by_phone:
            EmailLinkRequest.objects.get_or_create(
                shop=shop, customer=by_phone, email=email, status=EmailLinkRequest.PENDING)
            return JsonResponse({
                'pending': True,
                'detail': f'That number is already registered with {shop.name}. We have asked '
                          'them to confirm it is you; your orders appear once they approve.'},
                status=202)
        customer = Customer.objects.create(shop=shop, name=name, phone=phone, email=email)
        if previous:
            _copy_addresses(previous, customer)
        _ensure_customer_membership(user, shop)
    return JsonResponse(_me_json(customer), status=201)


def _copy_addresses(source, customer):
    """Give a customer joining another laundry the pickup addresses they saved before."""
    for a in CustomerAddress.all_objects.filter(customer=source).order_by('created_at'):
        CustomerAddress.all_objects.create(
            shop=customer.shop, customer=customer, label=a.label, address=a.address,
            landmark=a.landmark, area=a.area, pin_code=a.pin_code, latitude=a.latitude,
            longitude=a.longitude, is_default=a.is_default)


def _ensure_customer_membership(user, shop):
    """Give `user` an active CUSTOMER membership of `shop`, never downgrading an
    owner/staff membership they already have there."""
    m, created = ShopMembership.objects.get_or_create(
        user=user, shop=shop,
        defaults={'role': ShopRole.CUSTOMER, 'is_active': True,
                  'is_default': not ShopMembership.objects.filter(user=user).exists()})
    if not created and m.role == ShopRole.CUSTOMER and not m.is_active:
        m.is_active = True
        m.save(update_fields=['is_active'])
    return m


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
