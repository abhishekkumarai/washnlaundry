from datetime import timedelta

from django.db.models import Sum
from rest_framework import serializers

from .models import (
    Shop, Customer, GarmentCategory, GarmentItem, Order, OrderItem, OrderAuditLog,
    OrderStatus, Expense, Credit, CreditCategory, Staff, Attendance, SalaryPayment, SalaryAdvance,
    ServiceArea, TimeSlot, MetaSettings, MetaPost, MetaMessage, MetaLead, OrderMedia,
)
from .validators import validate_mobile_10_digit


class TenantModelSerializer(serializers.ModelSerializer):
    """Base ModelSerializer for tenant-scoped models ensuring `shop` is read-only."""
    def get_fields(self):
        fields = super().get_fields()
        if 'shop' in fields:
            fields['shop'].read_only = True
        return fields


class ShopSerializer(serializers.ModelSerializer):
    class Meta:
        model = Shop
        fields = '__all__'


class CustomerSerializer(TenantModelSerializer):
    avg_order_value = serializers.FloatField(read_only=True)
    delivered_due_amount = serializers.FloatField(read_only=True)
    has_app_login = serializers.SerializerMethodField()

    def get_has_app_login(self, obj):
        """True when the owner has issued this customer a sign-in (shop membership)."""
        email = (obj.email or '').strip()
        if not email or not obj.shop_id:
            return False
        from .models import ShopMembership, ShopRole
        return ShopMembership.objects.filter(
            user__username__iexact=email, shop_id=obj.shop_id,
            role=ShopRole.CUSTOMER, is_active=True).exists()

    class Meta:
        model = Customer
        fields = '__all__'

    def validate_phone(self, value):
        return validate_mobile_10_digit(value)


class GarmentItemSerializer(TenantModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)
    unit_label = serializers.CharField(source='get_unit_display', read_only=True)

    class Meta:
        model = GarmentItem
        fields = '__all__'


class GarmentCategorySerializer(TenantModelSerializer):
    items = GarmentItemSerializer(many=True, read_only=True)
    item_count = serializers.IntegerField(read_only=True)
    price_range = serializers.DictField(read_only=True)

    class Meta:
        model = GarmentCategory
        fields = '__all__'


class OrderItemSerializer(TenantModelSerializer):
    class Meta:
        model = OrderItem
        fields = '__all__'
        extra_kwargs = {'order': {'required': False}}


class OrderAuditLogSerializer(TenantModelSerializer):
    class Meta:
        model = OrderAuditLog
        fields = ['id', 'status', 'title', 'detail', 'created_at']


