"""Per-shop import for the sections that Backup & Data Export can export.

Round-trips the files written by `backup_export_service` (CSV with the export
headers, or the JSON record list / full-backup JSON). Customers and Services
keep their own column-mapping import flows; this covers the rest: staff,
orders, attendance, payroll, expenses and credits.

Every import is scoped to one shop (`require_shop()`), skips rows that already
exist instead of duplicating them, and reports per-row problems rather than
failing the whole file.
"""

import csv
import io
import json
from datetime import datetime

from django.db import transaction
from django.utils import timezone

from .models import (
    Attendance, Credit, CreditCategory, Customer, DeliveryType, Expense,
    ExpenseCategory, Order, OrderSource, OrderStatus, PaymentMethod,
    PaymentStatus, SalaryAdvance, SalaryPayment, Staff,
)
from .tenancy import require_shop

IMPORTABLE_SECTIONS = ('staff', 'orders', 'attendance', 'payroll', 'expenses', 'credits')
MAX_ROWS = 20000


class ImportFileError(ValueError):
    pass


# ── parsing ───────────────────────────────────────────────────────────────────

def _key(name):
    return str(name or '').strip().lower().replace(' ', '_').replace('-', '_')


def parse_records(upload, section):
    """Returns a list of dicts keyed by normalised header (`monthly_wage`)."""
    raw = upload.read()
    name = (getattr(upload, 'name', '') or '').lower()
    if name.endswith('.json') or raw.lstrip()[:1] in (b'[', b'{'):
        try:
            data = json.loads(raw.decode('utf-8-sig'))
        except (UnicodeDecodeError, ValueError):
            raise ImportFileError('The file is not valid JSON.')
        if isinstance(data, dict) and 'sections' in data:  # full-backup JSON
            data = (data['sections'].get(section) or {}).get('records') or []
        if not isinstance(data, list):
            raise ImportFileError('Expected a JSON list of records.')
        records = [{_key(k): v for k, v in r.items()} for r in data if isinstance(r, dict)]
    else:
        try:
            text = raw.decode('utf-8-sig')
        except UnicodeDecodeError:
            raise ImportFileError('The file must be UTF-8 CSV or JSON.')
        reader = csv.DictReader(io.StringIO(text))
        if not reader.fieldnames:
            raise ImportFileError('The file has no header row.')
        records = [{_key(k): (v or '').strip() for k, v in row.items() if k} for row in reader]
    if len(records) > MAX_ROWS:
        raise ImportFileError(f'Too many rows (max {MAX_ROWS}).')
    return records


def _s(rec, *keys):
    for k in keys:
        v = rec.get(k)
        if v not in (None, ''):
            return str(v).strip()
    return ''


def _float(rec, *keys, default=0.0):
    v = _s(rec, *keys)
    if v == '':
        return default
    try:
        return float(v.replace(',', ''))
    except ValueError:
        raise ValueError(f'"{v}" is not a number')


def _date(rec, *keys):
    v = _s(rec, *keys)
    if not v:
        return None
    for fmt, size in (('%Y-%m-%d', 10), ('%d/%m/%Y', 10), ('%d-%m-%Y', 10)):
        try:
            return datetime.strptime(v[:size], fmt).date()
        except ValueError:
            continue
    raise ValueError(f'"{v}" is not a valid date (use YYYY-MM-DD)')


def _aware(rec, *keys):
    v = _s(rec, *keys)
    if not v:
        return None
    for fmt, size in (('%Y-%m-%d %H:%M:%S', 19), ('%Y-%m-%d', 10)):
        try:
            return timezone.make_aware(datetime.strptime(v[:size], fmt))
        except ValueError:
            continue
    raise ValueError(f'"{v}" is not a valid date/time')


def _choice(value, choices, label, default):
    v = (value or '').strip()
    if not v:
        return default
    for code, human in choices:
        if v.lower() in (str(code).lower(), str(human).lower()):
            return code
    raise ValueError(f'unknown {label} "{v}"')


