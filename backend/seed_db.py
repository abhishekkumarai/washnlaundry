"""Seed the database with data mirroring the live app.laundrybill.com account.

The 79-item catalogue below was captured from the live app on 2026-07-30; the
per-category counts and price ranges match it exactly. See LIVE_AUDIT.md.

WARNING: this wipes every table before seeding.
"""

import calendar
import os
import random
from datetime import datetime, time, timedelta

import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'laundry_backend.settings')
django.setup()

from django.utils import timezone  # noqa: E402

from api.models import (  # noqa: E402
    Shop, Customer, GarmentCategory, GarmentItem, Order, OrderItem, OrderAuditLog,
    Expense, Staff, Attendance, SalaryPayment, ServiceArea, TimeSlot,
    OrderStatus, PaymentStatus, DeliveryType, OrderSource, PricingUnit,
)

PC, KG, SQFT, SET = PricingUnit.PIECE, PricingUnit.KG, PricingUnit.SQFT, PricingUnit.SET

# Order provenance, as the live timeline writes it: a counter order names the
# person who rang it up, the other channels name themselves.
#
# Must cover every OrderSource value — the seed picks one at random, so a gap
# here is a KeyError that only shows up on some runs. It used to be missing
# STAFF_APP and AGENT_APP.
CREATED_BY = {
    OrderSource.WEB: 'AK',
    OrderSource.MOBILE_APP: 'Mobile App',
    OrderSource.PUBLIC_PAGE: 'Public Page',
    OrderSource.STAFF_APP: 'Staff App',
    OrderSource.AGENT_APP: 'Agent App',
}

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

# Demo product photography. Only the items we happen to have a picture for —
# the rest seed with an empty image_url and render the icon treatment, which
# is the same thing a real shop sees before it uploads its own.
_UNSPLASH = 'https://images.unsplash.com/photo-{}?w=300&h=300&fit=crop'
ITEM_IMAGES = {
    'Shirt': _UNSPLASH.format('1602810316493-c1e5e6a89dce'),
    'T-Shirt': _UNSPLASH.format('1527719327859-c6ce80353573'),
    'Kurta': _UNSPLASH.format('1594938291221-94f18cbb5660'),
    'Suit (2 piece)': _UNSPLASH.format('1507679799987-c73779587ccf'),
    'Pant': _UNSPLASH.format('1624378439575-d8705ad7ae80'),
    'Jeans': _UNSPLASH.format('1542272604-787c3835535d'),
    'Shorts': _UNSPLASH.format('1591195853828-11db59a44f43'),
    'Top / Kurti': _UNSPLASH.format('1610030469983-98e550d6193c'),
    'Saree (Silk)': _UNSPLASH.format('1610030469983-98e550d6193c'),
    'Sherwani': _UNSPLASH.format('1599643478518-a784e5dc4c8f'),
    'Lehenga (Bridal)': _UNSPLASH.format('1515372039744-b8f02a3ae446'),
    'Blazer/Jacket': _UNSPLASH.format('1507679799987-c73779587ccf'),
}