class OrderMediaSerializer(TenantModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model = OrderMedia
        fields = ['id', 'kind', 'content_type', 'original_name', 'size', 'status', 'url', 'created_at']
        read_only_fields = fields

    def get_url(self, obj):
        if obj.status != OrderMedia.READY:
            return None
        from .media_storage import get_storage
        return get_storage().read_url(obj, self.context.get('request'))


class OrderSerializer(TenantModelSerializer):
    items = OrderItemSerializer(many=True)
    audit_log = OrderAuditLogSerializer(many=True, read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    assigned_agent_name = serializers.CharField(source='assigned_agent.name', read_only=True, default=None)
    media = OrderMediaSerializer(many=True, read_only=True)
    # Ids of uploaded (READY, unattached) photos/videos to attach to this order.
    media_ids = serializers.ListField(child=serializers.UUIDField(), write_only=True, required=False)

    class Meta:
        model = Order
        fields = '__all__'
        read_only_fields = ['order_number', 'shop']

    def validate_media_ids(self, ids):
        from .media_storage import MAX_FILES_PER_ORDER, MAX_VIDEOS_PER_ORDER
        ids = list(dict.fromkeys(ids))
        found = list(OrderMedia.objects.filter(
            id__in=ids, status=OrderMedia.READY, order__isnull=True))
        if len(found) != len(ids):
            raise serializers.ValidationError('Some photos or videos are missing or already used. Re-add them.')
        existing = self.instance.media.all() if self.instance is not None else []
        total = len(found) + len(existing)
        videos = sum(1 for m in [*found, *existing] if m.kind == 'VIDEO')
        if total > MAX_FILES_PER_ORDER:
            raise serializers.ValidationError(f'At most {MAX_FILES_PER_ORDER} photos/videos per order.')
        if videos > MAX_VIDEOS_PER_ORDER:
            raise serializers.ValidationError(f'At most {MAX_VIDEOS_PER_ORDER} videos per order.')
        return ids

    @staticmethod
    def _attach_media(order, ids):
        if ids:
            OrderMedia.objects.filter(
                id__in=ids, status=OrderMedia.READY, order__isnull=True).update(order=order)

    def validate_customer_phone(self, value):
        if value:
            return validate_mobile_10_digit(value)
        return value

    def create(self, validated_data):
        """Accept nested items on POST, and log the opening audit entry."""
        from django.utils import timezone

        items_data = validated_data.pop('items', [])
        media_ids = validated_data.pop('media_ids', [])
        user = getattr(self.context.get('request'), 'user', None)
        if getattr(user, 'role', None) == 'customer' and getattr(user, 'customer', None):
            # A customer orders for themselves: no delivery charge, no discount,
            # nothing prepaid, and totals come from the items, not the client.
            c = user.customer
            validated_data.update(
                customer=c, customer_name=c.name, customer_phone=c.phone,
                delivery_charge=0.0, discount_amount=0.0, paid_amount=0.0,
                subtotal=0.0, total_amount=0.0)
        order = Order(**validated_data)
        if not order.placed_at:
            order.placed_at = timezone.now()
        order.save()
        order.audit_log.create(
            status=OrderStatus.PLACED, title=OrderStatus.PLACED.label, created_at=order.placed_at,
        )

        subtotal = 0.0
        for item_data in items_data:
            item_data.pop('order', None)
            total = item_data.get('total_price') or (
                item_data.get('quantity', 1) * item_data.get('unit_price', 0.0)
            )
            item_data['total_price'] = total
            subtotal += total
            OrderItem.objects.create(order=order, **item_data)

        # Trust the client's totals if it sent them, otherwise derive.
        if not order.subtotal:
            order.subtotal = subtotal
        if not order.total_amount:
            order.total_amount = order.subtotal + order.delivery_charge - order.discount_amount
        order.due_amount = max(order.total_amount - order.paid_amount, 0.0)
        order.save()
        self._attach_media(order, media_ids)
        return order

    def update(self, instance, validated_data):
        validated_data.pop('items', None)
        media_ids = validated_data.pop('media_ids', [])
        order = super().update(instance, validated_data)
        self._attach_media(order, media_ids)
        return order


class ExpenseSerializer(TenantModelSerializer):
    class Meta:
        model = Expense
        fields = '__all__'


class CreditCategorySerializer(TenantModelSerializer):
    credit_count = serializers.IntegerField(source='credits.count', read_only=True)
    is_default = serializers.SerializerMethodField()

    class Meta:
        model = CreditCategory
        fields = ['id', 'name', 'display_order', 'is_active', 'credit_count', 'is_default']

    def get_is_default(self, obj):
        from .models import DEFAULT_CREDIT_CATEGORIES
        return obj.name in DEFAULT_CREDIT_CATEGORIES

    def validate_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Name cannot be blank.')
        clash = CreditCategory.objects.filter(name__iexact=value)
        if self.instance:
            clash = clash.exclude(pk=self.instance.pk)
        if clash.exists():
            raise serializers.ValidationError(f'A category named "{value}" already exists.')
        return value


class CreditSerializer(TenantModelSerializer):
    # Read and written as the category's name, so the API shape stayed a plain
    # string when categories moved from fixed choices into their own table —
    # and a rename in Settings shows on every existing credit.
    category = serializers.SlugRelatedField(
        slug_field='name', queryset=CreditCategory.objects.all())

    class Meta:
        model = Credit
        fields = '__all__'

    def validate_category(self, value):
        # A turned-off category stays on the credits already filed under it,
        # but can't be picked for a new credit or switched to on an edit.
        unchanged = self.instance is not None and self.instance.category_id == value.pk
        if not value.is_active and not unchanged:
            raise serializers.ValidationError(
                f'"{value.name}" is turned off. Turn it on in Settings → Credit categories first.')
        return value


class StaffSerializer(TenantModelSerializer):
    class Meta:
        model = Staff
        fields = '__all__'

    def validate_phone(self, value):
        return validate_mobile_10_digit(value)

    def validate_start_date(self, value):
        # Only matters on an edit (self.instance exists) — a brand-new Staff
        # row can't have attendance yet, so there's nothing to conflict with.
        if value and self.instance and self.instance.attendance.filter(date__lt=value).exists():
            raise serializers.ValidationError(
                'This staff member already has attendance recorded before this date. '
                'Fix or remove those records first.'
            )
        return value


class AttendanceSerializer(TenantModelSerializer):
    staff_name = serializers.CharField(source='staff.name', read_only=True)

    class Meta:
        model = Attendance
        fields = '__all__'

    def validate(self, attrs):
        staff = attrs.get('staff') or getattr(self.instance, 'staff', None)
        date = attrs.get('date') or getattr(self.instance, 'date', None)
        if staff and date and staff.start_date and date < staff.start_date:
            raise serializers.ValidationError(
                f"Cannot mark attendance for {staff.name} before their start date "
                f"({staff.start_date})."
            )
        return attrs


class SalaryPaymentSerializer(TenantModelSerializer):
    staff_name = serializers.CharField(source='staff.name', read_only=True)

    class Meta:
        model = SalaryPayment
        fields = '__all__'

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError('amount must be greater than zero.')
        return value

    def validate(self, attrs):
        # Mirrors payroll_summary's own total_salary/pending_amount formula
        # (views.py) so this can't be bypassed by calling the API directly
        # even though the Payroll screen's dialog already caps the amount
        # against `pendingAmount` client-side.
        staff = attrs.get('staff') or getattr(self.instance, 'staff', None)
        month = attrs.get('month') or getattr(self.instance, 'month', None)
        amount = attrs.get('amount', getattr(self.instance, 'amount', None))
        if not (staff and month and amount is not None):
            return attrs

        month = SalaryPayment.month_start(month)
        next_month = (month + timedelta(days=32)).replace(day=1)
        days_in_month = (next_month - month).days
        days_worked = sum(
            a.day_value for a in
            Attendance.objects.filter(staff=staff, date__gte=month, date__lt=next_month)
        )
        daily_rate = staff.monthly_wage / days_in_month
        total_salary = round(days_worked * daily_rate, 2)
        advances = SalaryAdvance.objects.filter(staff=staff, month=month) \
            .aggregate(total=Sum('amount'))['total'] or 0.0
        net_pay = round(max(total_salary - advances, 0.0), 2)

        other_payments = SalaryPayment.objects.filter(staff=staff, month=month)
        if self.instance:
            other_payments = other_payments.exclude(pk=self.instance.pk)
        already_paid = other_payments.aggregate(total=Sum('amount'))['total'] or 0.0

        # Pay owed is derived from attendance only. When nothing was earned
        # (no attendance marked, or advances cover it) there is no amount to
        # cap against, so the payment is accepted rather than blocked at 0.
        if net_pay > 0 and round(already_paid + amount, 2) > net_pay:
            remaining = round(max(net_pay - already_paid, 0.0), 2)
            raise serializers.ValidationError(
                f"This payment would exceed what {staff.name} is owed for "
                f"{month:%B %Y} ({remaining} remaining)."
            )
        return attrs


class SalaryAdvanceSerializer(TenantModelSerializer):
    staff_name = serializers.CharField(source='staff.name', read_only=True)

    class Meta:
        model = SalaryAdvance
        fields = '__all__'

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError('amount must be greater than zero.')
        return value


class ServiceAreaSerializer(TenantModelSerializer):
    class Meta:
        model = ServiceArea
        fields = '__all__'


class TimeSlotSerializer(TenantModelSerializer):
    label = serializers.CharField(source='__str__', read_only=True)

    class Meta:
        model = TimeSlot
        fields = '__all__'


# ── Meta & Social Suite Serializers ──────────────────────────────────────────

class MetaSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = MetaSettings
        fields = [
            'id', 'shop', 'page_access_token', 'user_access_token', 'app_id', 'app_secret', 'business_id',
            'facebook_page_id', 'facebook_page_name', 'facebook_followers',
            'instagram_account_id', 'instagram_username', 'instagram_followers', 'instagram_media_count',
            'whatsapp_phone_number_id', 'whatsapp_business_account_id', 'whatsapp_phone_number',
            'profile_picture_url', 'auto_reply_enabled', 'is_connected', 'updated_at'
        ]


class MetaPostSerializer(serializers.ModelSerializer):
    class Meta:
        model = MetaPost
        fields = '__all__'


class MetaMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = MetaMessage
        fields = '__all__'


class MetaLeadSerializer(serializers.ModelSerializer):
    converted_order_number = serializers.CharField(source='converted_order.order_number', read_only=True)

    class Meta:
        model = MetaLead
        fields = '__all__'

    def validate_customer_phone(self, value):
        if value:
            return validate_mobile_10_digit(value)
        return value

