from datetime import timedelta

from django.db.models import Sum, Count, Q
from django.utils import timezone
from rest_framework import viewsets
from rest_framework.decorators import api_view, action
from rest_framework.response import Response

from .models import (
    Shop, Customer, GarmentCategory, GarmentItem, Order, OrderItem,
    Expense, Staff, Attendance, ServiceArea, TimeSlot,
    OrderStatus, PaymentStatus, DeliveryType,
)
from .serializers import (
    ShopSerializer, CustomerSerializer, GarmentCategorySerializer,
    GarmentItemSerializer, OrderSerializer, OrderItemSerializer,
    ExpenseSerializer, StaffSerializer, AttendanceSerializer,
    ServiceAreaSerializer, TimeSlotSerializer,
)


class ShopViewSet(viewsets.ModelViewSet):
    queryset = Shop.objects.all()
    serializer_class = ShopSerializer


class CustomerViewSet(viewsets.ModelViewSet):
    queryset = Customer.objects.all().order_by('-created_at')
    serializer_class = CustomerSerializer

    def get_queryset(self):
        qs = super().get_queryset()
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(
                Q(name__icontains=search) | Q(phone__icontains=search) | Q(email__icontains=search)
            )
        return qs


class GarmentCategoryViewSet(viewsets.ModelViewSet):
    queryset = GarmentCategory.objects.all().order_by('display_order')
    serializer_class = GarmentCategorySerializer


class GarmentItemViewSet(viewsets.ModelViewSet):
    serializer_class = GarmentItemSerializer

    def get_queryset(self):
        qs = GarmentItem.objects.select_related('category').all()
        if self.request.query_params.get('include_inactive') != 'true':
            qs = qs.filter(is_active=True)
        category = self.request.query_params.get('category')
        if category:
            qs = qs.filter(category_id=category)
        return qs


class OrderViewSet(viewsets.ModelViewSet):
    serializer_class = OrderSerializer

    def get_queryset(self):
        qs = Order.objects.prefetch_related('items').all().order_by('-created_at')
        status_filter = (self.request.query_params.get('status') or '').upper()
        today = timezone.localdate()

        # Derived filters that don't map to a stored status value.
        if status_filter == 'OVERDUE':
            return qs.filter(scheduled_date__lt=today).exclude(
                status__in=[OrderStatus.DELIVERED, OrderStatus.CANCELLED]
            )
        if status_filter == 'SCHEDULED':
            return qs.filter(scheduled_date__gt=today).exclude(
                status__in=[OrderStatus.DELIVERED, OrderStatus.CANCELLED]
            )
        if status_filter == 'UNPAID':
            return qs.filter(payment_status=PaymentStatus.UNPAID)
        if status_filter == 'PARTIAL':
            return qs.filter(payment_status=PaymentStatus.PARTIAL)
        if status_filter and status_filter != 'ALL':
            qs = qs.filter(status=status_filter)

        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(
                Q(order_number__icontains=search)
                | Q(customer_name__icontains=search)
                | Q(customer_phone__icontains=search)
            )
        return qs

    @action(detail=True, methods=['post'])
    def status(self, request, pk=None):
        """POST /api/orders/<id>/status/ {"status": "READY"} — stamps the timeline."""
        order = self.get_object()
        new_status = (request.data.get('status') or '').upper()
        if new_status not in OrderStatus.values:
            return Response(
                {'detail': f'Invalid status. Expected one of {OrderStatus.values}.'}, status=400
            )
        order.mark_status(new_status)
        return Response(self.get_serializer(order).data)

    @action(detail=True, methods=['post'])
    def payment(self, request, pk=None):
        """POST /api/orders/<id>/payment/ {"amount": 250} — 'Collect Payment'."""
        order = self.get_object()
        try:
            amount = float(request.data.get('amount', 0))
        except (TypeError, ValueError):
            return Response({'detail': 'amount must be a number.'}, status=400)
        if amount <= 0:
            return Response({'detail': 'amount must be greater than zero.'}, status=400)

        order.paid_amount = min(order.paid_amount + amount, order.total_amount)
        order.due_amount = max(order.total_amount - order.paid_amount, 0.0)
        if order.due_amount <= 0:
            order.payment_status = PaymentStatus.PAID
        elif order.paid_amount > 0:
            order.payment_status = PaymentStatus.PARTIAL
        else:
            order.payment_status = PaymentStatus.UNPAID
        order.save()

        if order.customer:
            order.customer.due_amount = max(order.customer.due_amount - amount, 0.0)
            order.customer.save()

        return Response(self.get_serializer(order).data)


