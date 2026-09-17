import json
from datetime import timedelta

from django.db.models import Sum, Count, Q
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import viewsets
from rest_framework.decorators import api_view, action
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response

from . import customer_import
from .models import (
    Shop, Customer, GarmentCategory, GarmentItem, Order, OrderItem,
    Expense, Staff, Attendance, SalaryPayment, SalaryAdvance, ServiceArea, TimeSlot,
    OrderStatus, PaymentStatus, DeliveryType, OrderSource, PricingUnit,
    PaymentMethod, ExpenseCategory,
)
from .serializers import (
    ShopSerializer, CustomerSerializer, GarmentCategorySerializer,
    GarmentItemSerializer, OrderSerializer, OrderItemSerializer,
    ExpenseSerializer, StaffSerializer, AttendanceSerializer,
    SalaryPaymentSerializer, SalaryAdvanceSerializer, ServiceAreaSerializer,
    TimeSlotSerializer,
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

    @action(detail=False, methods=['post'], parser_classes=[MultiPartParser],
            url_path='import/preview')
    def import_preview(self, request):
        """POST /api/customers/import/preview/ {file} — column names, a
        handful of sample rows, and a best-effort field-mapping guess, for
        the frontend's mapping-confirmation step.
        """
        upload = request.FILES.get('file')
        if not upload:
            return Response({'detail': 'file is required.'}, status=400)
        try:
            headers, rows = customer_import.parse_rows(upload)
        except customer_import.ImportFileError as exc:
            return Response({'detail': str(exc)}, status=400)
        if not headers:
            return Response({'detail': 'The file has no header row.'}, status=400)

        return Response({
            'columns': headers,
            'sample_rows': rows[:5],
            'row_count': len(rows),
            'suggested_mapping': customer_import.guess_mapping(headers),
        })

    @action(detail=False, methods=['post'], parser_classes=[MultiPartParser],
            url_path='import/commit')
    def import_commit(self, request):
        """POST /api/customers/import/commit/ {file, mapping} — bulk-creates
        customers from the file using a confirmed column mapping.

        `mapping` is a JSON object {"name": "<source column>", ...}, from
        the preview step's suggestion (edited or not). Rows missing a name
        or phone are always dropped. A row whose phone is already in use —
        by another row in this same file, or by an existing customer — is
        also dropped *unless* `overwrite_duplicates` ("true"/"false" form
        field, default false) is set, in which case that customer's other
        fields are updated in place instead (never the phone itself, which
        is what matched it) — a blank cell in the file leaves the existing
        value alone rather than wiping it. Either way the response
        summarises what happened, never fails the whole import over it.
        """
        upload = request.FILES.get('file')
        if not upload:
            return Response({'detail': 'file is required.'}, status=400)

        try:
            mapping = json.loads(request.data.get('mapping') or '{}')
        except (TypeError, ValueError):
            return Response({'detail': 'mapping must be valid JSON.'}, status=400)
        if not isinstance(mapping, dict) or not mapping.get('name') or not mapping.get('phone'):
            return Response(
                {'detail': 'Map both a name column and a phone column before importing.'},
                status=400,
            )
        overwrite_duplicates = (request.data.get('overwrite_duplicates') or '').lower() == 'true'

        try:
            headers, rows = customer_import.parse_rows(upload)
        except customer_import.ImportFileError as exc:
            return Response({'detail': str(exc)}, status=400)

        records = customer_import.rows_to_records(headers, rows, mapping)

        existing_by_phone = {c.phone: c for c in Customer.objects.all()}
        to_create = {}  # phone -> unsaved Customer
        to_update = {}  # phone -> existing Customer, fields already applied in memory
        skipped_missing = 0
        skipped_duplicate = 0

        for record in records:
            name = (record.get('name') or '').strip()
            phone = customer_import.normalize_phone(record.get('phone'))
            if not name or not phone:
                skipped_missing += 1
                continue

            fields = {
                'name': name,
                'email': (record.get('email') or '').strip() or None,
                'address': (record.get('address') or '').strip() or None,
                'area': (record.get('area') or '').strip(),
                'notes': (record.get('notes') or '').strip() or None,
            }

            target = to_create.get(phone) or to_update.get(phone) or existing_by_phone.get(phone)
            if target is not None:
                if not overwrite_duplicates:
                    skipped_duplicate += 1
                    continue
                for field, value in fields.items():
                    if value not in (None, ''):
                        setattr(target, field, value)
                if phone in existing_by_phone and phone not in to_update:
                    to_update[phone] = target
                continue

            to_create[phone] = Customer(phone=phone, **fields)

        Customer.objects.bulk_create(to_create.values())
        if to_update:
            Customer.objects.bulk_update(
                to_update.values(), ['name', 'email', 'address', 'area', 'notes'],
            )

        return Response({
            'total_rows': len(records),
            'created': len(to_create),
            'updated': len(to_update),
            'skipped_missing': skipped_missing,
            'skipped_duplicate': skipped_duplicate,
        })


class GarmentCategoryViewSet(viewsets.ModelViewSet):
    queryset = GarmentCategory.objects.all().order_by('display_order')
    serializer_class = GarmentCategorySerializer


class GarmentItemViewSet(viewsets.ModelViewSet):
    serializer_class = GarmentItemSerializer

    def get_queryset(self):
        qs = GarmentItem.objects.select_related('category').all()
        # is_active is a *list* default-hide, not an access restriction —
        # applying it unconditionally also gated retrieve/update/destroy,
        # so PATCHing is_active to False made the item unreachable by its
        # own id afterward: no way to GET it, edit it, or turn it back on
        # again through the API.
        if self.action == 'list' and self.request.query_params.get('include_inactive') != 'true':
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

    # Fields the "Edit Order" dialog can PATCH, and the label their audit
    # entry uses. Financial fields go through `status`/`payment` instead,
    # which log their own, more specific entries.
    _TRACKED_UPDATE_FIELDS = {
        'customer_name': 'Customer name',
        'customer_phone': 'Phone',
        'delivery_type': 'Delivery type',
        'scheduled_date': 'Scheduled date',
        'notes': 'Notes',
    }

    def perform_update(self, serializer):
        before = self.get_object()
        old_values = {f: getattr(before, f) for f in self._TRACKED_UPDATE_FIELDS}
        instance = serializer.save()
        changes = [
            f'{label}: {old_values[field] or "—"} → {getattr(instance, field) or "—"}'
            for field, label in self._TRACKED_UPDATE_FIELDS.items()
            if old_values[field] != getattr(instance, field)
        ]
        if changes:
            instance.audit_log.create(title='Order Updated', detail='; '.join(changes))

    @action(detail=True, methods=['post'])
    def status(self, request, pk=None):
        """POST /api/orders/<id>/status/ {"status": "READY", "note": "..."}

        Stamps the timeline. `note` is the optional free-text the live Update
        Status dialog collects; it is appended to the order's notes with the
        stage it belongs to, so the reason for a change survives, and it also
        rides along on the audit entry `mark_status` logs.
        """
        order = self.get_object()
        new_status = (request.data.get('status') or '').upper()
        if new_status not in OrderStatus.values:
            return Response(
                {'detail': f'Invalid status. Expected one of {OrderStatus.values}.'}, status=400
            )

        note = (request.data.get('note') or '').strip()
        if note:
            label = OrderStatus(new_status).label
            entry = f'[{label}] {note}'
            order.notes = f'{order.notes}\n{entry}' if order.notes else entry

        order.mark_status(new_status, note=note)
        return Response(self.get_serializer(order).data)

    @action(detail=True, methods=['post'])
    def payment(self, request, pk=None):
        """POST /api/orders/<id>/payment/ {"amount": 250, "payment_method": "UPI"}
        — 'Collect Payment'.
        """
        order = self.get_object()
        try:
            amount = float(request.data.get('amount', 0))
        except (TypeError, ValueError):
            return Response({'detail': 'amount must be a number.'}, status=400)
        if amount <= 0:
            return Response({'detail': 'amount must be greater than zero.'}, status=400)

        method = (request.data.get('payment_method') or '').upper()
        if method and method not in PaymentMethod.values:
            return Response(
                {'detail': f'Invalid payment_method. Expected one of {PaymentMethod.values}.'},
                status=400,
            )

        order.paid_amount = min(order.paid_amount + amount, order.total_amount)
        order.due_amount = max(order.total_amount - order.paid_amount, 0.0)
        if method:
            order.payment_method = method
        if order.due_amount <= 0:
            order.payment_status = PaymentStatus.PAID
        elif order.paid_amount > 0:
            order.payment_status = PaymentStatus.PARTIAL
        else:
            order.payment_status = PaymentStatus.UNPAID
        order.save()
        order.audit_log.create(
            title='Payment Collected',
            detail=(
                f'₹{amount:.0f} via {order.get_payment_method_display()} — '
                f'now {order.get_payment_status_display()}'
            ),
        )

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

    @action(detail=False, methods=['post'])
    def bulk(self, request):
        """POST /api/attendance/bulk/ — save a whole day's register at once.

            {"date": "2026-08-11",
             "entries": [{"staff": 3, "status": "PRESENT"}, ...]}

        Upserts rather than creates: `unique_together = ('staff', 'date')` means
        a plain re-POST of an already-marked day would 400, and the Attendance
        screen's Save Register is expected to be pressable twice.
        """
        date = parse_date(str(request.data.get('date') or ''))
        if date is None:
            return Response(
                {'detail': 'date is required, as YYYY-MM-DD.'}, status=400
            )

        entries = request.data.get('entries')
        if not isinstance(entries, list):
            return Response({'detail': 'entries must be a list.'}, status=400)

        valid_statuses = {choice[0] for choice in Attendance.STATUS_CHOICES}
        cleaned = []
        for entry in entries:
            if not isinstance(entry, dict):
                return Response({'detail': 'Each entry must be an object.'}, status=400)
            status_value = str(entry.get('status') or '').upper()
            if status_value not in valid_statuses:
                return Response(
                    {'detail': f'Invalid status. Expected one of {sorted(valid_statuses)}.'},
                    status=400,
                )
            try:
                staff_id = int(entry.get('staff'))
            except (TypeError, ValueError):
                return Response({'detail': 'Each entry needs a staff id.'}, status=400)
            cleaned.append((staff_id, status_value))

        staff_by_id = {
            s.id: s for s in Staff.objects.filter(id__in=[s for s, _ in cleaned])
        }
        missing = sorted({s for s, _ in cleaned} - set(staff_by_id))
        if missing:
            return Response({'detail': f'Unknown staff: {missing}.'}, status=400)

        not_yet_started = sorted({
            staff_by_id[staff_id].name
            for staff_id, _ in cleaned
            if staff_by_id[staff_id].start_date and date < staff_by_id[staff_id].start_date
        })
        if not_yet_started:
            return Response(
                {'detail': f"Cannot mark attendance before start date for: "
                           f"{', '.join(not_yet_started)}."},
                status=400,
            )

        # Validate everything before writing anything — a half-saved register is
        # worse than a rejected one, because nothing on screen says which half.
        for staff_id, status_value in cleaned:
            Attendance.objects.update_or_create(
                staff_id=staff_id, date=date, defaults={'status': status_value}
            )

        saved = Attendance.objects.select_related('staff').filter(date=date)
        return Response(AttendanceSerializer(saved, many=True).data)


class SalaryPaymentViewSet(viewsets.ModelViewSet):
    serializer_class = SalaryPaymentSerializer

    def get_queryset(self):
        qs = SalaryPayment.objects.select_related('staff').all()
        month = parse_month(self.request.query_params.get('month'))
        if month:
            qs = qs.filter(month=month)
        staff = self.request.query_params.get('staff')
        if staff:
            qs = qs.filter(staff_id=staff)
        return qs


class SalaryAdvanceViewSet(viewsets.ModelViewSet):
    """An advance against a month's wages — see `SalaryAdvance` for how this
    differs from a `SalaryPayment`."""
    serializer_class = SalaryAdvanceSerializer

    def get_queryset(self):
        qs = SalaryAdvance.objects.select_related('staff').all()
        month = parse_month(self.request.query_params.get('month'))
        if month:
            qs = qs.filter(month=month)
        staff = self.request.query_params.get('staff')
        if staff:
            qs = qs.filter(staff_id=staff)
        return qs


def parse_month(raw):
    """'2026-08' or '2026-08-11' -> date(2026, 8, 1). None if unparseable."""
    if not raw:
        return None
    text = str(raw).strip()
    parsed = parse_date(text if len(text) > 7 else f'{text}-01')
    return parsed.replace(day=1) if parsed else None


@api_view(['GET'])
def payroll_summary(request):
    """GET /api/payroll/?month=YYYY-MM — the Payroll screen, in one call.

    Wages earned are derived from Attendance (`Attendance.DAY_VALUE` decides
    what each state is worth) times a per-day rate — `Staff.monthly_wage`
    divided by however many days the month being paid actually has, so a day
    is worth slightly more in February than in a 31-day month for the same
    monthly wage. Advances (`SalaryAdvance`) come off that to give net pay —
    matching the real app's "the advance is deducted from this month's net
    pay". What was actually paid comes from SalaryPayment. None of these
    numbers are stored on Staff, so nothing here can drift out of step with
    the register.

    The roster is every staff member who is currently ACTIVE *or* has
    attendance/advance/payment activity in the requested month — an
    INACTIVE staff member with a wage still owed for a month they actually
    worked must stay reachable here, not vanish the moment they're marked
    inactive.
    """
    month = parse_month(request.query_params.get('month')) or timezone.localdate().replace(day=1)
    # First day of the following month, without needing calendar arithmetic.
    next_month = (month + timedelta(days=32)).replace(day=1)
    days_in_month = (next_month - month).days

    month_attendance = Attendance.objects.filter(date__gte=month, date__lt=next_month)

    days = {}
    present = {}
    half = {}
    leave = {}
    for record in month_attendance:
        days[record.staff_id] = days.get(record.staff_id, 0.0) + record.day_value
        if record.status == Attendance.PRESENT:
            present[record.staff_id] = present.get(record.staff_id, 0) + 1
        elif record.status == Attendance.HALF_DAY:
            half[record.staff_id] = half.get(record.staff_id, 0) + 1
        elif record.status == Attendance.LEAVE:
            leave[record.staff_id] = leave.get(record.staff_id, 0) + 1

    paid = {
        row['staff_id']: row['total']
        for row in SalaryPayment.objects.filter(month=month)
        .values('staff_id')
        .annotate(total=Sum('amount'))
    }
    advanced = {
        row['staff_id']: row['total']
        for row in SalaryAdvance.objects.filter(month=month)
        .values('staff_id')
        .annotate(total=Sum('amount'))
    }

    active_ids = set(Staff.objects.filter(status='ACTIVE').values_list('id', flat=True))
    active_with_activity_ids = (
        set(days) | set(paid) | set(advanced) | active_ids
    )
    roster = Staff.objects.filter(id__in=active_with_activity_ids).order_by('name')

    entries = []
    for member in roster:
        days_worked = round(days.get(member.id, 0.0), 1)
        daily_rate = member.monthly_wage / days_in_month
        total_salary = round(days_worked * daily_rate, 2)
        advances_amount = round(advanced.get(member.id, 0.0), 2)
        net_pay = round(max(total_salary - advances_amount, 0.0), 2)
        paid_amount = round(paid.get(member.id, 0.0), 2)
        pending = round(max(net_pay - paid_amount, 0.0), 2)

        # Same three-way rule the order payment action uses, so PAID/PARTIAL/
        # UNPAID mean the same thing everywhere in the app.
        if net_pay <= 0:
            status_value = PaymentStatus.UNPAID
        elif pending <= 0:
            status_value = PaymentStatus.PAID
        elif paid_amount > 0:
            status_value = PaymentStatus.PARTIAL
        else:
            status_value = PaymentStatus.UNPAID

        entries.append({
            'staff': member.id,
            'staff_name': member.name,
            'role': member.role,
            'monthly_wage': member.monthly_wage,
            'days_worked': days_worked,
            'present_days': present.get(member.id, 0),
            'half_days': half.get(member.id, 0),
            'leave_days': leave.get(member.id, 0),
            'total_salary': total_salary,
            'advances_amount': advances_amount,
            'net_pay': net_pay,
            'paid_amount': paid_amount,
            'pending_amount': pending,
            'status': status_value,
        })

    return Response({
        'month': month.isoformat(),
        'entries': entries,
        'totals': {
            'total_payroll': round(sum(e['net_pay'] for e in entries), 2),
            'paid': round(sum(e['paid_amount'] for e in entries), 2),
            'pending': round(sum(e['pending_amount'] for e in entries), 2),
            'staff_count': len(entries),
        },
    })


@api_view(['GET'])
def reports(request):
    """GET /api/reports/?from=YYYY-MM-DD&to=YYYY-MM-DD — the Reports screen.

    Defaults to the current month. Every figure the screen shows comes from
    here; it used to hardcode all of them, down to an eight-month bar chart
    whose heights were typed in by hand.

    Follows the same rule as `dashboard_stats`: a metric with nothing to
    measure is None, not 0, because the two mean very different things and the
    UI renders them differently.
    """
    today = timezone.localdate()
    start = parse_date(request.query_params.get('from') or '') or today.replace(day=1)
    end = parse_date(request.query_params.get('to') or '') or today
    if end < start:
        start, end = end, start

    orders = Order.objects.filter(created_at__date__gte=start, created_at__date__lte=end)
    expenses_qs = Expense.objects.filter(date__date__gte=start, date__date__lte=end)

    revenue = orders.aggregate(s=Sum('total_amount'))['s'] or 0.0
    collected = orders.aggregate(s=Sum('paid_amount'))['s'] or 0.0
    expenses = expenses_qs.aggregate(s=Sum('amount'))['s'] or 0.0
    order_count = orders.count()

    # The immediately preceding window of equal length — which is what
    # "▲ 12% vs last month" on the cards has always claimed to be.
    span = (end - start).days + 1
    prev_end = start - timedelta(days=1)
    prev_start = prev_end - timedelta(days=span - 1)
    prev_orders = Order.objects.filter(
        created_at__date__gte=prev_start, created_at__date__lte=prev_end
    )
    prev_revenue = prev_orders.aggregate(s=Sum('total_amount'))['s'] or 0.0
    prev_collected = prev_orders.aggregate(s=Sum('paid_amount'))['s'] or 0.0
    prev_expenses = Expense.objects.filter(
        date__date__gte=prev_start, date__date__lte=prev_end
    ).aggregate(s=Sum('amount'))['s'] or 0.0

    def pct_change(now, before):
        if not before:
            return None if not now else 100.0
        return round(((now - before) / before) * 100, 1)

    net_profit = collected - expenses
    prev_net = prev_collected - prev_expenses

    # ── Revenue vs expenses, last 8 months ────────────────────────────────────
    # Anchored on the range's end month so a custom range shows the months it
    # actually covers rather than always the last eight from today.
    monthly_series = []
    anchor = end.replace(day=1)
    for offset in range(7, -1, -1):
        month_start = anchor
        for _ in range(offset):
            month_start = (month_start - timedelta(days=1)).replace(day=1)
        month_end = (month_start + timedelta(days=32)).replace(day=1)
        monthly_series.append({
            'month': month_start.isoformat(),
            'label': month_start.strftime('%b'),
            'revenue': Order.objects.filter(
                created_at__date__gte=month_start, created_at__date__lt=month_end
            ).aggregate(s=Sum('total_amount'))['s'] or 0.0,
            'expenses': Expense.objects.filter(
                date__date__gte=month_start, date__date__lt=month_end
            ).aggregate(s=Sum('amount'))['s'] or 0.0,
        })

    def breakdown(field, choices):
        counts = {
            row[field]: row['n']
            for row in orders.values(field).annotate(n=Count('id'))
        }
        # Driven by the canonical choices, so a status the model no longer has
        # (the screen used to list "Washing") cannot appear, and one it does
        # have (Ironing) cannot be forgotten.
        return [
            {'key': value, 'label': label, 'count': counts.get(value, 0)}
            for value, label in choices
            if counts.get(value, 0)
        ]

    by_service = [
        {'label': row['service_type'], 'count': row['n']}
        for row in OrderItem.objects.filter(order__in=orders)
        .values('service_type')
        .annotate(n=Count('id'))
        .order_by('-n')
    ]

    mix_rows = [
        row for row in orders.values('payment_method').annotate(s=Sum('paid_amount'))
        if (row['s'] or 0) > 0
    ]
    mix_total = sum(row['s'] for row in mix_rows)
    payment_mix = sorted(
        (
            {
                'method': row['payment_method'],
                'amount': round(row['s'], 2),
                'percent': round((row['s'] / mix_total) * 100, 1) if mix_total else 0.0,
            }
            for row in mix_rows
        ),
        key=lambda row: row['amount'],
        reverse=True,
    )

    return Response({
        'from': start.isoformat(),
        'to': end.isoformat(),
        'revenue': revenue,
        'revenue_change': pct_change(revenue, prev_revenue),
        'collected': collected,
        # Share of what was billed that actually came in. None when nothing was
        # billed — "0% collected" would be a lie about an idle period.
        'collected_percent': round((collected / revenue) * 100, 1) if revenue else None,
        'outstanding': round(revenue - collected, 2),
        'expenses': expenses,
        'expenses_change': pct_change(expenses, prev_expenses),
        'net_profit': round(net_profit, 2),
        'net_profit_change': pct_change(net_profit, prev_net),
        'margin': round((net_profit / collected) * 100, 1) if collected else None,
        'order_count': order_count,
        'average_order_value': round(revenue / order_count, 2) if order_count else 0.0,
        'monthly_series': monthly_series,
        'by_status': breakdown('status', OrderStatus.choices),
        'by_type': breakdown('delivery_type', DeliveryType.choices),
        'by_service': by_service,
        'payment_mix': payment_mix,
    })


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


def _choices(enum):
    return [{'value': value, 'label': label} for value, label in enum.choices]


@api_view(['GET'])
def meta(request):
    """The canonical vocabularies, so the client stops hardcoding them.

    Every one of these existed only as a hand-maintained Dart literal that
    could drift from the model — most visibly the payment methods, which the
    Flutter app carried in three different lists with three different
    orderings. Serving them means a value added here shows up everywhere, and
    a value removed cannot linger in a dropdown.
    """
    return Response({
        'order_statuses': _choices(OrderStatus),
        'payment_statuses': _choices(PaymentStatus),
        'delivery_types': _choices(DeliveryType),
        'order_sources': _choices(OrderSource),
        'pricing_units': _choices(PricingUnit),
        'payment_methods': _choices(PaymentMethod),
        'expense_categories': _choices(ExpenseCategory),
        'attendance_statuses': [
            {'value': value, 'label': label}
            for value, label in Attendance.STATUS_CHOICES
        ],
    })


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
    #
    # Sums paid_amount, not total_amount: `revenue_today` above is collected
    # money, and the chart sits directly beside it. Billing the series and
    # collecting the card meant the last bar could never equal the "Revenue
    # today" figure, with nothing on screen explaining why. The whole
    # dashboard now speaks one language — collected.
    revenue_series = []
    for offset in range(13, -1, -1):
        day = today - timedelta(days=offset)
        amount = orders.filter(created_at__date=day).aggregate(s=Sum('paid_amount'))['s'] or 0.0
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
