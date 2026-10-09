from django.conf import settings
from django.db import models
from django.db.models import Max
from django.utils import timezone
from django.utils.text import slugify
import re
import uuid

from .tenancy import TenantModel, get_current_tenant


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
    slug = models.SlugField(max_length=100, unique=True, blank=True, null=True)
    subdomain = models.CharField(max_length=100, blank=True, default='')
    custom_domain = models.CharField(max_length=255, blank=True, default='')
    status = models.CharField(max_length=20, default='ACTIVE')

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
    express_multiplier = models.FloatField(default=1.5)
    default_monthly_wage = models.FloatField(default=18000.0)
    default_staff_role = models.CharField(max_length=100, default='Washer')

    # ── Presentation ──────────────────────────────────────────────────────────
    currency_symbol = models.CharField(max_length=8, default='₹')
    locale = models.CharField(max_length=16, default='en_IN')

    def save(self, *args, **kwargs):
        if not self.order_prefix:
            self.order_prefix = self.derive_prefix(self.name)
        if not self.slug:
            base_slug = slugify(self.name) or 'shop'
            candidate = base_slug
            idx = 1
            while Shop.objects.filter(slug=candidate).exclude(pk=self.pk).exists():
                candidate = f"{base_slug}-{idx}"
                idx += 1
            self.slug = candidate
        if not self.subdomain and self.slug:
            self.subdomain = self.slug
        super().save(*args, **kwargs)

    @staticmethod
    def derive_prefix(name):
        """'washing' -> 'WA3P'-ish: first letters of the name, padded to 4 chars."""
        letters = re.sub(r'[^A-Za-z0-9]', '', name or 'SHOP').upper()
        return (letters[:4] or 'SHOP').ljust(4, 'X')

    def __str__(self):
        return self.name


class ShopRole(models.TextChoices):
    OWNER = 'OWNER', 'Owner'
    STAFF = 'STAFF', 'Staff'
    CUSTOMER = 'CUSTOMER', 'Customer'


class ShopMembership(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='shop_memberships')
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='memberships')
    role = models.CharField(max_length=20, choices=ShopRole.choices, default=ShopRole.STAFF)
    is_default = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'shop')
        ordering = ['-is_default', 'created_at']

    def __str__(self):
        return f"{self.user} @ {self.shop.name} ({self.role})"


class ShopOrderSequence(models.Model):
    shop = models.OneToOneField(Shop, on_delete=models.CASCADE, related_name='order_sequence')
    last_number = models.PositiveIntegerField(default=0)

    @classmethod
    def get_next_order_number(cls, shop):
        from django.db import transaction
        with transaction.atomic():
            seq, _ = cls.objects.select_for_update().get_or_create(shop=shop)
            prefix = shop.order_prefix or 'SHOP'
            last_order = (
                Order.objects.filter(shop=shop, order_number__startswith=f'{prefix}-')
                .aggregate(Max('order_number'))['order_number__max']
            )
            max_num = 0
            if last_order:
                try:
                    max_num = int(last_order.rsplit('-', 1)[1])
                except (IndexError, ValueError):
                    max_num = Order.objects.filter(shop=shop).count()
            next_num = max_num + 1
            seq.last_number = next_num
            seq.save(update_fields=['last_number'])
            return f"{prefix}-{next_num:05d}"

    def __str__(self):
        return f"{self.shop.name}: #{self.last_number}"


# ── Customers ─────────────────────────────────────────────────────────────────

class Customer(TenantModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='customers', db_index=True)
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20)
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

    class Meta:
        unique_together = ('shop', 'phone')

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

class GarmentCategory(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='categories', db_index=True)
    name = models.CharField(max_length=100)
    icon = models.CharField(max_length=50, default='Shirt')
    display_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = 'Garment categories'
        unique_together = ('shop', 'name')

    @property
    def item_count(self):
        return self.items.filter(is_active=True).count()

    @property
    def price_range(self):
        prices = list(self.items.filter(is_active=True).values_list('price', flat=True))
        return {'min': min(prices), 'max': max(prices)} if prices else {'min': 0, 'max': 0}

    def __str__(self):
        return self.name