def _phone(value):
    digits = ''.join(ch for ch in str(value or '') if ch.isdigit())
    return digits[-10:] if len(digits) >= 10 else digits


# ── per-section importers: return 'created' | 'skipped', raise ValueError ─────

def _import_staff(rec, shop):
    name = _s(rec, 'name')
    phone = _phone(_s(rec, 'phone'))
    if not name or not phone:
        raise ValueError('name and phone are required')
    if Staff.objects.filter(shop=shop, phone=phone).exists():
        return 'skipped'
    Staff.objects.create(
        shop=shop, name=name, phone=phone,
        role=_s(rec, 'role') or 'Washer',
        email=_s(rec, 'email'),
        monthly_wage=_float(rec, 'monthly_wage', default=0.0),
        status=(_s(rec, 'status') or 'ACTIVE').upper(),
        # Never grant sign-in access from a file; the owner enables it in-app.
        has_app_login=False,
        start_date=_date(rec, 'start_date'),
    )
    return 'created'


def _staff_by_name(shop, name):
    matches = list(Staff.objects.filter(shop=shop, name__iexact=name)[:2])
    if not matches:
        raise ValueError(f'no staff member named "{name}" in this shop (import Staff first)')
    if len(matches) > 1:
        raise ValueError(f'more than one staff member named "{name}"')
    return matches[0]


def _import_attendance(rec, shop):
    staff = _staff_by_name(shop, _s(rec, 'staff_name'))
    day = _date(rec, 'date')
    if not day:
        raise ValueError('date is required')
    if Attendance.objects.filter(shop=shop, staff=staff, date=day).exists():
        return 'skipped'
    status = _choice(_s(rec, 'status'), Attendance.STATUS_CHOICES, 'status', Attendance.PRESENT)
    check_in = _s(rec, 'check_in_time', 'check_in')
    t = None
    if check_in:
        try:
            t = datetime.strptime(check_in[:8], '%H:%M:%S').time()
        except ValueError:
            raise ValueError(f'"{check_in}" is not a valid time (HH:MM:SS)')
    Attendance.objects.create(
        shop=shop, staff=staff, date=day, status=status,
        check_in_time=t, notes=_s(rec, 'notes')[:255],
    )
    return 'created'


def _import_payroll(rec, shop):
    staff = _staff_by_name(shop, _s(rec, 'staff_name'))
    month = _date(rec, 'month')
    amount = _float(rec, 'amount', default=None)
    if not month or amount is None:
        raise ValueError('month and amount are required')
    kind = (_s(rec, 'type') or 'Salary Payout').lower()
    model = SalaryAdvance if 'advance' in kind else SalaryPayment
    paid_on = _aware(rec, 'paid_on') or timezone.now()
    month = month.replace(day=1)
    if model.objects.filter(shop=shop, staff=staff, month=month, amount=amount,
                            paid_on=paid_on).exists():
        return 'skipped'
    model.objects.create(
        shop=shop, staff=staff, month=month, amount=amount, paid_on=paid_on,
        method=_choice(_s(rec, 'method', 'payment_method'), PaymentMethod.choices,
                       'payment method', PaymentMethod.CASH),
        note=_s(rec, 'note', 'notes'),
    )
    return 'created'


def _import_expense(rec, shop):
    title = _s(rec, 'title')
    amount = _float(rec, 'amount', default=None)
    if not title or amount is None:
        raise ValueError('title and amount are required')
    when = _aware(rec, 'date') or timezone.now()
    if Expense.objects.filter(shop=shop, title=title, amount=amount, date=when).exists():
        return 'skipped'
    Expense.objects.create(
        shop=shop, title=title, amount=amount, date=when,
        category=_choice(_s(rec, 'category'), ExpenseCategory.choices, 'category',
                         ExpenseCategory.OTHER),
        payment_method=_choice(_s(rec, 'payment_method'), PaymentMethod.choices,
                               'payment method', PaymentMethod.CASH),
        notes=_s(rec, 'notes') or None,
    )
    return 'created'


