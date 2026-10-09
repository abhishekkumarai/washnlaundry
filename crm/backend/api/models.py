from django.db import models
from django.db.models import Max
from django.utils import timezone
import re
import uuid


# ── Canonical vocabularies ────────────────────────────────────────────────────
# Do not invent new values in seeds, views or the Flutter client —
# import/refer to these instead.

class OrderStatus(models.TextChoices):
    PLACED = 'PLACED', 'Placed'
    PROCESSING = 'PROCESSING', 'Processing'
    IRONING = 'IRONING', 'Ironing'
    READY = 'READY', 'Ready'
    OUT_FOR_DELIVERY = 'OUT_FOR_DELIVERY', 'Out for Delivery'
    DELIVERED = 'DELIVERED', 'Delivered'
    CANCELLED = 'CANCELLED', 'Cancelled'


class PaymentStatus(models.TextChoices):
    PAID = 'PAID', 'Paid'
    PARTIAL = 'PARTIAL', 'Partial'
    UNPAID = 'UNPAID', 'Unpaid'


class DeliveryType(models.TextChoices):
    STORE_PICKUP = 'STORE_PICKUP', 'Store Pickup'
    HOME_PICKUP = 'HOME_PICKUP', 'Home Pickup'
    HOME_DELIVERY = 'HOME_DELIVERY', 'Home Delivery'
    ONLINE = 'ONLINE', 'Online'


class OrderSource(models.TextChoices):
    WEB = 'WEB', 'Web Dashboard'
    MOBILE_APP = 'MOBILE_APP', 'Mobile App'
    PUBLIC_PAGE = 'PUBLIC_PAGE', 'Public Page'
    STAFF_APP = 'STAFF_APP', 'Staff App'
    AGENT_APP = 'AGENT_APP', 'Agent App'


class PricingUnit(models.TextChoices):
    PIECE = 'PC', 'per pc'
    KG = 'KG', 'per kg'
    SQFT = 'SQFT', 'per sq.ft'
    SET = 'SET', 'per set'


class PaymentMethod(models.TextChoices):
    """How money changed hands.

    Previously `payment_method` was a free-text CharField with no choices, and
    the Flutter client carried three divergent hardcoded lists: New Order
    offered CASH/UPI/CARD, while Expenses and Payroll each offered four in a
    different order. Serving this from `/api/meta/` gives all three one source.
    """
    CASH = 'CASH', 'Cash'
    UPI = 'UPI', 'UPI'
    CARD = 'CARD', 'Card'
    BANK_TRANSFER = 'BANK_TRANSFER', 'Bank Transfer'


class ExpenseCategory(models.TextChoices):
    SUPPLIES = 'Supplies', 'Supplies'
    RENT = 'Rent', 'Rent'
    UTILITIES = 'Utilities', 'Utilities'
    MAINTENANCE = 'Maintenance', 'Maintenance'
    SALARY = 'Salary', 'Salary'
    TRANSPORT = 'Transport', 'Transport'
    OTHER = 'Other', 'Other'


# ── Shop ──────────────────────────────────────────────────────────────────────

