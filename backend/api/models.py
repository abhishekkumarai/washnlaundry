from django.db import models
from django.db.models import Max
import re
import uuid


# ── Canonical vocabularies ────────────────────────────────────────────────────
# These mirror app.laundrybill.com. Do not invent new values in seeds, views or
# the Flutter client — import/refer to these instead.

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


# ── Shop ──────────────────────────────────────────────────────────────────────

class Shop(models.Model):
    name = models.CharField(max_length=255, default='LaundryBill Express')
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
    email = models.EmailField(blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    area = models.CharField(max_length=120, blank=True, default='')
    total_orders = models.IntegerField(default=0)
    total_spent = models.FloatField(default=0.0)
    due_amount = models.FloatField(default=0.0)
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def avg_order_value(self):
        return round(self.total_spent / self.total_orders, 2) if self.total_orders else 0.0

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
    price = models.FloatField(default=0.0)
    unit = models.CharField(max_length=8, choices=PricingUnit.choices, default=PricingUnit.PIECE)
    turnaround_days = models.IntegerField(default=1)
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
    customer_phone = models.CharField(max_length=20)

    status = models.CharField(max_length=20, choices=OrderStatus.choices, default=OrderStatus.PLACED)
    payment_status = models.CharField(max_length=20, choices=PaymentStatus.choices, default=PaymentStatus.UNPAID)
    payment_method = models.CharField(max_length=50, default='CASH')
    delivery_type = models.CharField(max_length=20, choices=DeliveryType.choices, default=DeliveryType.STORE_PICKUP)
    source = models.CharField(max_length=20, choices=OrderSource.choices, default=OrderSource.WEB)

    subtotal = models.FloatField(default=0.0)
    delivery_charge = models.FloatField(default=0.0)
    discount_amount = models.FloatField(default=0.0)
    total_amount = models.FloatField(default=0.0)
    paid_amount = models.FloatField(default=0.0)
    due_amount = models.FloatField(default=0.0)

    express = models.BooleanField(default=False)
    notes = models.TextField(blank=True, null=True)

    scheduled_date = models.DateField(null=True, blank=True)
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

    def mark_status(self, new_status, when=None):
        """Set status and stamp the matching timeline field."""
        from django.utils import timezone
        self.status = new_status
        field = self.STATUS_TIMESTAMP_FIELD.get(new_status)
        if field and not getattr(self, field):
            setattr(self, field, when or timezone.now())
        self.save()

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
    category = models.CharField(max_length=100, default='Supplies')
    amount = models.FloatField()
    payment_method = models.CharField(max_length=50, default='CASH')
    date = models.DateTimeField(auto_now_add=True)
    notes = models.TextField(blank=True, null=True)

    def __str__(self):
        return self.title


class Staff(models.Model):
    name = models.CharField(max_length=255)
    role = models.CharField(max_length=100, default='Washer')
    phone = models.CharField(max_length=20)
    daily_wage = models.FloatField(default=500.0)
    status = models.CharField(max_length=20, default='ACTIVE')
    # Drives the "Delivery agents" KPI and decides who can be assigned to an
    # order; the Agent app is a separate portal from the Staff app.
    is_delivery_agent = models.BooleanField(default=False)
    # Whether this person has credentials for the Staff/Agent mobile app.
    # Plans cap how many of these a shop gets.
    has_app_login = models.BooleanField(default=False)

    class Meta:
        verbose_name_plural = 'Staff'

    def __str__(self):
        return f"{self.name} ({self.role})"


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

    staff = models.ForeignKey(Staff, on_delete=models.CASCADE, related_name='attendance')
    date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=PRESENT)

    class Meta:
        unique_together = ('staff', 'date')

    def __str__(self):
        return f"{self.staff.name} {self.date} {self.status}"
