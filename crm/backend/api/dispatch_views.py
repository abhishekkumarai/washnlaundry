"""Rider dispatch & live tracking.

Hub for the DeliveryBoy rider app (producer) and the customer's live map (consumer):

* ``POST /api/orders/<id>/dispatch/``          staff: create a rider task, get the DeliveryBoy payload
* ``POST /api/rider/location/``                rider: GPS ping
* ``POST /api/rider/webhook/complete/``        DeliveryBoy completion webhook (HMAC-signed)
* ``GET  /api/customer/orders/<number>/track/`` customer: latest rider position + OTP

Task payloads follow ``deliveryboy/docs/sample_live_task.json``.
"""
import base64
import hashlib
import hmac
import json
import secrets

from django.conf import settings
from django.db import transaction
from django.http import JsonResponse
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .auth import IsStaff, Principal, OWNER
from .customer_views import _customer_for, _iso
from .models import (
    DeliveryType, Order, OrderStatus, RiderLocation, RiderTask, RiderTaskKind,
    RiderTaskStatus, Staff,
)

WEBHOOK_SIGNATURE_HEADER = 'X-Signature'


def _valid_point(lat, lng):
    try:
        lat, lng = float(lat), float(lng)
    except (TypeError, ValueError):
        return None
    if not (-90 <= lat <= 90 and -180 <= lng <= 180):
        return None
    return lat, lng


def _webhook_secret():
    return getattr(settings, 'RIDER_WEBHOOK_SECRET', '') or settings.SECRET_KEY


def sign_webhook(body: bytes) -> str:
    return hmac.new(_webhook_secret().encode(), body, hashlib.sha256).hexdigest()


def task_payload(task, request=None):
    """The task in DeliveryBoy's external-task schema."""
    order, shop = task.order, task.order.shop
    rider = task.rider
    pickup_is_customer = task.kind == RiderTaskKind.PICKUP
    shop_name = getattr(shop, 'name', '') or 'Shop'
    shop_phone = getattr(shop, 'phone', '') or ''
    shop_address = getattr(shop, 'address', '') or ''

    def party(is_customer, lat, lng):
        if is_customer:
            return {'name': order.customer_name, 'phone': order.customer_phone,
                    'address': order.address, 'latitude': lat, 'longitude': lng}
        return {'name': shop_name, 'phone': shop_phone, 'address': shop_address,
                'latitude': lat, 'longitude': lng}

    webhook = f"/api/rider/webhook/complete/?shop={getattr(shop, 'slug', '') or shop.id}"
    if request is not None:
        webhook = request.build_absolute_uri(webhook)
    due = max(order.due_amount or 0, 0) if task.kind == RiderTaskKind.DELIVERY else 0
    return {
        'taskId': str(task.id),
        'externalOrderId': order.order_number,
        'clientApp': {
            'appId': 'com.washnlaundry.crm', 'appName': shop_name,
            'webhookUrl': webhook, 'returnUrl': '',
        },
        'deliveryPerson': {
            'id': str(rider.id) if rider else '', 'name': rider.name if rider else '',
            'phone': rider.phone if rider else '',
        },
        'pickup': party(pickup_is_customer, task.pickup_lat, task.pickup_lng),
        'destination': party(not pickup_is_customer, task.drop_lat, task.drop_lng),
        'packageDetails': {'packageId': str(order.id), 'trackingBarcode': order.order_number},
        'payment': {'mode': 'Cash on Delivery' if due else 'Prepaid', 'amountDue': due,
                    'currency': 'INR', 'isPrepaid': not due},
        'verificationRequirements': {'requireOtp': True, 'expectedOtp': task.otp,
                                     'requireBarcodeScan': False},
        'createdAt': _iso(task.created_at),
    }


def deep_link(payload):
    raw = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode()
    return f'deliveryboy://task?payload={raw}'


def _shop_point(shop):
    if shop is not None and shop.latitude is not None and shop.longitude is not None:
        return shop.latitude, shop.longitude
    return None


