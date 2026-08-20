from rest_framework import serializers

from .models import (
    Shop, Customer, GarmentCategory, GarmentItem, Order, OrderItem, OrderAuditLog,
    OrderStatus, Expense, Staff, Attendance, SalaryPayment, ServiceArea, TimeSlot,
)


class ShopSerializer(serializers.ModelSerializer):
    class Meta:
        model = Shop
        fields = '__all__'


class CustomerSerializer(serializers.ModelSerializer):
    avg_order_value = serializers.FloatField(read_only=True)

    class Meta:
        model = Customer
        fields = '__all__'


class GarmentItemSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)
    unit_label = serializers.CharField(source='get_unit_display', read_only=True)

    class Meta:
        model = GarmentItem
        fields = '__all__'


class GarmentCategorySerializer(serializers.ModelSerializer):
    items = GarmentItemSerializer(many=True, read_only=True)
    item_count = serializers.IntegerField(read_only=True)
    price_range = serializers.DictField(read_only=True)

    class Meta:
        model = GarmentCategory
        fields = '__all__'


class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = '__all__'
        extra_kwargs = {'order': {'required': False}}


class OrderAuditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderAuditLog
        fields = ['id', 'status', 'title', 'detail', 'created_at']


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True)
    audit_log = OrderAuditLogSerializer(many=True, read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    assigned_agent_name = serializers.CharField(source='assigned_agent.name', read_only=True, default=None)

    class Meta:
        model = Order
        fields = '__all__'
        read_only_fields = ['order_number']

    def create(self, validated_data):
        """Accept nested items on POST, and log the opening audit entry."""
        from django.utils import timezone

        items_data = validated_data.pop('items', [])
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
        return order

    def update(self, instance, validated_data):
        validated_data.pop('items', None)
        return super().update(instance, validated_data)


class ExpenseSerializer(serializers.ModelSerializer):
    class Meta:
        model = Expense
        fields = '__all__'


class StaffSerializer(serializers.ModelSerializer):
    class Meta:
        model = Staff
        fields = '__all__'


class AttendanceSerializer(serializers.ModelSerializer):
    staff_name = serializers.CharField(source='staff.name', read_only=True)

    class Meta:
        model = Attendance
        fields = '__all__'


class SalaryPaymentSerializer(serializers.ModelSerializer):
    staff_name = serializers.CharField(source='staff.name', read_only=True)

    class Meta:
        model = SalaryPayment
        fields = '__all__'

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError('amount must be greater than zero.')
        return value


class ServiceAreaSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceArea
        fields = '__all__'


class TimeSlotSerializer(serializers.ModelSerializer):
    label = serializers.CharField(source='__str__', read_only=True)

    class Meta:
        model = TimeSlot
        fields = '__all__'