class ExpenseViewSet(viewsets.ModelViewSet):
    queryset = Expense.objects.all().order_by('-date')
    serializer_class = ExpenseSerializer


class StaffViewSet(viewsets.ModelViewSet):
    queryset = Staff.objects.all()
    serializer_class = StaffSerializer


class AttendanceViewSet(viewsets.ModelViewSet):
    serializer_class = AttendanceSerializer

    def get_queryset(self):
        qs = Attendance.objects.select_related('staff').all().order_by('-date')
        date = self.request.query_params.get('date')
        if date:
            qs = qs.filter(date=date)
        return qs


class ServiceAreaViewSet(viewsets.ModelViewSet):
    queryset = ServiceArea.objects.all()
    serializer_class = ServiceAreaSerializer


class TimeSlotViewSet(viewsets.ModelViewSet):
    serializer_class = TimeSlotSerializer

    def get_queryset(self):
        qs = TimeSlot.objects.all()
        kind = (self.request.query_params.get('kind') or '').upper()
        if kind in (TimeSlot.PICKUP, TimeSlot.DELIVERY):
            qs = qs.filter(kind=kind)
        return qs


@api_view(['GET'])
def dashboard_stats(request):
    today = timezone.localdate()
    yesterday = today - timedelta(days=1)
    month_start = today.replace(day=1)

    orders = Order.objects.all()
    active = orders.exclude(status__in=[OrderStatus.DELIVERED, OrderStatus.CANCELLED])

    orders_today = orders.filter(created_at__date=today)
    orders_yesterday = orders.filter(created_at__date=yesterday)

    revenue_today = orders_today.aggregate(s=Sum('paid_amount'))['s'] or 0.0
    revenue_yesterday = orders_yesterday.aggregate(s=Sum('paid_amount'))['s'] or 0.0

    sales_month = orders.filter(created_at__date__gte=month_start).aggregate(s=Sum('total_amount'))['s'] or 0.0
    collected_month = orders.filter(created_at__date__gte=month_start).aggregate(s=Sum('paid_amount'))['s'] or 0.0
    expenses_month = Expense.objects.filter(date__date__gte=month_start).aggregate(s=Sum('amount'))['s'] or 0.0

    def pct_change(now, before):
        if not before:
            return None if not now else 100.0
        return round(((now - before) / before) * 100, 1)

    # 14-day revenue series for the dashboard bar chart.
    revenue_series = []
    for offset in range(13, -1, -1):
        day = today - timedelta(days=offset)
        amount = orders.filter(created_at__date=day).aggregate(s=Sum('total_amount'))['s'] or 0.0
        revenue_series.append({'date': day.isoformat(), 'day': day.day, 'amount': amount})

    attendance_today = Attendance.objects.filter(date=today)

    # ── Store Health ──────────────────────────────────────────────────────────
    # Each metric is a percentage or None when there's nothing to measure yet;
    # the score is the mean of whichever metrics are available. Returning None
    # rather than 0 matters — the live UI renders an em dash for "no data",
    # which is very different from "0%".
    window_start = today - timedelta(days=30)
    recent = orders.filter(created_at__date__gte=window_start)

    delivered = recent.filter(status=OrderStatus.DELIVERED, scheduled_date__isnull=False)
    delivered_total = delivered.count()
    on_time_delivery = None
    if delivered_total:
        on_time = sum(
            1 for o in delivered
            if o.delivered_at and o.delivered_at.date() <= o.scheduled_date
        )
        on_time_delivery = round((on_time / delivered_total) * 100, 1)

    scheduled_active = active.filter(scheduled_date__isnull=False)
    scheduled_active_total = scheduled_active.count()
    on_schedule = scheduled_active.filter(scheduled_date__gte=today).count()
    order_flow = (
        round((on_schedule / scheduled_active_total) * 100, 1)
        if scheduled_active_total else None
    )

    collection_rate = round((collected_month / sales_month) * 100, 1) if sales_month else 0.0

    # Pickups aren't tracked as a separate milestone yet.
    on_time_pickup = None

    measured = [m for m in (on_time_delivery, order_flow, collection_rate) if m is not None]
    health_score = round(sum(measured) / len(measured)) if measured else 0

    if health_score >= 80:
        health_verdict = 'Healthy'
    elif health_score >= 60:
        health_verdict = 'Fair'
    else:
        health_verdict = 'Needs attention'

    return Response({
        'store_health': {
            'score': health_score,
            'verdict': health_verdict,
            'on_time_delivery': on_time_delivery,
            'on_time_pickup': on_time_pickup,
            'order_flow': order_flow,
            'collection_rate': collection_rate,
            'active_on_schedule': on_schedule,
        },
        'orders_today': orders_today.count(),
        'orders_today_change': pct_change(orders_today.count(), orders_yesterday.count()),
        'revenue_today': revenue_today,
        'revenue_today_change': pct_change(revenue_today, revenue_yesterday),
        'ready_for_pickup': orders.filter(status=OrderStatus.READY).count(),
        'overdue': active.filter(scheduled_date__lt=today).count(),
        'customers_total': Customer.objects.count(),
        'customers_new_today': Customer.objects.filter(created_at__date=today).count(),

        'pipeline': {
            'received': orders.filter(status=OrderStatus.PLACED).count(),
            'processing': orders.filter(status__in=[OrderStatus.PROCESSING, OrderStatus.IRONING]).count(),
            'ready': orders.filter(status=OrderStatus.READY).count(),
            'out_for_delivery': orders.filter(status=OrderStatus.OUT_FOR_DELIVERY).count(),
        },

        'revenue_series': revenue_series,

        'revenue_analytics': {
            'sales': sales_month,
            'collected': collected_month,
            'uncollected': sales_month - collected_month,
            'expenses': expenses_month,
            'net_profit': collected_month - expenses_month,
            'collection_progress': round((collected_month / sales_month) * 100, 1) if sales_month else 0.0,
        },

        'needs_attention': {
            'scheduled_ahead': active.filter(scheduled_date__gt=today).count(),
            'overdue_orders': active.filter(scheduled_date__lt=today).count(),
            'unpaid_invoices': orders.filter(
                payment_status__in=[PaymentStatus.UNPAID, PaymentStatus.PARTIAL]
            ).count(),
            'unpaid_outstanding': orders.aggregate(s=Sum('due_amount'))['s'] or 0.0,
            'online_orders': orders_today.filter(delivery_type=DeliveryType.ONLINE).count(),
        },

        'order_channels': {
            'store_pickup': orders_today.filter(delivery_type=DeliveryType.STORE_PICKUP).count(),
            'home_pickup': orders_today.filter(delivery_type=DeliveryType.HOME_PICKUP).count(),
            'home_delivery': orders_today.filter(delivery_type=DeliveryType.HOME_DELIVERY).count(),
            'online': orders_today.filter(delivery_type=DeliveryType.ONLINE).count(),
        },

        'staff_attendance': {
            'present': attendance_today.filter(status=Attendance.PRESENT).count(),
            'absent': attendance_today.filter(status=Attendance.ABSENT).count(),
            'leave': attendance_today.filter(status=Attendance.LEAVE).count(),
            'total_staff': Staff.objects.filter(status='ACTIVE').count(),
        },

        # Legacy keys kept so the current Flutter client keeps working.
        'total_orders': orders.count(),
        'total_revenue': orders.aggregate(s=Sum('paid_amount'))['s'] or 0.0,
        'total_dues': orders.aggregate(s=Sum('due_amount'))['s'] or 0.0,
        'total_expenses': Expense.objects.aggregate(s=Sum('amount'))['s'] or 0.0,
    })
