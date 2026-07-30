"""Seed the database with data mirroring the live app.laundrybill.com account.

The 79-item catalogue below was captured from the live app on 2026-07-30; the
per-category counts and price ranges match it exactly. See LIVE_AUDIT.md.

WARNING: this wipes every table before seeding.
"""

import os
import random
from datetime import datetime, time, timedelta

import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'laundry_backend.settings')
django.setup()

from django.utils import timezone  # noqa: E402

from api.models import (  # noqa: E402
    Shop, Customer, GarmentCategory, GarmentItem, Order, OrderItem,
    Expense, Staff, Attendance, ServiceArea, TimeSlot,
    OrderStatus, PaymentStatus, DeliveryType, OrderSource, PricingUnit,
)

PC, KG, SQFT, SET = PricingUnit.PIECE, PricingUnit.KG, PricingUnit.SQFT, PricingUnit.SET

# (category, [(name, price, unit), ...])
CATALOGUE = [
    ('Ironing', 'Iron', [
        ('Shirt', 15, PC), ('T-Shirt', 12, PC), ('Kurta', 20, PC),
        ('Suit (2 piece)', 100, PC), ('Pant', 18, PC), ('Jeans', 20, PC),
        ('Shorts', 12, PC), ('Top / Kurti', 15, PC), ('Blouse', 12, PC),
        ('Dress', 25, PC), ('Leggings', 12, PC), ('Salwar', 15, PC),
        ('Skirt', 15, PC), ('Saree (Cotton)', 30, PC), ('Saree (Silk)', 50, PC),
        ('Dupatta', 12, PC), ('Bedsheet (Single)', 25, PC), ('Bedsheet (Double)', 35, PC),
        ('Pillow Cover', 10, PC), ('Shirt/T-Shirt', 10, PC), ('Trouser/Shorts', 12, PC),
        ('Frock', 15, PC), ('School Uniform', 10, PC),
    ]),
    ('Wash & Fold', 'Laundry', [
        ('Regular Cloths (Per Kg)', 85, KG),
        ('Household item', 125, PC),
        ('Heavy bedshoots', 185, PC),
    ]),
    ('Wash & Iron', 'WashIron', [
        ('Shirt (Cotton)', 40, PC), ('Shirt (Silk/Linen)', 60, PC), ('T-Shirt/Polo', 35, PC),
        ('Trouser/Jeans', 50, PC), ('Kurta', 55, PC), ('Top / Kurti', 40, PC),
        ('Salwar/Leggings', 40, PC), ('Salwar Kameez Set', 80, PC), ('Saree (Cotton)', 80, PC),
        ('Saree (Silk)', 140, PC), ('Bedsheet (Single)', 70, PC), ('Bedsheet (Double)', 95, PC),
        ('Pillow Cover', 28, PC), ('Shirt/Top', 28, PC), ('Trouser/Jeans', 35, PC),
        ('Frock/Dress', 42, PC), ('School Uniform', 25, PC),
    ]),
    ('Dry Cleaning', 'Sparkles', [
        ('Suit (2 piece)', 250, PC), ('Suit (3 piece)', 350, PC), ('Blazer/Jacket', 150, PC),
        ('Overcoat (Wool)', 240, PC), ('Leather Jacket', 400, PC), ('Sherwani', 350, PC),
        ('Saree (Silk)', 250, PC), ('Saree (Heavy work)', 400, PC), ('Lehenga (Bridal)', 700, PC),
        ('Kurta (Silk)', 150, PC), ('Shirt (Silk/Premium)', 100, PC), ('Trouser (Wool)', 90, PC),
        ('Dress / Gown', 200, PC), ('Blanket (Double)', 300, PC), ('Comforter', 400, PC),
        ('Curtains (Panel)', 180, PC), ('Party Dress', 140, PC), ('Lehenga/Sherwani', 180, PC),
        ('Winter Jacket', 90, PC),
    ]),
    ('Household', 'Home', [
        ('Blanket (Wash)', 200, PC), ('Comforter (Wash)', 280, PC), ('Curtains (Wash)', 80, PC),
        ('Carpet (Vacuum)', 15, SQFT), ('Sofa Cleaning', 200, SET),
    ]),
    ('Shoe Cleaning', 'Shoe', [
        ('Sports Shoes', 200, PC), ('Sneakers', 250, PC), ('Leather Shoes', 300, PC),
        ('Boots', 350, PC), ('Sandals', 100, PC), ('Suede Shoes', 350, PC),
        ('Heels/Boots', 250, PC),
    ]),
    ('Premium', 'Star', [
        ('Designer Handbag', 500, PC), ('Leather Bag Cleaning', 300, PC),
        ('Travel Bag/Suitcase', 400, PC), ('Soft Toy Cleaning', 100, PC),
        ('Stroller/Pram', 600, PC),
    ]),
]