class Shop(models.Model):
    name = models.CharField(max_length=255, default='WashNLaundry Express')
    owner_name = models.CharField(max_length=255, default='Aditya Sharma')
    phone = models.CharField(max_length=50, default='+91 98765 43210')
    whatsapp = models.CharField(max_length=50, blank=True, default='')
    email = models.EmailField(blank=True, default='')

    address = models.TextField(default='123 MG Road, Connaught Place, New Delhi')
    city = models.CharField(max_length=120, blank=True, default='')
    state = models.CharField(max_length=120, blank=True, default='')
    pin_code = models.CharField(max_length=12, blank=True, default='')
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)

    gstin = models.CharField(max_length=50, default='07AAAAA0000A1Z5')
    pan = models.CharField(max_length=20, blank=True, default='')
    tax_rate = models.FloatField(default=5.0)

    account_holder_name = models.CharField(max_length=255, blank=True, default='')
    account_number = models.CharField(max_length=50, blank=True, default='')
    ifsc_code = models.CharField(max_length=20, blank=True, default='')
    bank_name = models.CharField(max_length=255, blank=True, default='')
    upi_id = models.CharField(max_length=120, blank=True, default='')

    # Order numbers are shop-prefixed and sequential, e.g. #WA3P-00001.
    order_prefix = models.CharField(max_length=8, blank=True, default='')

    # Minutes before a slot starts after which customers can no longer book it.
    pickup_buffer_minutes = models.IntegerField(default=30)
    delivery_buffer_minutes = models.IntegerField(default=30)

    # ── Operating rules ───────────────────────────────────────────────────────
    # These were client-side Dart constants: a 1.5x express surcharge baked into
    # new_order_screen.dart, and a 600 wage / 'Washer' role hardcoded as the
    # defaults on the Add Staff form. They are shop policy, not app policy.
    express_multiplier = models.FloatField(default=1.5)
    default_monthly_wage = models.FloatField(default=18000.0)
    default_staff_role = models.CharField(max_length=100, default='Washer')

    # ── Presentation ──────────────────────────────────────────────────────────
    # '₹' was a bare literal in ~15 widgets and the en_IN grouping was hardcoded
    # in the Reports screen.
    currency_symbol = models.CharField(max_length=8, default='₹')
    locale = models.CharField(max_length=16, default='en_IN')

    def save(self, *args, **kwargs):
        if not self.order_prefix:
            self.order_prefix = self.derive_prefix(self.name)
        super().save(*args, **kwargs)

    @staticmethod
    def derive_prefix(name):
        """'washing' -> 'WA3P'-ish: first letters of the name, padded to 4 chars."""
        letters = re.sub(r'[^A-Za-z0-9]', '', name or 'SHOP').upper()
        return (letters[:4] or 'SHOP').ljust(4, 'X')

    def __str__(self):
        return self.name


# ── Customers ─────────────────────────────────────────────────────────────────

class Customer(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20, unique=True)
    email = models.EmailField(blank=True, null=True, db_index=True)
    address = models.TextField(blank=True, null=True)
    area = models.CharField(max_length=120, blank=True, default='')
    landmark = models.CharField(max_length=255, blank=True, default='')
    preference = models.TextField(blank=True, default='')
    total_orders = models.IntegerField(default=0)
    total_spent = models.FloatField(default=0.0)
    due_amount = models.FloatField(default=0.0)
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def avg_order_value(self):
        return round(self.total_spent / self.total_orders, 2) if self.total_orders else 0.0

    @property
    def delivered_due_amount(self):
        """Total unpaid amount for orders that have already been delivered."""
        from .models import Order
        return float(
            Order.objects.filter(
                models.Q(customer=self) | (models.Q(customer_phone=self.phone) if self.phone else models.Q()),
                status=OrderStatus.DELIVERED,
            ).aggregate(s=models.Sum('due_amount'))['s'] or 0.0
        )

    def __str__(self):
        return f"{self.name} ({self.phone})"


# ── Service catalogue ─────────────────────────────────────────────────────────

class GarmentCategory(models.Model):
    name = models.CharField(max_length=100)
    icon = models.CharField(max_length=50, default='Shirt')
    display_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = 'Garment categories'

    @property
    def item_count(self):
        return self.items.filter(is_active=True).count()

    @property
    def price_range(self):
        prices = list(self.items.filter(is_active=True).values_list('price', flat=True))
        return {'min': min(prices), 'max': max(prices)} if prices else {'min': 0, 'max': 0}

    def __str__(self):
        return self.name


class GarmentItem(models.Model):
    """One row per (category, item) with a single price.

    The same garment appears under several categories at different prices —
    'Shirt' is ₹15 under Ironing and ₹40 under Dry Cleaning. That is two rows,
    not one row with two price columns.
    """
    category = models.ForeignKey(GarmentCategory, on_delete=models.CASCADE, related_name='items')
    name = models.CharField(max_length=255)
    icon = models.CharField(max_length=50, default='Shirt')
    # Product photography. The client used to hold a 12-entry map of garment
    # *names* to Unsplash URLs, so renaming an item lost its picture and a shop
    # could never supply its own. Blank falls back to the icon treatment.
    image_url = models.URLField(max_length=500, blank=True, default='')
    price = models.FloatField(default=0.0)
    unit = models.CharField(max_length=8, choices=PricingUnit.choices, default=PricingUnit.PIECE)
    is_active = models.BooleanField(default=True)
    display_order = models.IntegerField(default=0)

    class Meta:
        ordering = ['category__display_order', 'display_order', 'id']

    def __str__(self):
        return f"{self.name} ({self.category.name})"


# ── Orders ────────────────────────────────────────────────────────────────────