def seed():
    print('Clearing old data...')
    OrderItem.objects.all().delete()
    Order.objects.all().delete()
    Customer.objects.all().delete()
    GarmentItem.objects.all().delete()
    GarmentCategory.objects.all().delete()
    Expense.objects.all().delete()
    Attendance.objects.all().delete()
    SalaryPayment.objects.all().delete()
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
        # Operating rules that used to be Dart constants in the client.
        express_multiplier=1.5,
        default_monthly_wage=18000.0,
        default_staff_role='Washer',
        currency_symbol='₹',
        locale='en_IN',
    )

    print('Seeding Categories & Items...')
    categories = {}
    total_items = 0
    for order_index, (cat_name, icon, items) in enumerate(CATALOGUE, start=1):
        category = GarmentCategory.objects.create(
            name=cat_name, icon=icon, display_order=order_index, turnaround_days=1
        )
        categories[cat_name] = category
        for item_index, (name, price, unit) in enumerate(items, start=1):
            GarmentItem.objects.create(
                category=category, name=name, price=float(price), unit=unit,
                turnaround_days=1, display_order=item_index,
                # Matched by name *here*, once, at seed time. The client used
                # to do this lookup on every build, which meant renaming an
                # item silently lost its photo.
                image_url=ITEM_IMAGES.get(name, ''),
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
    # Same auto_now_add problem as orders: without this every customer counts
    # as new today, and the dashboard reports "+10 new today" on a shop that
    # has been trading for months. The newest two stay on today so the figure
    # is not simply zero.
    signup_base = timezone.now()
    for offset, customer in enumerate(customers):
        Customer.objects.filter(pk=customer.pk).update(
            created_at=signup_base - timedelta(days=max(offset - 1, 0) * 9)
        )

    print('Seeding Staff...')
    # (name, role, phone, monthly wage, has app login)
    staff_data = [
        ('Ramesh Kumar', 'Head Washer', '9711223344', 17000.0, True),
        ('Sunil Paswan', 'Steam Press', '9811445566', 15500.0, False),
        ('Geeta Devi', 'Dry Cleaning', '9922334455', 18000.0, False),
        ('Mohan Das', 'Delivery Driver', '9933441122', 15000.0, True),
        ('Lakshman Rao', 'Manager', '9944556677', 23000.0, True),
        ('Anita Sharma', 'Ironing Specialist', '9955667788', 16000.0, False),
    ]
    staff_objs = [
        Staff.objects.create(
            name=name, role=role, phone=phone, monthly_wage=wage,
            has_app_login=app_login,
        )
        for name, role, phone, wage, app_login in staff_data
    ]
    # `Order.assigned_agent` is a plain FK to any Staff — picking the seed's
    # delivery-oriented member by role, now that there's no dedicated flag.
    agent_for_seed = next(
        (s for s in staff_objs if s.role == 'Delivery Driver'), staff_objs[0]
    )

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
        # Spread the orders evenly across the dashboard's 14-day window, with
        # the newest landing today. This used to derive the age from
        # `sched_offset`, which bunched every order into the last six days and
        # left today empty — so the dashboard opened on "0 orders today".
        day_offset = (idx * 13) // max(len(orders_plan) - 1, 1)
        placed_at = now - timedelta(days=day_offset, hours=(idx % 6))

        source = random.choice(OrderSource.values)
        order = Order(
            customer=customer,
            customer_name=customer.name,
            customer_phone=customer.phone,
            status=status,
            payment_status=pay_status,
            payment_method=method,
            delivery_type=delivery_type,
            source=source,
            created_by=CREATED_BY[source],
            express=express,
            scheduled_date=today + timedelta(days=sched_offset),
            placed_at=placed_at,
        )
        if delivery_type in (DeliveryType.HOME_DELIVERY, DeliveryType.ONLINE):
            order.delivery_charge = 50.0
            if status in (OrderStatus.OUT_FOR_DELIVERY, OrderStatus.DELIVERED):
                order.assigned_agent = agent_for_seed

        # Stamp every stage up to the current one, and log the same trail as
        # audit entries so the order-detail Timeline & Audit Log panel has
        # real history to show rather than an empty state on every seed.
        stage_events = [(OrderStatus.PLACED, placed_at)]
        if status == OrderStatus.CANCELLED:
            order.cancelled_at = placed_at + timedelta(hours=2)
            stage_events.append((OrderStatus.CANCELLED, order.cancelled_at))
        else:
            reached = progression[: progression.index(status) + 1]
            for step, stage in enumerate(reached[1:], start=1):
                field = Order.STATUS_TIMESTAMP_FIELD[stage]
                at = placed_at + timedelta(minutes=step * 45)
                setattr(order, field, at)
                stage_events.append((stage, at))
        order.save()

        OrderAuditLog.objects.bulk_create([
            OrderAuditLog(order=order, status=stage, title=OrderStatus(stage).label, created_at=at)
            for stage, at in stage_events
        ])

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

        # `created_at` is auto_now_add, so every seeded order landed on today
        # however far back its timeline said it was placed. Every dashboard and
        # report query filters on created_at, which meant "Orders today" was
        # always the entire seed and the 14-day revenue chart was a single
        # bar. A queryset update is the only way past auto_now_add.
        Order.objects.filter(pk=order.pk).update(created_at=placed_at)

    print('Seeding Attendance...')
    # 70 days, not 7: Payroll totals a calendar month, and a week of register
    # made everyone look like they had worked five days and earned almost
    # nothing. This reaches back far enough that the previous month is fully
    # covered and the month navigator has somewhere to go.
    attendance_days = 70
    for days_ago in range(attendance_days):
        date = today - timedelta(days=days_ago)
        # Sunday off, which is why days worked is nearer 26 than 30.
        if date.weekday() == 6:
            continue
        for staff in staff_objs:
            roll = random.random()
            if roll > 0.15:
                status = Attendance.PRESENT
            elif roll > 0.10:
                status = Attendance.HALF_DAY
            elif roll > 0.05:
                status = Attendance.LEAVE
            else:
                status = Attendance.ABSENT
            Attendance.objects.create(staff=staff, date=date, status=status)

    print('Seeding Salary Payments...')
    # Enough to show all three payroll states on first run: last month settled
    # in full, this month part-paid for some and untouched for others.
    this_month = today.replace(day=1)
    last_month = (this_month - timedelta(days=1)).replace(day=1)
    salary_payments = 0
    for index, staff in enumerate(staff_objs):
        # Last month: paid off, so the row reads PAID.
        worked = Attendance.objects.filter(
            staff=staff, date__gte=last_month, date__lt=this_month
        )
        days_in_last_month = calendar.monthrange(last_month.year, last_month.month)[1]
        daily_rate = staff.monthly_wage / days_in_last_month
        earned = sum(a.day_value for a in worked) * daily_rate
        if earned:
            SalaryPayment.objects.create(
                staff=staff,
                month=last_month,
                amount=round(earned, 2),
                paid_on=timezone.now() - timedelta(days=today.day + 1),
                method='BANK_TRANSFER',
                note='Full settlement',
            )
            salary_payments += 1

        # This month: every third person gets nothing (UNPAID), the rest get an
        # advance (PARTIAL).
        if index % 3 != 0:
            SalaryPayment.objects.create(
                staff=staff,
                month=this_month,
                amount=5000.0,
                paid_on=timezone.now() - timedelta(days=2),
                method='CASH',
                note='Advance',
            )
            salary_payments += 1

    print('Seeding Expenses...')
    # Trailing int is "days ago", so the log spans the current and previous
    # month and the month-to-date totals on the dashboard mean something.
    expenses_data = [
        ('Commercial Detergent & Liquid Soap (50L)', 'Supplies', 3500.0, 'UPI', 3),
        ('Monthly Shop Rent', 'Rent', 28000.0, 'BANK_TRANSFER', 9),
        ('Electricity Bill (Commercial)', 'Utilities', 4200.0, 'BANK_TRANSFER', 12),
        ('Steam Press Machine Servicing', 'Maintenance', 1800.0, 'CASH', 18),
        ('Packaging Bags & Hangers', 'Supplies', 650.0, 'CASH', 22),
        ('Water Bill', 'Utilities', 900.0, 'CASH', 27),
        ('Staff Salary Advance - Ramesh', 'Salary', 5000.0, 'CASH', 34),
        ('Diesel for Delivery Van', 'Transport', 2200.0, 'CASH', 41),
    ]
    for title, cat, amount, method, days_ago in expenses_data:
        Expense.objects.create(
            title=title,
            category=cat,
            amount=amount,
            payment_method=method,
            date=timezone.now() - timedelta(days=days_ago),
        )

    print('\n[SUCCESS] Database seeded.')
    print(f'   - {len(customers_data)} customers')
    print(f'   - {len(orders_plan)} orders')
    print(f'   - {len(staff_data)} staff')
    print(f'   - {len(expenses_data)} expenses')
    print(f'   - {Attendance.objects.count()} attendance records over {attendance_days} days')
    print(f'   - {salary_payments} salary payments')
    print(f'   - {total_items} items across {len(CATALOGUE)} categories')
    print(f'   - {ServiceArea.objects.count()} service areas, {TimeSlot.objects.count()} time slots')


if __name__ == '__main__':
    seed()