class GarmentItem(TenantModel):
    """One row per (category, item) with a single price.

    The same garment appears under several categories at different prices —
    'Shirt' is ₹15 under Ironing and ₹40 under Dry Cleaning. That is two rows,
    not one row with two price columns.
    """
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='items', db_index=True)
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

    def save(self, *args, **kwargs):
        if not getattr(self, 'shop_id', None) and getattr(self, 'category_id', None):
            self.shop = self.category.shop
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} ({self.category.name})"


# ── Orders ────────────────────────────────────────────────────────────────────

class Order(TenantModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='orders', db_index=True)
    order_number = models.CharField(max_length=50, blank=True)

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
    scheduled_time = models.TimeField(null=True, blank=True)
    pickup_date = models.DateField(null=True, blank=True)
    pickup_time = models.TimeField(null=True, blank=True)
    address = models.TextField(blank=True, default='')
    assigned_agent = models.ForeignKey(
        'Staff', on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_orders'
    )

    # Timeline — one timestamp per stage
    placed_at = models.DateTimeField(null=True, blank=True)
    processing_at = models.DateTimeField(null=True, blank=True)
    ironing_at = models.DateTimeField(null=True, blank=True)
    ready_at = models.DateTimeField(null=True, blank=True)
    out_for_delivery_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('shop', 'order_number')

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
        if not getattr(self, 'shop_id', None):
            tenant = get_current_tenant()
            if tenant:
                self.shop = tenant
            elif self.customer and getattr(self.customer, 'shop_id', None):
                self.shop = self.customer.shop
            else:
                default_shop = Shop.objects.first()
                if default_shop:
                    self.shop = default_shop
        if not self.order_number and getattr(self, 'shop_id', None):
            self.order_number = self.next_order_number(self.shop)
        elif not self.order_number:
            self.order_number = self.next_order_number()
        super().save(*args, **kwargs)

    @classmethod
    def next_order_number(cls, shop=None):
        target_shop = shop or get_current_tenant() or Shop.objects.first()
        if not target_shop:
            return 'SHOP-00001'
        return ShopOrderSequence.get_next_order_number(target_shop)

    def mark_status(self, new_status, when=None, note=''):
        self.status = new_status
        field = self.STATUS_TIMESTAMP_FIELD.get(new_status)
        at = when or timezone.now()
        if field:
            setattr(self, field, at)
        self.save()
        self.audit_log.create(
            status=new_status, title=OrderStatus(new_status).label, detail=note, created_at=at,
            shop=self.shop
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


class OrderAuditLog(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='audit_logs', db_index=True)
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='audit_log')
    status = models.CharField(max_length=20, choices=OrderStatus.choices, blank=True, default='')
    title = models.CharField(max_length=255)
    detail = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['created_at']

    def save(self, *args, **kwargs):
        if not getattr(self, 'shop_id', None) and getattr(self, 'order_id', None):
            self.shop = self.order.shop
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.order.order_number}: {self.title}"


class OrderItem(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='order_items', db_index=True)
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    item = models.ForeignKey(GarmentItem, on_delete=models.SET_NULL, null=True, blank=True)
    item_title = models.CharField(max_length=255)
    service_type = models.CharField(max_length=100)
    status = models.CharField(max_length=20, choices=OrderStatus.choices, default=OrderStatus.PLACED)
    quantity = models.IntegerField(default=1)
    unit = models.CharField(max_length=8, choices=PricingUnit.choices, default=PricingUnit.PIECE)
    unit_price = models.FloatField(default=0.0)
    total_price = models.FloatField(default=0.0)

    def save(self, *args, **kwargs):
        if not getattr(self, 'shop_id', None) and getattr(self, 'order_id', None):
            self.shop = self.order.shop
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.quantity} x {self.item_title}"