DEFAULT_SLOTS = [
    (time(9, 0), time(11, 0)),
    (time(11, 0), time(13, 0)),
    (time(14, 0), time(16, 0)),
    (time(16, 0), time(18, 0)),
]


def seed():
    print('Clearing old data...')
    OrderItem.objects.all().delete()
    Order.objects.all().delete()
    Customer.objects.all().delete()
    GarmentItem.objects.all().delete()
    GarmentCategory.objects.all().delete()
    Expense.objects.all().delete()
    Attendance.objects.all().delete()
    Staff.objects.all().delete()
    TimeSlot.objects.all().delete()
    ServiceArea.objects.all().delete()
    Shop.objects.all().delete()

    print('Seeding Shop...')
    Shop.objects.create(
        name='washing',
        owner_name='AK',
        phone='+91 98765 43210',
        whatsapp='+91 98765 43210',
        email='hello@washing.example',
        address='Hbr layout, Bengaluru',
        city='Bengaluru',
        state='Karnataka',
        pin_code='560064',
        gstin='29AAACL1234F1Z9',
        pan='AAACL1234F',
        tax_rate=5.0,
        account_holder_name='AK',
        bank_name='HDFC Bank',
        ifsc_code='HDFC0001234',
        upi_id='washing@upi',
    )

    print('Seeding Categories & Items...')
    categories = {}
    total_items = 0
    for order_index, (cat_name, icon, items) in enumerate(CATALOGUE, start=1):
        category = GarmentCategory.objects.create(
            name=cat_name, icon=icon, display_order=order_index
        )
        categories[cat_name] = category
        for item_index, (name, price, unit) in enumerate(items, start=1):
            GarmentItem.objects.create(
                category=category, name=name, price=float(price), unit=unit,
                turnaround_days=1, display_order=item_index,
            )
            total_items += 1

    print('Seeding Service Areas & Time Slots...')
    for area in ['HBR Layout', 'Kalyan Nagar', 'Banaswadi', 'Hennur']:
        ServiceArea.objects.create(name=area, pin_code='560043')
    for kind in (TimeSlot.PICKUP, TimeSlot.DELIVERY):
        for start, end in DEFAULT_SLOTS:
            TimeSlot.objects.create(kind=kind, start_time=start, end_time=end, capacity=None)

    print('Seeding Customers...')
    customers_data = [
        ('Aditya Sharma', '9876543210', 'aditya@gmail.com', 'Hbr Layout, Bengaluru', 'HBR Layout', 12, 4850.0, 0.0),
        ('Rohan Verma', '9811223344', 'rohan@gmail.com', 'Koramangala, Bengaluru', 'Koramangala', 8, 3200.0, 350.0),
        ('Priya Sundaram', '9871100223', 'priya@outlook.com', 'Indiranagar, Bengaluru', 'Indiranagar', 5, 1980.0, 0.0),
        ('Meena Iyer', '9845512233', 'meena.iyer@gmail.com', 'Whitefield, Bengaluru', 'Whitefield', 3, 750.0, 200.0),
        ('Karthik Reddy', '9900112233', 'karthik.r@gmail.com', 'HSR Layout, Bengaluru', 'HSR Layout', 7, 2650.0, 0.0),
        ('Anjali Singh', '9988776655', 'anjali.s@yahoo.com', 'Jayanagar, Bengaluru', 'Jayanagar', 2, 480.0, 0.0),
        ('Suresh Babu', '9123456789', 'suresh.b@gmail.com', 'Rajajinagar, Bengaluru', 'Rajajinagar', 9, 3900.0, 600.0),
        ('Deepa Nair', '9654321098', 'deepa.n@gmail.com', 'Malleswaram, Bengaluru', 'Malleswaram', 4, 1240.0, 0.0),
        ('Vikram Patel', '9876001234', 'vikram.p@hotmail.com', 'Yelahanka, Bengaluru', 'Yelahanka', 6, 2100.0, 150.0),
        ('Lakshmi Krishnan', '9800998877', 'lakshmi.k@gmail.com', 'Basavanagudi, Bengaluru', 'Basavanagudi', 11, 5200.0, 0.0),
    ]
    customers = [
        Customer.objects.create(
            name=name, phone=phone, email=email, address=addr, area=area,
            total_orders=orders, total_spent=spent, due_amount=due,
        )
        for name, phone, email, addr, area, orders, spent, due in customers_data
    ]

    print('Seeding Staff...')
    # (name, role, phone, daily wage, delivery agent, has app login)
    staff_data = [
        ('Ramesh Kumar', 'Head Washer', '9711223344', 650.0, False, True),
        ('Sunil Paswan', 'Steam Press', '9811445566', 600.0, False, False),
        ('Geeta Devi', 'Dry Cleaning', '9922334455', 700.0, False, False),
        ('Mohan Das', 'Delivery Driver', '9933441122', 580.0, True, True),
        ('Lakshman Rao', 'Manager', '9944556677', 900.0, False, True),
        ('Anita Sharma', 'Ironing Specialist', '9955667788', 620.0, False, False),
    ]
    staff_objs = [
        Staff.objects.create(
            name=name, role=role, phone=phone, daily_wage=wage,
            is_delivery_agent=is_agent, has_app_login=app_login,
        )
        for name, role, phone, wage, is_agent, app_login in staff_data
    ]
    drivers = [s for s in staff_objs if s.is_delivery_agent]

    print('Seeding Orders...')
    today = timezone.localdate()
    now = timezone.now()
    all_items = list(GarmentItem.objects.select_related('category').all())

    # (customer, status, payment_status, method, delivery_type, express, scheduled offset in days)
    orders_plan = [
        (0, OrderStatus.PROCESSING, PaymentStatus.PAID, 'UPI', DeliveryType.HOME_DELIVERY, False, 2),
        (1, OrderStatus.PLACED, PaymentStatus.PARTIAL, 'CASH', DeliveryType.HOME_PICKUP, True, 1),
        (2, OrderStatus.READY, PaymentStatus.PAID, 'UPI', DeliveryType.STORE_PICKUP, False, 0),
        (3, OrderStatus.DELIVERED, PaymentStatus.PAID, 'CARD', DeliveryType.STORE_PICKUP, False, -2),
        (4, OrderStatus.OUT_FOR_DELIVERY, PaymentStatus.PAID, 'UPI', DeliveryType.HOME_DELIVERY, False, 0),
        (5, OrderStatus.PLACED, PaymentStatus.UNPAID, 'CASH', DeliveryType.STORE_PICKUP, False, -1),
        (6, OrderStatus.IRONING, PaymentStatus.PARTIAL, 'UPI', DeliveryType.HOME_DELIVERY, True, 1),
        (7, OrderStatus.READY, PaymentStatus.PAID, 'UPI', DeliveryType.STORE_PICKUP, False, 0),
        (8, OrderStatus.PROCESSING, PaymentStatus.PARTIAL, 'CASH', DeliveryType.HOME_PICKUP, False, 3),
        (9, OrderStatus.DELIVERED, PaymentStatus.PAID, 'BANK_TRANSFER', DeliveryType.ONLINE, False, -3),
        (0, OrderStatus.CANCELLED, PaymentStatus.UNPAID, 'CASH', DeliveryType.STORE_PICKUP, False, -4),
        (2, OrderStatus.PROCESSING, PaymentStatus.PAID, 'UPI', DeliveryType.HOME_DELIVERY, True, 2),
        (4, OrderStatus.READY, PaymentStatus.PAID, 'CARD', DeliveryType.STORE_PICKUP, False, 0),
        (6, OrderStatus.DELIVERED, PaymentStatus.PAID, 'UPI', DeliveryType.ONLINE, False, -5),
        (1, OrderStatus.PLACED, PaymentStatus.PARTIAL, 'CASH', DeliveryType.HOME_DELIVERY, False, -1),
    ]

    # Which timeline stamps exist by the time an order reaches a given status.
    progression = [
        OrderStatus.PLACED, OrderStatus.PROCESSING, OrderStatus.IRONING,
        OrderStatus.READY, OrderStatus.OUT_FOR_DELIVERY, OrderStatus.DELIVERED,
    ]

    for idx, (cust_i, status, pay_status, method, delivery_type, express, sched_offset) in enumerate(orders_plan):
        customer = customers[cust_i]
        placed_at = now - timedelta(days=abs(sched_offset) + 1, hours=idx % 8)

        order = Order(
            customer=customer,
            customer_name=customer.name,
            customer_phone=customer.phone,
            status=status,
            payment_status=pay_status,
            payment_method=method,
            delivery_type=delivery_type,
            source=random.choice(OrderSource.values),
            express=express,
            scheduled_date=today + timedelta(days=sched_offset),
            placed_at=placed_at,
        )
        if delivery_type in (DeliveryType.HOME_DELIVERY, DeliveryType.ONLINE):
            order.delivery_charge = 50.0
            if drivers and status in (OrderStatus.OUT_FOR_DELIVERY, OrderStatus.DELIVERED):
                order.assigned_agent = drivers[0]

        # Stamp every stage up to the current one.
        if status == OrderStatus.CANCELLED:
            order.cancelled_at = placed_at + timedelta(hours=2)
        else:
            reached = progression[: progression.index(status) + 1]
            for step, stage in enumerate(reached):
                field = Order.STATUS_TIMESTAMP_FIELD[stage]
                setattr(order, field, placed_at + timedelta(minutes=step * 45))
        order.save()

        chosen = random.sample(all_items, random.randint(2, 4))
        subtotal = 0.0
        for garment in chosen:
            qty = random.randint(1, 3)
            line_total = qty * garment.price
            subtotal += line_total
            OrderItem.objects.create(
                order=order,
                item=garment,
                item_title=garment.name,
                service_type=garment.category.name,
                status=status,
                quantity=qty,
                unit=garment.unit,
                unit_price=garment.price,
                total_price=line_total,
            )

        order.subtotal = subtotal
        order.total_amount = subtotal + order.delivery_charge
        if pay_status == PaymentStatus.PAID:
            order.paid_amount = order.total_amount
        elif pay_status == PaymentStatus.PARTIAL:
            order.paid_amount = round(order.total_amount / 2, 2)
        else:
            order.paid_amount = 0.0
        order.due_amount = round(order.total_amount - order.paid_amount, 2)
        order.save()

    print('Seeding Attendance...')
    for days_ago in range(7):
        date = today - timedelta(days=days_ago)
        for staff in staff_objs:
            roll = random.random()
            status = Attendance.PRESENT if roll > 0.15 else (
                Attendance.LEAVE if roll > 0.08 else Attendance.ABSENT
            )
            Attendance.objects.create(staff=staff, date=date, status=status)

    print('Seeding Expenses...')
    expenses_data = [
        ('Commercial Detergent & Liquid Soap (50L)', 'Supplies', 3500.0, 'UPI'),
        ('Monthly Shop Rent (July)', 'Rent', 28000.0, 'BANK_TRANSFER'),
        ('Electricity Bill - July', 'Utilities', 4200.0, 'BANK_TRANSFER'),
        ('Steam Press Machine Servicing', 'Maintenance', 1800.0, 'CASH'),
        ('Packaging Bags & Hangers', 'Supplies', 650.0, 'CASH'),
        ('Water Bill - July', 'Utilities', 900.0, 'CASH'),
        ('Staff Salary Advance - Ramesh', 'Salary', 5000.0, 'CASH'),
        ('Diesel for Delivery Van', 'Transport', 2200.0, 'CASH'),
    ]
    for title, cat, amount, method in expenses_data:
        Expense.objects.create(title=title, category=cat, amount=amount, payment_method=method)

    print('\n[SUCCESS] Database seeded.')
    print(f'   - {len(customers_data)} customers')
    print(f'   - {len(orders_plan)} orders')
    print(f'   - {len(staff_data)} staff')
    print(f'   - {len(expenses_data)} expenses')
    print(f'   - {total_items} items across {len(CATALOGUE)} categories')
    print(f'   - {ServiceArea.objects.count()} service areas, {TimeSlot.objects.count()} time slots')


if __name__ == '__main__':
    seed()