@api_view(['POST'])
@permission_classes([IsStaff])
def order_dispatch(request, order_id):
    """Create a rider task for a home-pickup / home-delivery order."""
    order = Order.objects.select_related('shop').filter(pk=order_id).first()
    if order is None:
        return Response({'detail': 'Order not found.'}, status=404)
    if order.delivery_type not in (DeliveryType.HOME_PICKUP, DeliveryType.HOME_DELIVERY):
        return Response({'detail': 'Only home pickup / home delivery orders can be dispatched.'}, status=400)
    if order.status in (OrderStatus.DELIVERED, OrderStatus.CANCELLED):
        return Response({'detail': f'Order is already {order.status.lower()}.'}, status=400)

    rider = Staff.objects.filter(pk=request.data.get('rider'), status='ACTIVE').first()
    if rider is None:
        return Response({'detail': 'rider must be an active staff member of this shop.'}, status=400)

    kind = (RiderTaskKind.PICKUP if order.delivery_type == DeliveryType.HOME_PICKUP
            else RiderTaskKind.DELIVERY)
    customer_pt = _valid_point(
        order.pickup_lat if kind == RiderTaskKind.PICKUP else order.drop_lat,
        order.pickup_lng if kind == RiderTaskKind.PICKUP else order.drop_lng)
    shop_pt = _shop_point(order.shop)
    if customer_pt is None:
        return Response({'detail': 'Order has no customer coordinates yet (geocode the address).'}, status=400)
    if shop_pt is None:
        return Response({'detail': 'Shop has no latitude/longitude set.'}, status=400)

    if order.rider_tasks.filter(kind=kind, status__in=[RiderTaskStatus.ASSIGNED, RiderTaskStatus.EN_ROUTE]).exists():
        return Response({'detail': f'A {kind.lower()} task is already active for this order.'}, status=409)

    start, end = (customer_pt, shop_pt) if kind == RiderTaskKind.PICKUP else (shop_pt, customer_pt)
    with transaction.atomic():
        task = RiderTask.objects.create(
            shop=order.shop, order=order, rider=rider, kind=kind,
            otp=f'{secrets.randbelow(10000):04d}',
            pickup_lat=start[0], pickup_lng=start[1], drop_lat=end[0], drop_lng=end[1])
        if order.assigned_agent_id != rider.id:
            order.assigned_agent = rider
            order.save(update_fields=['assigned_agent'])
    payload = task_payload(task, request)
    return Response({'task_id': str(task.id), 'status': task.status, 'payload': payload,
                     'deep_link': deep_link(payload)}, status=201)


@api_view(['POST'])
@permission_classes([IsStaff])
def rider_location(request):
    """GPS ping from the rider app. Moves the task to EN_ROUTE on the first ping."""
    point = _valid_point(request.data.get('lat', request.data.get('latitude')),
                         request.data.get('lng', request.data.get('longitude')))
    if point is None:
        return Response({'detail': 'lat/lng required and must be valid coordinates.'}, status=400)
    task = RiderTask.objects.select_related('rider').filter(pk=request.data.get('task_id')).first()
    if task is None:
        return Response({'detail': 'Task not found.'}, status=404)
    if not task.is_active:
        return Response({'detail': f'Task is {task.status.lower()}.'}, status=409)

    # Only the assigned rider (or an owner) may report for a task.
    principal = request.user
    if settings.API_AUTH_ENFORCED and isinstance(principal, Principal) and principal.role != OWNER:
        rider_email = (task.rider.email if task.rider else '').strip().lower()
        if not rider_email or rider_email != (principal.email or '').strip().lower():
            return Response({'detail': 'This task is assigned to another rider.'}, status=403)

    when = parse_datetime(str(request.data.get('ts') or '')) or timezone.now()
    if timezone.is_naive(when):
        when = timezone.make_aware(when)
    with transaction.atomic():
        ping = RiderLocation.objects.create(shop=task.shop, task=task, lat=point[0], lng=point[1], recorded_at=when)
        if task.status == RiderTaskStatus.ASSIGNED:
            task.status = RiderTaskStatus.EN_ROUTE
            task.save(update_fields=['status'])
            if task.kind == RiderTaskKind.DELIVERY and task.order.status != OrderStatus.OUT_FOR_DELIVERY:
                task.order.status = OrderStatus.OUT_FOR_DELIVERY
                task.order.out_for_delivery_at = timezone.now()
                task.order.save(update_fields=['status', 'out_for_delivery_at'])
        stale = list(task.locations.values_list('pk', flat=True)[RiderLocation.KEEP:])
        if stale:
            RiderLocation.objects.filter(pk__in=stale).delete()
    return Response({'ok': True, 'id': ping.pk, 'status': task.status}, status=201)