# ── Scheduling ────────────────────────────────────────────────────────────────

class ServiceArea(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='service_areas', db_index=True)
    name = models.CharField(max_length=180)
    pin_code = models.CharField(max_length=12, blank=True, default='')
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class TimeSlot(TenantModel):
    PICKUP = 'PICKUP'
    DELIVERY = 'DELIVERY'
    KIND_CHOICES = [(PICKUP, 'Pickup'), (DELIVERY, 'Delivery')]

    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='time_slots', db_index=True)
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

class Expense(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='expenses', db_index=True)
    title = models.CharField(max_length=255)
    category = models.CharField(max_length=100, choices=ExpenseCategory.choices, default=ExpenseCategory.SUPPLIES)
    amount = models.FloatField()
    payment_method = models.CharField(max_length=50, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
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


class CreditCategory(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='credit_categories', db_index=True)
    name = models.CharField(max_length=100)
    display_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['display_order', 'name']
        verbose_name_plural = 'Credit categories'
        unique_together = ('shop', 'name')

    def __str__(self):
        return self.name


class Credit(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='credits', db_index=True)
    title = models.CharField(max_length=255)
    category = models.ForeignKey(CreditCategory, on_delete=models.PROTECT, related_name='credits')
    amount = models.FloatField()
    payment_method = models.CharField(max_length=50, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    date = models.DateTimeField(default=timezone.now)
    notes = models.TextField(blank=True, null=True)

    def __str__(self):
        return self.title


class Staff(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='staff_members', db_index=True)
    name = models.CharField(max_length=255)
    role = models.CharField(max_length=100, default='Washer')
    phone = models.CharField(max_length=20)
    email = models.EmailField(blank=True, default='')
    monthly_wage = models.FloatField(default=15000.0)
    status = models.CharField(max_length=20, default='ACTIVE')
    has_app_login = models.BooleanField(default=False)
    start_date = models.DateField(null=True, blank=True)

    class Meta:
        verbose_name_plural = 'Staff'

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        if self.email:
            try:
                from .auth import sync_staff_user
                sync_staff_user(self)
            except Exception:
                pass

    def __str__(self):
        return f"{self.name} ({self.role})"


class SalaryPayment(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='salary_payments', db_index=True)
    staff = models.ForeignKey(Staff, on_delete=models.CASCADE, related_name='salary_payments')
    month = models.DateField()
    amount = models.FloatField()
    paid_on = models.DateTimeField(default=timezone.now)
    method = models.CharField(max_length=50, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    note = models.TextField(blank=True, default='')
    expense = models.OneToOneField(
        Expense, null=True, blank=True, editable=False,
        on_delete=models.SET_NULL, related_name='salary_payment',
    )

    class Meta:
        ordering = ['-month', '-paid_on']

    @staticmethod
    def month_start(when):
        return when.replace(day=1)

    def save(self, *args, **kwargs):
        if not getattr(self, 'shop_id', None) and getattr(self, 'staff_id', None):
            self.shop = self.staff.shop
        elif not getattr(self, 'shop_id', None):
            self.shop = get_current_tenant() or Shop.objects.first()
        if self.month:
            self.month = self.month_start(self.month)
        super().save(*args, **kwargs)

        expense_fields = dict(
            shop=self.shop,
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


class SalaryAdvance(TenantModel):
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='salary_advances', db_index=True)
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
        if not getattr(self, 'shop_id', None) and getattr(self, 'staff_id', None):
            self.shop = self.staff.shop
        elif not getattr(self, 'shop_id', None):
            self.shop = get_current_tenant() or Shop.objects.first()
        if self.month:
            self.month = self.month_start(self.month)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.staff.name} advance {self.month:%b %Y} ₹{self.amount}"


class Attendance(TenantModel):
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

    DAY_VALUE = {
        PRESENT: 1.0,
        HALF_DAY: 0.5,
        ABSENT: 0.0,
        LEAVE: 0.0,
    }

    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='attendance_records', db_index=True)
    staff = models.ForeignKey(Staff, on_delete=models.CASCADE, related_name='attendance')
    date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=PRESENT)
    check_in_time = models.TimeField(null=True, blank=True)
    notes = models.CharField(max_length=255, blank=True, default='')

    class Meta:
        unique_together = ('staff', 'date')

    def save(self, *args, **kwargs):
        if not getattr(self, 'shop_id', None) and getattr(self, 'staff_id', None):
            self.shop = self.staff.shop
        elif not getattr(self, 'shop_id', None):
            self.shop = get_current_tenant() or Shop.objects.first()
        super().save(*args, **kwargs)

    @property
    def day_value(self):
        return self.DAY_VALUE.get(self.status, 0.0)

    def __str__(self):
        return f"{self.staff.name} {self.date} {self.status}"


