import re
from django.utils import timezone


def format_currency(amount, symbol='₹'):
    """Format float amount nicely into currency string, e.g. ₹250.00"""
    return f"{symbol}{float(amount):,.2f}"


def build_order_receipt_message(order):
    """
    Generate professional WhatsApp receipt for an Order.
    Includes shop branding, customer name, itemized bill, total, dues, and live tracking URL.
    """
    shop = getattr(order, 'shop', None)
    if not shop:
        from api.models import Shop
        shop = Shop.objects.first()

    shop_name = shop.name if shop else "Wash & Laundry"
    curr = shop.currency_symbol if shop else "₹"

    customer_name = order.customer_name or "Valued Customer"
    order_num = order.order_number or str(order.id)[:8]
    date_str = order.created_at.strftime("%d %b %Y, %I:%M %p") if order.created_at else timezone.now().strftime("%d %b %Y")

    items = list(order.items.all())
    if items:
        item_lines = []
        for it in items:
            item_lines.append(
                f"• {it.quantity}x {it.item_title} ({it.service_type}) — {format_currency(it.total_price, curr)}"
            )
        items_block = "\n".join(item_lines)
    else:
        items_block = "• Laundry Services"

    delivery_line = ""
    if order.delivery_charge > 0:
        delivery_line = f"\nDelivery Charge: {format_currency(order.delivery_charge, curr)}"

    discount_line = ""
    if order.discount_amount > 0:
        discount_line = f"\nDiscount: -{format_currency(order.discount_amount, curr)}"

    tracking_url = f"https://app.laundrybill.com/track/{order_num}"

    msg = f"""🧺 *{shop_name.upper()}* — Order Receipt
━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hello *{customer_name}*, thank you for choosing us!

*Order #*: #{order_num}
*Date*: {date_str}
*Status*: {order.get_status_display() if hasattr(order, 'get_status_display') else order.status}

*Items Itemized*:
{items_block}
───────────────────────────
Subtotal: {format_currency(order.subtotal, curr)}{delivery_line}{discount_line}
*Total Amount*: *{format_currency(order.total_amount, curr)}*
Paid: {format_currency(order.paid_amount, curr)}
Due Balance: *{format_currency(order.due_amount, curr)}*
Payment: {order.payment_method.capitalize()} ({order.payment_status.upper()})

Track your order live:
🔗 {tracking_url}

_Have questions? Reply directly to this WhatsApp message._"""

    return msg.strip()


def build_order_status_message(order, note=''):
    """
    Generate customer notification for order status updates.
    (Placed -> Processing -> Ready -> Out for Delivery -> Delivered)
    """
    shop = getattr(order, 'shop', None)
    if not shop:
        from api.models import Shop
        shop = Shop.objects.first()

    shop_name = shop.name if shop else "Wash & Laundry"
    customer_name = order.customer_name or "Valued Customer"
    order_num = order.order_number or str(order.id)[:8]
    status = order.status

    status_meta = {
        'PLACED': ('📥 Order Confirmed', 'We have received your laundry order and queued it for processing.'),
        'PROCESSING': ('🧺 Washing & Cleaning in Progress', 'Your garments are currently being washed and treated with premium care.'),
        'IRONING': ('👔 Ironing & Pressing', 'Your clothes are being pressed to crisp perfection.'),
        'READY': ('✨ Ready for Pickup / Delivery', 'Your laundry is freshly cleaned, packed, and ready!'),
        'OUT_FOR_DELIVERY': ('🚚 Out for Delivery', 'Our delivery partner is on the way with your laundry package.'),
        'DELIVERED': ('✅ Delivered Successfully', 'Your laundry order has been delivered. Thank you for your business!'),
        'CANCELLED': ('❌ Order Cancelled', 'Your laundry order has been marked as cancelled.'),
    }

    title, default_instruction = status_meta.get(status, (f"Status: {status}", "Order status updated."))
    instruction = note.strip() if note and note.strip() else default_instruction

    tracking_url = f"https://app.laundrybill.com/track/{order_num}"

    msg = f"""🧺 *{shop_name.upper()}* — Order Update
━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hi *{customer_name}*,

*Order #{order_num}* update:
👉 *{title}*

{instruction}

View details & receipt:
🔗 {tracking_url}"""

    return msg.strip()


def build_payroll_slip_message(staff, month_str, days_worked=0, half_days=0, gross_wage=0.0, paid_amount=0.0, payment_method='Cash', note=''):
    """
    Generate WhatsApp salary slip notification for a staff member.
    """
    from api.models import Shop
    shop = Shop.objects.first()
    shop_name = shop.name if shop else "Wash & Laundry"
    curr = shop.currency_symbol if shop else "₹"

    note_line = f"\nNote: {note}" if note else ""

    msg = f"""💼 *{shop_name.upper()}* — Salary Slip
━━━━━━━━━━━━━━━━━━━━━━━━━━━
Employee: *{staff.name}* ({staff.role})
Period: *{month_str}*

Days Worked: {days_worked} Days {f'({half_days} Half Days)' if half_days else ''}
Monthly Base: {format_currency(staff.monthly_wage, curr)}
Gross Earned: {format_currency(gross_wage, curr)}
───────────────────────────
*Paid Amount*: *{format_currency(paid_amount, curr)}*
Payment Mode: {payment_method.capitalize()}{note_line}

Thank you for your hard work and dedication!"""

    return msg.strip()