@csrf_exempt
@require_POST
def rider_complete_webhook(request):
    """DeliveryBoy's completion webhook. Body is DeliveryBoy's CompletionPayload JSON,
    signed with HMAC-SHA256 (hex) in the ``X-Signature`` header."""
    body = request.body
    given = request.headers.get(WEBHOOK_SIGNATURE_HEADER, '')
    if not hmac.compare_digest(given.encode(), sign_webhook(body).encode()):
        return JsonResponse({'detail': 'Bad signature.'}, status=401)
    try:
        data = json.loads(body)
    except ValueError:
        return JsonResponse({'detail': 'Invalid JSON.'}, status=400)

    task = RiderTask.objects.select_related('order').filter(pk=data.get('taskId')).first() \
        if _is_uuid(data.get('taskId')) else None
    if task is None:
        return JsonResponse({'detail': 'Task not found.'}, status=404)
    if task.status == RiderTaskStatus.COMPLETED:
        return JsonResponse({'ok': True, 'duplicate': True})
    if not task.is_active:
        return JsonResponse({'detail': f'Task is {task.status.lower()}.'}, status=409)
    if data.get('status', 'delivered') != 'delivered':
        return JsonResponse({'detail': 'Only delivered completions are accepted.'}, status=400)
    if not (data.get('verification') or {}).get('otpVerified'):
        return JsonResponse({'detail': 'OTP was not verified.'}, status=400)

    now = timezone.now()
    with transaction.atomic():
        task.status = RiderTaskStatus.COMPLETED
        task.completed_at = now
        task.pod = {k: data.get(k) for k in ('timeline', 'deliveryLocation', 'verification', 'proofOfDelivery')}
        task.save(update_fields=['status', 'completed_at', 'pod'])
        order = task.order
        if task.kind == RiderTaskKind.DELIVERY:
            order.status = OrderStatus.DELIVERED
            order.delivered_at = now
            order.save(update_fields=['status', 'delivered_at'])
    return JsonResponse({'ok': True})


def _is_uuid(value):
    import uuid
    try:
        uuid.UUID(str(value))
        return True
    except ValueError:
        return False


@require_GET
def customer_order_track(request, order_number):
    """The customer's live view: latest rider position for their own order."""
    customer, err = _customer_for(request)
    if err:
        return err
    order = customer.orders.filter(order_number=order_number).first()
    if order is None:
        return JsonResponse({'detail': 'Order not found.'}, status=404)
    task = RiderTask.all_objects.filter(order=order).exclude(status=RiderTaskStatus.CANCELLED) \
        .order_by('-created_at').first()
    if task is None:
        return JsonResponse({'tracking': False})
    data = {
        'tracking': True, 'kind': task.kind, 'status': task.status,
        'otp': task.otp if task.is_active else None,
        'pickup': {'lat': task.pickup_lat, 'lng': task.pickup_lng},
        'drop': {'lat': task.drop_lat, 'lng': task.drop_lng},
        'rider': {'name': task.rider.name, 'phone': task.rider.phone} if task.rider else None,
        'location': None,
    }
    if task.is_active:
        last = RiderLocation.all_objects.filter(task=task).first()
        if last:
            data['location'] = {'lat': last.lat, 'lng': last.lng, 'at': _iso(last.recorded_at)}
    return JsonResponse(data)