class Lead(TenantModel):
    SOURCE_CHAT = 'chat'

    PENDING = 'PENDING'
    SENT = 'SENT'
    FAILED = 'FAILED'
    EMAIL_STATUS_CHOICES = [(PENDING, 'Pending'), (SENT, 'Sent'), (FAILED, 'Failed')]
    MAX_EMAIL_ATTEMPTS = 5

    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='leads', null=True, blank=True, db_index=True)
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


class EmailLinkRequest(TenantModel):
    PENDING = 'PENDING'
    APPROVED = 'APPROVED'
    REJECTED = 'REJECTED'
    STATUS_CHOICES = [(PENDING, 'Pending'), (APPROVED, 'Approved'), (REJECTED, 'Rejected')]

    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='link_requests', null=True, blank=True, db_index=True)
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='link_requests')
    email = models.EmailField()
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default=PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not getattr(self, 'shop_id', None) and getattr(self, 'customer_id', None):
            self.shop = self.customer.shop
        elif not getattr(self, 'shop_id', None):
            self.shop = get_current_tenant() or Shop.objects.first()
        super().save(*args, **kwargs)

    def approve(self):
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
    user_access_token = models.CharField(max_length=512, blank=True, default='')
    app_id = models.CharField(max_length=120, blank=True, default='')
    app_secret = models.CharField(max_length=120, blank=True, default='')
    business_id = models.CharField(max_length=120, blank=True, default='')
    facebook_page_id = models.CharField(max_length=120, blank=True, default='')
    facebook_page_name = models.CharField(max_length=255, blank=True, default='WashNLaundry Official')
    facebook_followers = models.IntegerField(default=0)
    instagram_account_id = models.CharField(max_length=120, blank=True, default='')
    instagram_username = models.CharField(max_length=120, blank=True, default='washnlaundry')
    instagram_followers = models.IntegerField(default=0)
    instagram_media_count = models.IntegerField(default=0)
    profile_picture_url = models.TextField(blank=True, default='')
    whatsapp_phone_number_id = models.CharField(max_length=120, blank=True, default='')
    whatsapp_business_account_id = models.CharField(max_length=120, blank=True, default='')
    whatsapp_phone_number = models.CharField(max_length=30, blank=True, default='')
    auto_reply_enabled = models.BooleanField(default=True)
    is_connected = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"MetaSettings for {self.facebook_page_name} ({'Connected' if self.is_connected else 'Disconnected'})"


class MetaPlatform(models.TextChoices):
    FACEBOOK = 'FACEBOOK', 'Facebook'
    INSTAGRAM = 'INSTAGRAM', 'Instagram'
    WHATSAPP = 'WHATSAPP', 'WhatsApp'
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
    image_url = models.TextField(blank=True, default='')
    permalink = models.URLField(max_length=500, blank=True, default='')
    media_type = models.CharField(max_length=30, blank=True, default='')
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