def _import_credit(rec, shop):
    title = _s(rec, 'title')
    amount = _float(rec, 'amount', default=None)
    if not title or amount is None:
        raise ValueError('title and amount are required')
    when = _aware(rec, 'date') or timezone.now()
    cat_name = _s(rec, 'category') or 'Other'
    category = CreditCategory.objects.filter(shop=shop, name__iexact=cat_name).first()
    if category is None:
        category = CreditCategory.objects.create(shop=shop, name=cat_name)
    if Credit.objects.filter(shop=shop, title=title, amount=amount, date=when,
                             category=category).exists():
        return 'skipped'
    Credit.objects.create(
        shop=shop, title=title, amount=amount, date=when, category=category,
        payment_method=_choice(_s(rec, 'payment_method'), PaymentMethod.choices,
                               'payment method', PaymentMethod.CASH),
        notes=_s(rec, 'notes') or None,
    )
    return 'created'


def _import_order(rec, shop):
    number = _s(rec, 'order_number')
    name = _s(rec, 'customer_name')
    if not name:
        raise ValueError('customer name is required')
    if number and Order.objects.filter(shop=shop, order_number=number).exists():
        return 'skipped'
    phone = _phone(_s(rec, 'customer_phone', 'phone'))
    customer = Customer.objects.filter(shop=shop, phone=phone).first() if phone else None
    total = _float(rec, 'total_amount')
    paid = _float(rec, 'paid_amount')
    order = Order(
        shop=shop, customer=customer, customer_name=name, customer_phone=phone,
        status=_choice(_s(rec, 'status'), OrderStatus.choices, 'status', OrderStatus.PLACED),
        payment_status=_choice(_s(rec, 'payment_status'), PaymentStatus.choices,
                               'payment status', PaymentStatus.UNPAID),
        payment_method=_choice(_s(rec, 'payment_method'), PaymentMethod.choices,
                               'payment method', PaymentMethod.CASH),
        delivery_type=_choice(_s(rec, 'delivery_type'), DeliveryType.choices,
                              'delivery type', DeliveryType.STORE_PICKUP),
        source=_choice(_s(rec, 'source'), OrderSource.choices, 'source', OrderSource.WEB),
        subtotal=_float(rec, 'subtotal'), delivery_charge=_float(rec, 'delivery_charge'),
        discount_amount=_float(rec, 'discount', 'discount_amount'),
        total_amount=total, paid_amount=paid,
        due_amount=_float(rec, 'due_amount', default=max(total - paid, 0.0)),
        scheduled_date=_date(rec, 'scheduled_date'),
        address=_s(rec, 'address'), notes=_s(rec, 'notes') or None,
    )
    if number:
        order.order_number = number
    order.save()
    created = _aware(rec, 'created_at')
    if created:  # auto_now_add ignores the constructor value
        Order.objects.filter(pk=order.pk).update(created_at=created)
    return 'created'


_IMPORTERS = {
    'staff': _import_staff,
    'orders': _import_order,
    'attendance': _import_attendance,
    'payroll': _import_payroll,
    'expenses': _import_expense,
    'credits': _import_credit,
}


def import_section(section, upload, dry_run=False):
    """Imports `upload` into the active shop. Returns a summary dict."""
    if section not in _IMPORTERS:
        raise ImportFileError(f"'{section}' cannot be imported here.")
    shop = require_shop()
    records = parse_records(upload, section)
    created = skipped = 0
    errors = []
    importer = _IMPORTERS[section]
    with transaction.atomic():
        for index, rec in enumerate(records, start=2):  # row 1 is the header
            try:
                with transaction.atomic():
                    outcome = importer(rec, shop)
            except ValueError as exc:
                errors.append({'row': index, 'error': str(exc)})
                continue
            if outcome == 'created':
                created += 1
            else:
                skipped += 1
        if dry_run:
            transaction.set_rollback(True)
    return {
        'section': section,
        'total': len(records),
        'created': created,
        'skipped_existing': skipped,
        'failed': len(errors),
        'errors': errors[:50],
        'dry_run': dry_run,
    }