class Order(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    order_number = models.CharField(max_length=50, unique=True, blank=True)

    customer = models.ForeignKey(Customer, on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    customer_name = models.CharField(max_length=255)
    # Blank for a counter walk-in: the POS bills them as "Walk-in customer"
    # with nothing to send a receipt to. Requiring a phone here forced the
    # client to invent one, which billed a stranger over WhatsApp.
    customer_phone = models.CharField(max_length=20, blank=True, default='')

    status = models.CharField(max_length=20, choices=OrderStatus.choices, default=OrderStatus.PLACED)
    payment_status = models.CharField(max_length=20, choices=PaymentStatus.choices, default=PaymentStatus.UNPAID)
    payment_method = models.CharField(max_length=50, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    delivery_type = models.CharField(max_length=20, choices=DeliveryType.choices, default=DeliveryType.STORE_PICKUP)
    source = models.CharField(max_length=20, choices=OrderSource.choices, default=OrderSource.WEB)
    # Free text, not a choice: the live timeline renders "Created by abhishek
    # kumar" for a counter order and "Created by Mobile App" for an app one, so
    # this holds either a person or a channel. Blank falls back to the source
    # label on the client.
    created_by = models.CharField(max_length=180, blank=True, default='')

    subtotal = models.FloatField(default=0.0)
    delivery_charge = models.FloatField(default=0.0)
    discount_amount = models.FloatField(default=0.0)
    total_amount = models.FloatField(default=0.0)
    paid_amount = models.FloatField(default=0.0)
    due_amount = models.FloatField(default=0.0)

    express = models.BooleanField(default=False)
    notes = models.TextField(blank=True, null=True)

    scheduled_date = models.DateField(null=True, blank=True)
    # Separate from scheduled_date rather than upgrading it to a DateTimeField
    # — same split TimeSlot already uses for pickup/delivery slots, and it
    # keeps every existing scheduled_date comparison (is_overdue, the
    # Scheduled tab filter) working unchanged.
    scheduled_time = models.TimeField(null=True, blank=True)
    # Home pickup only: when the agent collects from the customer. The
    # delivery leg stays on scheduled_date / scheduled_time above.
    pickup_date = models.DateField(null=True, blank=True)
    pickup_time = models.TimeField(null=True, blank=True)
    # Where a carried order is picked up from or delivered to — the review
    # step's "Pickup address" / "Delivery address".
    address = models.TextField(blank=True, default='')
    assigned_agent = models.ForeignKey(
        'Staff', on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_orders'
    )

    # Timeline — one timestamp per stage, so the order detail screen can render
    # the full audit trail rather than just the current status.
    placed_at = models.DateTimeField(null=True, blank=True)
    processing_at = models.DateTimeField(null=True, blank=True)
    ironing_at = models.DateTimeField(null=True, blank=True)
    ready_at = models.DateTimeField(null=True, blank=True)
    out_for_delivery_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    STATUS_TIMESTAMP_FIELD = {
        OrderStatus.PLACED: 'placed_at',
        OrderStatus.PROCESSING: 'processing_at',
        OrderStatus.IRONING: 'ironing_at',
        OrderStatus.READY: 'ready_at',
        OrderStatus.OUT_FOR_DELIVERY: 'out_for_delivery_at',
        OrderStatus.DELIVERED: 'delivered_at',
        OrderStatus.CANCELLED: 'cancelled_at',
    }

    def save(self, *args, **kwargs):
        if not self.order_number:
            self.order_number = self.next_order_number()
        super().save(*args, **kwargs)

    @staticmethod
    def next_order_number():
        shop = Shop.objects.first()
        prefix = shop.order_prefix if shop else 'SHOP'
        last = (
            Order.objects.filter(order_number__startswith=f'{prefix}-')
            .aggregate(Max('order_number'))['order_number__max']
        )
        seq = 1
        if last:
            try:
                seq = int(last.rsplit('-', 1)[1]) + 1
            except (IndexError, ValueError):
                seq = Order.objects.count() + 1
        return f'{prefix}-{seq:05d}'

    def mark_status(self, new_status, when=None, note=''):
        """Set status, stamp the matching timeline field, and log the change.

        The stamp is always refreshed, including on a revisit (e.g. Ready
        walked back to Processing and forward to Ready again) — the step bar
        reads these fields, and a stale first-arrival timestamp next to a
        Timeline that shows the revisit happened moments ago is exactly the
        "update and the audit log don't match" report this fixes. Every
        transition, revisit included, is still preserved in full in
        `audit_log` below; only the single-timestamp-per-stage summary now
        always reflects the most recent arrival.
        """
        self.status = new_status
        field = self.STATUS_TIMESTAMP_FIELD.get(new_status)
        at = when or timezone.now()
        if field:
            setattr(self, field, at)
        self.save()
        self.audit_log.create(
            status=new_status, title=OrderStatus(new_status).label, detail=note, created_at=at,
        )

    @property
    def is_overdue(self):
        from django.utils import timezone
        if not self.scheduled_date:
            return False
        if self.status in (OrderStatus.DELIVERED, OrderStatus.CANCELLED):
            return False
        return self.scheduled_date < timezone.localdate()

    def __str__(self):
        return f"Order #{self.order_number} - {self.customer_name}"


class OrderAuditLog(models.Model):
    """One row per recorded change to an order: creation, a status
    transition, a payment collection, or an edit to its details. Backs the
    order-detail "Timeline & Audit Log" panel with real per-change history,
    unlike `STATUS_TIMESTAMP_FIELD`, which only holds one timestamp per
    stage and can't carry a note or a payment amount.

    Settable `created_at`, not auto_now_add, so seed data can backdate a
    plausible history the same way `Expense.date` and `SalaryPayment.paid_on`
    already do.
    """
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='audit_log')
    status = models.CharField(max_length=20, choices=OrderStatus.choices, blank=True, default='')
    title = models.CharField(max_length=255)
    detail = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.order.order_number}: {self.title}"


class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    item = models.ForeignKey(GarmentItem, on_delete=models.SET_NULL, null=True, blank=True)
    item_title = models.CharField(max_length=255)
    service_type = models.CharField(max_length=100)
    status = models.CharField(max_length=20, choices=OrderStatus.choices, default=OrderStatus.PLACED)
    quantity = models.IntegerField(default=1)
    unit = models.CharField(max_length=8, choices=PricingUnit.choices, default=PricingUnit.PIECE)
    unit_price = models.FloatField(default=0.0)
    total_price = models.FloatField(default=0.0)

    def __str__(self):
        return f"{self.quantity} x {self.item_title}"


# ── Scheduling ────────────────────────────────────────────────────────────────

class ServiceArea(models.Model):
    name = models.CharField(max_length=180)
    pin_code = models.CharField(max_length=12, blank=True, default='')
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class TimeSlot(models.Model):
    PICKUP = 'PICKUP'
    DELIVERY = 'DELIVERY'
    KIND_CHOICES = [(PICKUP, 'Pickup'), (DELIVERY, 'Delivery')]

    kind = models.CharField(max_length=10, choices=KIND_CHOICES)
    start_time = models.TimeField()
    end_time = models.TimeField()
    # Max orders per day for this slot; null means unlimited.
    capacity = models.IntegerField(null=True, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['kind', 'start_time']

    def __str__(self):
        return f"{self.get_kind_display()} {self.start_time:%I:%M %p} - {self.end_time:%I:%M %p}"


# ── Back office ───────────────────────────────────────────────────────────────

class Expense(models.Model):
    title = models.CharField(max_length=255)
    category = models.CharField(max_length=100, choices=ExpenseCategory.choices, default=ExpenseCategory.SUPPLIES)
    amount = models.FloatField()
    payment_method = models.CharField(max_length=50, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    # Settable, not auto_now_add: an expense is logged when someone gets round
    # to it, but it belongs to the day it was actually incurred. Stamping it
    # with the moment of entry filed July's rent under whatever day you typed
    # it in, and the monthly totals inherited that error.
    date = models.DateTimeField(default=timezone.now)
    notes = models.TextField(blank=True, null=True)

    def __str__(self):
        return self.title


# Shop-managed from Settings → Credit categories, unlike ExpenseCategory's fixed
# TextChoices. Seeded by migration 0018 with DEFAULT_CREDIT_CATEGORIES.
DEFAULT_CREDIT_CATEGORIES = [
    'Laundry Income',
    'Dry Cleaning Income',
    'Delivery Charges',
    'Customer Advance',
    'Owner Investment',
    'Other',
]


class CreditCategory(models.Model):
    name = models.CharField(max_length=100, unique=True)
    display_order = models.IntegerField(default=0)
    # Turning a category off hides it from new credits but keeps it on the
    # credits already filed under it — the only option once it is in use,
    # since Credit.category is PROTECT.
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['display_order', 'name']
        verbose_name_plural = 'Credit categories'

    def __str__(self):
        return self.name


class Credit(models.Model):
    title = models.CharField(max_length=255)
    category = models.ForeignKey(CreditCategory, on_delete=models.PROTECT, related_name='credits')
    amount = models.FloatField()
    payment_method = models.CharField(max_length=50, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    date = models.DateTimeField(default=timezone.now)
    notes = models.TextField(blank=True, null=True)

    def __str__(self):
        return self.title


class Staff(models.Model):
    name = models.CharField(max_length=255)
    role = models.CharField(max_length=100, default='Washer')
    phone = models.CharField(max_length=20)
    # Google account used to sign in to the CRM. Only counts as CRM access when
    # `has_app_login` is also set and the status is ACTIVE (see api/auth.py).
    email = models.EmailField(blank=True, default='')
    monthly_wage = models.FloatField(default=15000.0)
    status = models.CharField(max_length=20, default='ACTIVE')
    # Whether this person has credentials for the Staff/Agent mobile app.
    # Plans cap how many of these a shop gets.
    has_app_login = models.BooleanField(default=False)
    # Null for staff added before this field existed — treated as "no
    # restriction" everywhere it's checked, so old records aren't retroactively
    # blocked from having attendance on file.
    start_date = models.DateField(null=True, blank=True)

    class Meta:
        verbose_name_plural = 'Staff'

    def __str__(self):
        return f"{self.name} ({self.role})"


class SalaryPayment(models.Model):
    """A payout against one staff member's wages for one month.

    Wages *earned* are derived — `Staff.monthly_wage` divided into a per-day
    rate (by the number of days in the month being paid) times days worked,
    which Attendance already records. Nothing recorded what was actually
    handed over, so the Payroll screen's Paid / Pending columns had no
    possible source and were hardcoded.

    Deliberately not unique on (staff, month): a month can be paid in
    instalments, which is what makes PARTIAL a real state rather than a
    decoration.
    """
    staff = models.ForeignKey(Staff, on_delete=models.CASCADE, related_name='salary_payments')
    # Always the 1st, so "which month" is a single comparable value.
    month = models.DateField()
    amount = models.FloatField()
    # Settable, like Expense.date and for the same reason: a payout is recorded
    # when someone gets round to it but belongs to the day it was made.
    paid_on = models.DateTimeField(default=timezone.now)
    method = models.CharField(max_length=50, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    note = models.TextField(blank=True, default='')
    # The real app's own text is "Paid salaries appear in Expenses
    # automatically" — kept in sync here rather than a one-off copy, so
    # editing or deleting a payment updates/removes its Expense too instead
    # of leaving a stale row behind.
    expense = models.OneToOneField(
        Expense, null=True, blank=True, editable=False,
        on_delete=models.SET_NULL, related_name='salary_payment',
    )

    class Meta:
        ordering = ['-month', '-paid_on']

    @staticmethod
    def month_start(when):
        """Normalise any date in a month to that month's first day."""
        return when.replace(day=1)

    def save(self, *args, **kwargs):
        if self.month:
            self.month = self.month_start(self.month)
        super().save(*args, **kwargs)

        expense_fields = dict(
            title=f'Salary — {self.staff.name} ({self.month:%b %Y})',
            category=ExpenseCategory.SALARY,
            amount=self.amount,
            payment_method=self.method,
            date=self.paid_on,
            notes=self.note,
        )
        if self.expense_id:
            Expense.objects.filter(pk=self.expense_id).update(**expense_fields)
        else:
            expense = Expense.objects.create(**expense_fields)
            type(self).objects.filter(pk=self.pk).update(expense=expense)
            self.expense = expense

    def delete(self, *args, **kwargs):
        expense = self.expense
        super().delete(*args, **kwargs)
        if expense:
            expense.delete()

    def __str__(self):
        return f"{self.staff.name} {self.month:%b %Y} ₹{self.amount}"


class SalaryAdvance(models.Model):
    """An advance handed to a staff member against a month's wages.

    Distinct from `SalaryPayment`: a payment records money paid out against
    what's owed (reducing pending balance), while an advance reduces what's
    owed in the first place — it comes off net pay before pending is even
    computed. See `views.payroll_summary`.
    """
    staff = models.ForeignKey(Staff, on_delete=models.CASCADE, related_name='salary_advances')
    month = models.DateField()
    amount = models.FloatField()
    paid_on = models.DateTimeField(default=timezone.now)
    method = models.CharField(max_length=50, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    note = models.TextField(blank=True, default='')

    class Meta:
        ordering = ['-month', '-paid_on']

    @staticmethod
    def month_start(when):
        return when.replace(day=1)

    def save(self, *args, **kwargs):
        if self.month:
            self.month = self.month_start(self.month)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.staff.name} advance {self.month:%b %Y} ₹{self.amount}"


class Attendance(models.Model):
    PRESENT = 'PRESENT'
    ABSENT = 'ABSENT'
    HALF_DAY = 'HALF_DAY'
    LEAVE = 'LEAVE'
    STATUS_CHOICES = [
        (PRESENT, 'Present'),
        (ABSENT, 'Absent'),
        (HALF_DAY, 'Half Day'),
        (LEAVE, 'Leave'),
    ]

    # What a day in each state is worth when payroll totals it up. HALF_DAY is
    # offered on the register and stored, so paying it as a whole day would be
    # wrong; LEAVE is unpaid here, matching ABSENT.
    DAY_VALUE = {
        PRESENT: 1.0,
        HALF_DAY: 0.5,
        ABSENT: 0.0,
        LEAVE: 0.0,
    }

    staff = models.ForeignKey(Staff, on_delete=models.CASCADE, related_name='attendance')
    date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=PRESENT)
    check_in_time = models.TimeField(null=True, blank=True)
    notes = models.CharField(max_length=255, blank=True, default='')

    class Meta:
        unique_together = ('staff', 'date')

    @property
    def day_value(self):
        return self.DAY_VALUE.get(self.status, 0.0)

    def __str__(self):
        return f"{self.staff.name} {self.date} {self.status}"


class Lead(models.Model):
    """A pickup request captured by the website chat bot, before it is an Order."""
    SOURCE_CHAT = 'chat'

    # PENDING: saved, alert email not yet delivered (provider down / no key).
    # SENT: delivered; FAILED: gave up after MAX_EMAIL_ATTEMPTS.
    PENDING = 'PENDING'
    SENT = 'SENT'
    FAILED = 'FAILED'
    EMAIL_STATUS_CHOICES = [(PENDING, 'Pending'), (SENT, 'Sent'), (FAILED, 'Failed')]
    MAX_EMAIL_ATTEMPTS = 5

    name = models.CharField(max_length=120)
    phone = models.CharField(max_length=20)
    address = models.TextField()
    requirements = models.TextField()
    source = models.CharField(max_length=20, default=SOURCE_CHAT)
    email_status = models.CharField(max_length=10, choices=EMAIL_STATUS_CHOICES, default=PENDING)
    email_attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Lead {self.name} ({self.phone})"


class EmailLinkRequest(models.Model):
    """A signed-in Google account asking to be attached to an existing Customer.

    Created when someone claims a phone number that already has a Customer
    record. Without an OTP, linking automatically would let anyone take over a
    stranger's order history by typing their number, so staff approve it
    (Django admin, or /api/link-requests/<id>/approve/) before the email is
    written onto the Customer.
    """
    PENDING = 'PENDING'
    APPROVED = 'APPROVED'
    REJECTED = 'REJECTED'
    STATUS_CHOICES = [(PENDING, 'Pending'), (APPROVED, 'Approved'), (REJECTED, 'Rejected')]

    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='link_requests')
    email = models.EmailField()
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default=PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def approve(self):
        """Attach the email to the customer, unless they already have a different one."""
        if self.status != self.PENDING:
            return False
        if self.customer.email and self.customer.email.lower() != self.email.lower():
            return False
        Customer.objects.filter(pk=self.customer_id).update(email=self.email.lower())
        self.status = self.APPROVED
        self.resolved_at = timezone.now()
        self.save(update_fields=['status', 'resolved_at'])
        return True

    def __str__(self):
        return f"{self.email} -> {self.customer} [{self.status}]"


# ── Meta & Social Suite (KAN-Meta) ───────────────────────────────────────────

class MetaSettings(models.Model):
    """Stores local Meta Graph API Access Tokens, connected Facebook Page and Instagram details."""
    shop = models.OneToOneField(Shop, on_delete=models.CASCADE, related_name='meta_settings', null=True, blank=True)
    page_access_token = models.CharField(max_length=512, blank=True, default='')
    app_id = models.CharField(max_length=120, blank=True, default='')
    app_secret = models.CharField(max_length=120, blank=True, default='')
    facebook_page_id = models.CharField(max_length=120, blank=True, default='')
    facebook_page_name = models.CharField(max_length=255, blank=True, default='WashNLaundry Official')
    instagram_account_id = models.CharField(max_length=120, blank=True, default='')
    instagram_username = models.CharField(max_length=120, blank=True, default='washnlaundry')
    auto_reply_enabled = models.BooleanField(default=True)
    is_connected = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"MetaSettings for {self.facebook_page_name} ({'Connected' if self.is_connected else 'Disconnected'})"


class MetaPlatform(models.TextChoices):
    FACEBOOK = 'FACEBOOK', 'Facebook'
    INSTAGRAM = 'INSTAGRAM', 'Instagram'
    BOTH = 'BOTH', 'Facebook & Instagram'


class MetaPost(models.Model):
    """Posts scheduled or published across Facebook and Instagram."""
    STATUS_DRAFT = 'DRAFT'
    STATUS_SCHEDULED = 'SCHEDULED'
    STATUS_PUBLISHED = 'PUBLISHED'
    STATUS_FAILED = 'FAILED'
    STATUS_CHOICES = [
        (STATUS_DRAFT, 'Draft'),
        (STATUS_SCHEDULED, 'Scheduled'),
        (STATUS_PUBLISHED, 'Published'),
        (STATUS_FAILED, 'Failed'),
    ]

    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='meta_posts', null=True, blank=True)
    platform = models.CharField(max_length=20, choices=MetaPlatform.choices, default=MetaPlatform.BOTH)
    content = models.TextField()
    image_url = models.URLField(max_length=1000, blank=True, default='')
    scheduled_for = models.DateTimeField(null=True, blank=True)
    published_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_DRAFT)
    meta_post_id = models.CharField(max_length=120, blank=True, default='')
    likes_count = models.IntegerField(default=0)
    comments_count = models.IntegerField(default=0)
    shares_count = models.IntegerField(default=0)
    error_message = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.platform}] {self.content[:30]} ({self.status})"


class MetaMessage(models.Model):
    """Direct message conversations from Instagram & Facebook with Meta AI responses."""
    SENDER_USER = 'USER'
    SENDER_AI = 'AI'
    SENDER_STAFF = 'STAFF'
    SENDER_CHOICES = [
        (SENDER_USER, 'Customer'),
        (SENDER_AI, 'Meta AI'),
        (SENDER_STAFF, 'Staff Agent'),
    ]

    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='meta_messages', null=True, blank=True)
    platform = models.CharField(max_length=20, choices=MetaPlatform.choices, default=MetaPlatform.INSTAGRAM)
    conversation_id = models.CharField(max_length=120, db_index=True)
    sender_type = models.CharField(max_length=10, choices=SENDER_CHOICES, default=SENDER_USER)
    sender_name = models.CharField(max_length=120, default='Customer')
    sender_id = models.CharField(max_length=120, blank=True, default='')
    text = models.TextField()
    is_lead = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.sender_name} ({self.platform}): {self.text[:30]}"


class MetaLead(models.Model):
    """Ad inquiries and chat leads captured from Facebook and Instagram."""
    STATUS_NEW = 'NEW'
    STATUS_CONTACTED = 'CONTACTED'
    STATUS_CONVERTED = 'CONVERTED'
    STATUS_CHOICES = [
        (STATUS_NEW, 'New Lead'),
        (STATUS_CONTACTED, 'Contacted'),
        (STATUS_CONVERTED, 'Converted to Order'),
    ]

    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='meta_leads', null=True, blank=True)
    platform = models.CharField(max_length=20, choices=MetaPlatform.choices, default=MetaPlatform.INSTAGRAM)
    ad_campaign = models.CharField(max_length=255, blank=True, default='Organic DM / Promo')
    customer_name = models.CharField(max_length=120)
    customer_phone = models.CharField(max_length=30, blank=True, default='')
    customer_email = models.CharField(max_length=120, blank=True, default='')
    inquiry_notes = models.TextField(blank=True, default='')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_NEW)
    converted_order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Lead: {self.customer_name} via {self.platform} ({self.status})"

