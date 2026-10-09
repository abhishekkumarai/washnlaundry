"""Seed the database with rich demo data for comprehensive testing and Demo Mode.

Populates realistic shops, 79 catalogue items, 65 customers, 18 staff members,
88 orders across all lifecycle statuses, 70 days of attendance, salary payments,
advances, expenses, and credits.

WARNING: this wipes every tenant table before seeding.
"""

import calendar
import os
import random
from datetime import date, datetime, time, timedelta

import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'laundry_backend.settings')
django.setup()

from django.utils import timezone  # noqa: E402

from api.models import (  # noqa: E402
    Shop, ShopOrderSequence, Customer, GarmentCategory, GarmentItem, Order, OrderItem, OrderAuditLog,
    Expense, Credit, CreditCategory, DEFAULT_CREDIT_CATEGORIES,
    Staff, Attendance, SalaryPayment, SalaryAdvance, ServiceArea, TimeSlot,
    OrderStatus, PaymentStatus, DeliveryType, OrderSource, PricingUnit,
    ExpenseCategory, PaymentMethod,
)

PC, KG, SQFT, SET = PricingUnit.PIECE, PricingUnit.KG, PricingUnit.SQFT, PricingUnit.SET

CREATED_BY = {
    OrderSource.WEB: 'AK',
    OrderSource.MOBILE_APP: 'Mobile App',
    OrderSource.PUBLIC_PAGE: 'Public Page',
    OrderSource.STAFF_APP: 'Staff App',
    OrderSource.AGENT_APP: 'Agent App',
}

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

RAW_CUSTOMERS = [
    ('Aditya Sharma', '9876543210', 'aditya@gmail.com', '124, 2nd Main, HBR Layout 1st Block', 'HBR Layout'),
    ('Rohan Verma', '9811223344', 'rohan@gmail.com', '45, 5th Cross, Koramangala 4th Block', 'Koramangala'),
    ('Priya Sundaram', '9871100223', 'priya@outlook.com', '88, 100ft Road, Indiranagar', 'Indiranagar'),
    ('Meena Iyer', '9845512233', 'meena.iyer@gmail.com', '12B, Prestige Ozone, Whitefield', 'Whitefield'),
    ('Karthik Reddy', '9900112233', 'karthik.r@gmail.com', '78, 14th Main, HSR Layout Sector 3', 'HSR Layout'),
    ('Anjali Singh', '9988776655', 'anjali.s@yahoo.com', '54, 3rd Block, Jayanagar', 'Jayanagar'),
    ('Suresh Babu', '9123456789', 'suresh.b@gmail.com', '101, 1st Block, Rajajinagar', 'Rajajinagar'),
    ('Deepa Nair', '9654321098', 'deepa.n@gmail.com', '33, Margosa Road, Malleswaram', 'Malleswaram'),
    ('Vikram Patel', '9876001234', 'vikram.p@hotmail.com', '210, Judicial Layout, Yelahanka', 'Yelahanka'),
    ('Lakshmi Krishnan', '9800998877', 'lakshmi.k@gmail.com', '15, DVG Road, Basavanagudi', 'Basavanagudi'),
    ('Rahul Dravid', '9844001122', 'rahul.d@gmail.com', '7, Indiranagar 1st Stage', 'Indiranagar'),
    ('Sunita Rao', '9855112233', 'sunita.rao@yahoo.com', '24, Banaswadi Main Road', 'Banaswadi'),
    ('Amit Sen', '9866223344', 'amit.sen@outlook.com', '512, Kalyan Nagar HRBR 2nd Block', 'Kalyan Nagar'),
    ('Pooja Hegde', '9877334455', 'pooja.h@gmail.com', '19, Hennur Cross, Hennur', 'Hennur'),
    ('Rajesh Khanna', '9888445566', 'rajesh.k@gmail.com', '64, Kammanahalli Main Road', 'Kammanahalli'),
    ('Sneha Kulkarni', '9899556677', 'sneha.k@gmail.com', '99, Cooke Town, Bengaluru', 'Cooke Town'),
    ('Manoj Bajpayee', '9711002233', 'manoj.b@yahoo.com', '34, Frazer Town, Mosque Road', 'Frazer Town'),
    ('Kavita Menon', '9722113344', 'kavita.m@outlook.com', '82, Ulsoor Lake Road', 'Ulsoor'),
    ('Nikhil Kamath', '9733224455', 'nikhil.k@gmail.com', '100, RMV Extension 2nd Stage', 'Sadashivanagar'),
    ('Divya Spandana', '9744335566', 'divya.s@gmail.com', '43, Bellary Road, Hebbal', 'Hebbal'),
    ('Harish Kumar', '9755446677', 'harish.k@yahoo.com', '11, Marathahalli Ring Road', 'Marathahalli'),
    ('Shweta Tiwari', '9766557788', 'shweta.t@gmail.com', '29, Green Glen Layout, Bellandur', 'Bellandur'),
    ('Arvind Hegde', '9777668899', 'arvind.h@outlook.com', '91, Sarjapur Road, Bellandur', 'Bellandur'),
    ('Neha Kakkar', '9788779900', 'neha.k@gmail.com', '14, Electronic City Phase 1', 'Electronic City'),
    ('Chetan Bhagat', '9799880011', 'chetan.b@yahoo.com', '67, JP Nagar 6th Phase', 'JP Nagar'),
    ('Ritu Karidhal', '9611001122', 'ritu.k@gmail.com', '80, BTM Layout 2nd Stage', 'BTM Layout'),
    ('Gautam Gambhir', '9622112233', 'gautam.g@gmail.com', '15, Cunningham Road, Vasanth Nagar', 'Vasanth Nagar'),
    ('Swati Mohan', '9633223344', 'swati.m@outlook.com', '37, Lavelle Road', 'Richmond Town'),
    ('Pradeep Kumar', '9644334455', 'pradeep.k@gmail.com', '58, Richmond Road', 'Richmond Town'),
    ('Vandana Shiva', '9655445566', 'vandana.s@yahoo.com', '21, Victoria Layout', 'Victoria Layout'),
    ('Alok Nath', '9666556677', 'alok.n@gmail.com', '73, Benson Town', 'Benson Town'),
    ('Smriti Irani', '9677667788', 'smriti.i@outlook.com', '49, Wheeler Road, Cox Town', 'Cox Town'),
    ('Sandeep Maheshwari', '9688778899', 'sandeep.m@gmail.com', '62, RT Nagar Main Road', 'RT Nagar'),
    ('Shilpa Shetty', '9699889900', 'shilpa.s@yahoo.com', '88, Sanjeevini Nagar, Sahakar Nagar', 'Sahakar Nagar'),
    ('Vijay Mallya', '9511002233', 'vijay.m@gmail.com', '1, UB City, Vittal Mallya Road', 'CBD'),
    ('Preeti Shenoy', '9522113344', 'preeti.s@outlook.com', '40, Koramangala 1st Block', 'Koramangala'),
    ('Varun Dhawan', '9533224455', 'varun.d@gmail.com', '52, 17th Cross, HSR Layout Sector 4', 'HSR Layout'),
    ('Tanvi Azmi', '9544335566', 'tanvi.a@gmail.com', '30, 8th Main, Malleswaram', 'Malleswaram'),
    ('Mohit Chauhan', '9555446677', 'mohit.c@yahoo.com', '16, Sanjay Nagar', 'Sanjay Nagar'),
    ('Radhika Apte', '9566557788', 'radhika.a@gmail.com', '93, New BEL Road', 'Sanjay Nagar'),
    ('Sanjay Dutt', '9577668899', 'sanjay.d@outlook.com', '75, Dollars Colony, RMV', 'Sadashivanagar'),
    ('Sunidhi Chauhan', '9588779900', 'sunidhi.c@gmail.com', '61, Kasturi Nagar', 'Kasturi Nagar'),
    ('Kunal Shah', '9599880011', 'kunal.s@gmail.com', '102, Embassy Golf Links, Domlur', 'Domlur'),
    ('Deepika Padukone', '9411001122', 'deepika.p@yahoo.com', '23, HAL 2nd Stage, Indiranagar', 'Indiranagar'),
    ('Ranbir Kapoor', '9422112233', 'ranbir.k@gmail.com', '84, Cambridge Layout', 'Ulsoor'),
    ('Aparna Sen', '9433223344', 'aparna.s@outlook.com', '12, Rest House Crescent, Church Street', 'CBD'),
    ('Pankaj Tripathi', '9444334455', 'pankaj.t@gmail.com', '47, Austin Town', 'Austin Town'),
    ('Nandita Das', '9455445566', 'nandita.d@yahoo.com', '68, Langford Town', 'Langford Town'),
    ('Raghuram Rajan', '9466556677', 'raghuram.r@gmail.com', '39, Jayamahal Extension', 'Jayamahal'),
    ('Arundhati Roy', '9477667788', 'arundhati.r@outlook.com', '55, Palace Cross Road', 'Vasanth Nagar'),
    ('Sabeer Bhatia', '9488778899', 'sabeer.b@gmail.com', '90, Kumara Park West', 'Kumara Park'),
    ('Kiran Mazumdar', '9499889900', 'kiran.m@biocon.example', '110, Hosur Road, Electronic City', 'Electronic City'),
    ('Narayana Murthy', '9311002233', 'narayana.m@infosys.example', '44, Jayanagar 4th T Block', 'Jayanagar'),
    ('Sudha Murty', '9322113344', 'sudha.m@foundation.example', '46, Jayanagar 4th T Block', 'Jayanagar'),
    ('Azim Premji', '9333224455', 'azim.p@wipro.example', '72, Sarjapur Road', 'Bellandur'),
    ('Nandan Nilekani', '9344335566', 'nandan.n@gmail.com', '85, Koramangala 3rd Block', 'Koramangala'),
    ('Kris Gopalakrishnan', '9355446677', 'kris.g@gmail.com', '27, Koramangala 3rd Block', 'Koramangala'),
    ('Bhavish Aggarwal', '9366557788', 'bhavish.a@ola.example', '18, Regent Insignia, Koramangala', 'Koramangala'),
    ('Vijay Shekhar', '9377668899', 'vijay.s@paytm.example', '63, Indiranagar Defence Colony', 'Indiranagar'),
    ('Sachin Bansal', '9388779900', 'sachin.b@navi.example', '95, Koramangala 3rd Block', 'Koramangala'),
    ('Binny Bansal', '9399880011', 'binny.b@gmail.com', '104, Koramangala 3rd Block', 'Koramangala'),
    ('Ritesh Agarwal', '9211001122', 'ritesh.a@oyo.example', '36, HSR Layout Sector 1', 'HSR Layout'),
    ('Deepinder Goyal', '9222112233', 'deepinder.g@zomato.example', '77, Indiranagar 100ft Road', 'Indiranagar'),
    ('Falguni Nayar', '9233223344', 'falguni.n@nykaa.example', '59, Sadashivanagar 1st Main', 'Sadashivanagar'),
    ('Byju Raveendran', '9244334455', 'byju.r@byjus.example', '81, IBC Knowledge Park, Bannerghatta Road', 'Bannerghatta Road'),
]


def seed():
    print('Clearing old data...')
    OrderItem.objects.all().delete()
    OrderAuditLog.objects.all().delete()
    Order.objects.all().delete()
    ShopOrderSequence.objects.all().delete()
    Customer.objects.all().delete()
    GarmentItem.objects.all().delete()
    GarmentCategory.objects.all().delete()
    Expense.objects.all().delete()
    Credit.objects.all().delete()
    CreditCategory.objects.all().delete()
    Attendance.objects.all().delete()
    SalaryAdvance.objects.all().delete()
    SalaryPayment.objects.all().delete()
    Staff.objects.all().delete()
    TimeSlot.objects.all().delete()
    ServiceArea.objects.all().delete()
    Shop.objects.all().delete()

    print('Seeding Shop...')
    shop = Shop.objects.create(
        name='washing',
        owner_name='AK',
        phone='9876543210',
        whatsapp='9876543210',
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
        express_multiplier=1.5,
        default_monthly_wage=18000.0,
        default_staff_role='Washer',
        currency_symbol='₹',
        locale='en_IN',
    )

    print('Seeding Categories & Items...')
    GarmentItem.objects.all().delete()
    GarmentCategory.objects.all().delete()
    categories = {}
    total_items = 0
    for order_index, (cat_name, icon, items) in enumerate(CATALOGUE, start=1):
        category = GarmentCategory.objects.create(
            shop=shop, name=cat_name, icon=icon, display_order=order_index
        )
        categories[cat_name] = category
        for item_index, (name, price, unit) in enumerate(items, start=1):
            GarmentItem.objects.create(
                shop=shop,
                category=category, name=name, price=float(price), unit=unit,
                display_order=item_index,
                image_url=ITEM_IMAGES.get(name, ''),
            )
            total_items += 1

    print('Seeding Service Areas & Time Slots...')
    for area in ['HBR Layout', 'Kalyan Nagar', 'Banaswadi', 'Hennur', 'Indiranagar', 'Koramangala', 'HSR Layout', 'Whitefield']:
        ServiceArea.objects.create(shop=shop, name=area, pin_code='560043')
    for kind in (TimeSlot.PICKUP, TimeSlot.DELIVERY):
        for start, end in DEFAULT_SLOTS:
            TimeSlot.objects.create(shop=shop, kind=kind, start_time=start, end_time=end, capacity=None)

    print('Seeding 65 Customers...')
    customers = []
    signup_base = timezone.now()
    for idx, (name, phone, email, addr, area) in enumerate(RAW_CUSTOMERS):
        c = Customer.objects.create(
            shop=shop,
            name=name,
            phone=phone,
            email=email,
            address=addr,
            area=area,
            total_orders=0,
            total_spent=0.0,
            due_amount=0.0,
        )
        # Distribute signup dates: the first 3 registered today, the rest stagger over 90 days
        created_at = signup_base - timedelta(days=max((idx - 2) * 2, 0))
        Customer.objects.filter(pk=c.pk).update(created_at=created_at)
        customers.append(c)

    print('Seeding 18 Staff Members across roles...')
    staff_data = [
        ('Lakshman Rao', 'Manager', '9944556677', 28000.0, True, 'ACTIVE', date(2025, 1, 10)),
        ('Ramesh Kumar', 'Head Washer', '9711223344', 18500.0, True, 'ACTIVE', date(2025, 2, 1)),
        ('Sunil Paswan', 'Steam Press', '9811445566', 16000.0, False, 'ACTIVE', date(2025, 3, 15)),
        ('Geeta Devi', 'Dry Cleaning', '9922334455', 18500.0, False, 'ACTIVE', date(2025, 3, 20)),
        ('Mohan Das', 'Delivery Driver', '9933441122', 16000.0, True, 'ACTIVE', date(2025, 4, 1)),
        ('Anita Sharma', 'Ironing Specialist', '9955667788', 16000.0, False, 'ACTIVE', date(2025, 4, 15)),
        ('Prakash Jha', 'Delivery Driver', '9966778899', 15500.0, True, 'ACTIVE', date(2025, 5, 1)),
        ('Manoj Tiwari', 'Head Washer', '9877112233', 18000.0, False, 'ACTIVE', date(2025, 6, 1)),
        ('Rekha Verma', 'Quality Checker', '9888223344', 17000.0, True, 'ACTIVE', date(2025, 6, 15)),
        ('Kavita Soni', 'Steam Press', '9899334455', 15500.0, False, 'ACTIVE', date(2025, 7, 1)),
        ('Vikram Rathore', 'Delivery Driver', '9700445566', 15500.0, True, 'ACTIVE', date(2025, 8, 1)),
        ('Sanjay Yadav', 'Store Associate', '9711556677', 16500.0, True, 'ACTIVE', date(2025, 9, 1)),
        ('Sarita Devi', 'Ironing Specialist', '9722667788', 15000.0, False, 'ACTIVE', date(2025, 10, 1)),
        ('Dinesh Pandey', 'Assistant Manager', '9733778899', 22000.0, True, 'ACTIVE', date(2025, 11, 1)),
        ('Santosh Gond', 'Washer', '9744889900', 14500.0, False, 'ACTIVE', date(2025, 12, 1)),
        ('Asha Negi', 'Ironing Specialist', '9755990011', 15000.0, False, 'INACTIVE', date(2025, 2, 15)),
        ('Rajesh Bind', 'Dry Cleaning', '9766001122', 17500.0, False, 'INACTIVE', date(2025, 4, 1)),
        ('Vinod Rawat', 'Delivery Driver', '9777112233', 15000.0, False, 'INACTIVE', date(2025, 5, 20)),
    ]
    staff_objs = [
        Staff.objects.create(
            shop=shop,
            name=name, role=role, phone=phone, monthly_wage=wage,
            has_app_login=app_login, status=status, start_date=s_date,
        )
        for name, role, phone, wage, app_login, status, s_date in staff_data
    ]

    delivery_drivers = [s for s in staff_objs if s.role == 'Delivery Driver']

    print('Seeding 88 Orders across all lifecycle states...')
    today = timezone.localdate()
    now = timezone.now()
    all_items = list(GarmentItem.objects.select_related('category').all())

    progression = [
        OrderStatus.PLACED, OrderStatus.PROCESSING, OrderStatus.IRONING,
        OrderStatus.READY, OrderStatus.OUT_FOR_DELIVERY, OrderStatus.DELIVERED,
    ]

    # Deterministic generation plan for 88 orders
    # Distribution:
    # 12 placed today (days_ago = 0)
    # 10 placed yesterday (days_ago = 1)
    # 66 placed across days 2 to 28
    orders_to_create = []

    statuses_pool = (
        [OrderStatus.PLACED] * 10 +
        [OrderStatus.PROCESSING] * 12 +
        [OrderStatus.IRONING] * 10 +
        [OrderStatus.READY] * 12 +
        [OrderStatus.OUT_FOR_DELIVERY] * 8 +
        [OrderStatus.DELIVERED] * 31 +
        [OrderStatus.CANCELLED] * 5
    )
    # Total 88 items
    random.seed(42)  # reproducible rich seed
    random.shuffle(statuses_pool)

    for i in range(88):
        status = statuses_pool[i]

        # Days ago determination:
        if i < 12:
            days_ago = 0
            hours_ago = 1 + (i % 10)
        elif i < 22:
            days_ago = 1
            hours_ago = 3 + (i % 8)
        else:
            # Span days 2 through 28
            days_ago = 2 + ((i - 22) * 26) // 66
            hours_ago = (i * 3) % 12

        placed_at = now - timedelta(days=days_ago, hours=hours_ago)

        # Scheduled offset from placed_at date
        if status in (OrderStatus.PLACED, OrderStatus.PROCESSING, OrderStatus.IRONING):
            sched_offset = random.randint(1, 3)
        elif status == OrderStatus.READY:
            sched_offset = 0
        elif status == OrderStatus.OUT_FOR_DELIVERY:
            sched_offset = 0
        elif status == OrderStatus.DELIVERED:
            sched_offset = -random.randint(0, 2)
        else:
            sched_offset = -1

        # Payment status & methods
        if status == OrderStatus.DELIVERED:
            pay_status = PaymentStatus.PAID if (i % 8 != 0) else PaymentStatus.PARTIAL
        elif status in (OrderStatus.READY, OrderStatus.OUT_FOR_DELIVERY):
            pay_status = PaymentStatus.PAID if (i % 2 == 0) else PaymentStatus.PARTIAL
        elif status == OrderStatus.CANCELLED:
            pay_status = PaymentStatus.UNPAID
        else:
            pay_status = random.choice([PaymentStatus.PAID, PaymentStatus.PARTIAL, PaymentStatus.UNPAID])

        method = random.choice(['UPI', 'CASH', 'CARD', 'BANK_TRANSFER'])
        delivery_type = random.choice([
            DeliveryType.HOME_DELIVERY, DeliveryType.HOME_DELIVERY,
            DeliveryType.STORE_PICKUP, DeliveryType.HOME_PICKUP, DeliveryType.ONLINE
        ])
        express = (i % 5 == 0)
        customer = customers[i % len(customers)]

        orders_to_create.append({
            'customer': customer,
            'status': status,
            'pay_status': pay_status,
            'method': method,
            'delivery_type': delivery_type,
            'express': express,
            'placed_at': placed_at,
            'sched_date': today - timedelta(days=days_ago) + timedelta(days=sched_offset),
            'idx': i,
        })

    # Sort so oldest orders get lower sequence numbers, newest get highest
    orders_to_create.sort(key=lambda x: x['placed_at'])

    customer_totals = {c.pk: {'orders': 0, 'spent': 0.0, 'due': 0.0} for c in customers}

    for ord_info in orders_to_create:
        customer = ord_info['customer']
        status = ord_info['status']
        pay_status = ord_info['pay_status']
        method = ord_info['method']
        delivery_type = ord_info['delivery_type']
        express = ord_info['express']
        placed_at = ord_info['placed_at']
        sched_date = ord_info['sched_date']
        i = ord_info['idx']

        source = random.choice(OrderSource.values)
        order = Order(
            shop=shop,
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
            scheduled_date=sched_date,
            placed_at=placed_at,
        )

        if delivery_type in (DeliveryType.HOME_DELIVERY, DeliveryType.ONLINE):
            order.delivery_charge = 50.0
            if status in (OrderStatus.OUT_FOR_DELIVERY, OrderStatus.DELIVERED):
                order.assigned_agent = delivery_drivers[i % len(delivery_drivers)]

        # Timeline and stage events
        stage_events = [(OrderStatus.PLACED, placed_at)]
        if status == OrderStatus.CANCELLED:
            order.cancelled_at = placed_at + timedelta(hours=2)
            stage_events.append((OrderStatus.CANCELLED, order.cancelled_at))
        else:
            reached = progression[: progression.index(status) + 1]
            for step, stage in enumerate(reached[1:], start=1):
                field = Order.STATUS_TIMESTAMP_FIELD[stage]
                at = placed_at + timedelta(minutes=step * 40)
                setattr(order, field, at)
                stage_events.append((stage, at))
        order.save()

        OrderAuditLog.objects.bulk_create([
            OrderAuditLog(shop=shop, order=order, status=stage, title=OrderStatus(stage).label, created_at=at)
            for stage, at in stage_events
        ])

        # 2 to 4 items per order
        chosen_items = random.sample(all_items, random.randint(2, 4))
        subtotal = 0.0
        for garment in chosen_items:
            qty = random.randint(1, 4)
            line_total = qty * garment.price
            subtotal += line_total
            OrderItem.objects.create(
                shop=shop,
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

        if express:
            subtotal = round(subtotal * shop.express_multiplier, 2)

        order.subtotal = subtotal
        order.total_amount = subtotal + order.delivery_charge

        if pay_status == PaymentStatus.PAID:
            order.paid_amount = order.total_amount
        elif pay_status == PaymentStatus.PARTIAL:
            order.paid_amount = round(order.total_amount * 0.5, 2)
        else:
            order.paid_amount = 0.0

        order.due_amount = round(order.total_amount - order.paid_amount, 2)
        order.save()

        # Update auto_now_add created_at
        Order.objects.filter(pk=order.pk).update(created_at=placed_at)

        # Accumulate into customer totals
        if status != OrderStatus.CANCELLED:
            customer_totals[customer.pk]['orders'] += 1
            customer_totals[customer.pk]['spent'] += order.paid_amount
            customer_totals[customer.pk]['due'] += order.due_amount

    # Write aggregated customer figures
    for cust_pk, stats in customer_totals.items():
        Customer.objects.filter(pk=cust_pk).update(
            total_orders=stats['orders'],
            total_spent=round(stats['spent'], 2),
            due_amount=round(stats['due'], 2),
        )

    print('Seeding Attendance for all staff over 70 days...')
    attendance_days = 70
    attendance_records = []
    for days_ago in range(attendance_days):
        att_date = today - timedelta(days=days_ago)
        if att_date.weekday() == 6:  # Sunday off
            continue
        for staff in staff_objs:
            if staff.status == 'INACTIVE' and days_ago < 20:
                continue
            roll = random.random()
            if roll > 0.12:
                att_status = Attendance.PRESENT
            elif roll > 0.07:
                att_status = Attendance.HALF_DAY
            elif roll > 0.03:
                att_status = Attendance.LEAVE
            else:
                att_status = Attendance.ABSENT
            attendance_records.append(
                Attendance(shop=shop, staff=staff, date=att_date, status=att_status)
            )
    Attendance.objects.bulk_create(attendance_records)

    print('Seeding Salary Payments & Advances...')
    this_month = today.replace(day=1)
    last_month = (this_month - timedelta(days=1)).replace(day=1)
    salary_payments = 0
    for index, staff in enumerate(staff_objs):
        worked = Attendance.objects.filter(
            staff=staff, date__gte=last_month, date__lt=this_month
        )
        days_in_last_month = calendar.monthrange(last_month.year, last_month.month)[1]
        daily_rate = staff.monthly_wage / days_in_last_month
        earned = sum(a.day_value for a in worked) * daily_rate
        if earned:
            SalaryPayment.objects.create(
                shop=shop,
                staff=staff,
                month=last_month,
                amount=round(earned, 2),
                paid_on=timezone.now() - timedelta(days=today.day + 1),
                method='BANK_TRANSFER',
                note='Full settlement for previous month',
            )
            salary_payments += 1

        # Current month partials and advances
        if index % 3 != 0 and staff.status == 'ACTIVE':
            SalaryPayment.objects.create(
                shop=shop,
                staff=staff,
                month=this_month,
                amount=round(staff.monthly_wage * 0.4, 2),
                paid_on=timezone.now() - timedelta(days=2),
                method='CASH',
                note='Mid-month salary advance/partial',
            )
            salary_payments += 1
            if index % 3 == 1:
                SalaryAdvance.objects.create(
                    shop=shop,
                    staff=staff,
                    month=this_month,
                    amount=1500.0,
                    paid_on=timezone.now() - timedelta(days=5),
                    method='CASH',
                    note='Festival advance',
                )

    print('Seeding 24 Operational Expenses...')
    expenses_data = [
        ('Commercial Detergent & Liquid Soap (100L)', ExpenseCategory.SUPPLIES, 7500.0, 'UPI', 2),
        ('Fabric Softener & Optical Brightener', ExpenseCategory.SUPPLIES, 3200.0, 'UPI', 4),
        ('Boiler Fuel & Gas Cylinders (4 commercial)', ExpenseCategory.UTILITIES, 6800.0, 'CASH', 5),
        ('Monthly Main Shop Rent', ExpenseCategory.RENT, 32000.0, 'BANK_TRANSFER', 8),
        ('Electricity Bill - BESCOM Commercial', ExpenseCategory.UTILITIES, 5400.0, 'BANK_TRANSFER', 10),
        ('Water Tanker Supplies (4 loads)', ExpenseCategory.UTILITIES, 2800.0, 'UPI', 12),
        ('Garment Covers & Plastic Film Rolls', ExpenseCategory.SUPPLIES, 1850.0, 'CASH', 14),
        ('Wire Hangers Box (500 pcs)', ExpenseCategory.SUPPLIES, 1400.0, 'UPI', 16),
        ('Dry Cleaning Perchloroethylene Solvent (30L)', ExpenseCategory.SUPPLIES, 9200.0, 'BANK_TRANSFER', 18),
        ('Steam Iron Teflon Shoe Replacement (3 units)', ExpenseCategory.MAINTENANCE, 2100.0, 'CASH', 20),
        ('Van Diesel & Toll Charges', ExpenseCategory.TRANSPORT, 3400.0, 'UPI', 22),
        ('Staff Tea & Daily Refreshments (2 weeks)', ExpenseCategory.SUPPLIES, 1600.0, 'CASH', 24),
        ('Van Periodic Oil Service & Filter Change', ExpenseCategory.MAINTENANCE, 4500.0, 'BANK_TRANSFER', 27),
        ('Local Pamphlets Printing & Distribution', ExpenseCategory.OTHER, 3500.0, 'UPI', 29),
        ('Instagram & Meta Local Ad Boosts', ExpenseCategory.OTHER, 4000.0, 'CARD', 31),
        ('Shop Fire Extinguisher Refill & Inspection', ExpenseCategory.MAINTENANCE, 1200.0, 'CASH', 34),
        ('Commercial Washing Machine Drum Bearings Service', ExpenseCategory.MAINTENANCE, 5800.0, 'BANK_TRANSFER', 37),
        ('Broadband Internet & CCTV Cloud Backup', ExpenseCategory.UTILITIES, 1500.0, 'UPI', 40),
        ('Thermal Paper Receipt Rolls (Carton)', ExpenseCategory.SUPPLIES, 850.0, 'CASH', 42),
        ('Store Deep Cleaning & Pest Control', ExpenseCategory.MAINTENANCE, 2500.0, 'UPI', 45),
        ('Stationery, Tags & QR Marker Pens', ExpenseCategory.SUPPLIES, 950.0, 'CASH', 48),
        ('Electric Motor Overhaul for Dryer', ExpenseCategory.MAINTENANCE, 4200.0, 'BANK_TRANSFER', 51),
        ('Delivery Helmets & Reflective Jackets', ExpenseCategory.MAINTENANCE, 2200.0, 'UPI', 55),
        ('Customer Garment Loss Goodwill Claim Settlement', ExpenseCategory.OTHER, 1500.0, 'UPI', 58),
    ]
    for title, cat, amount, method, days_ago in expenses_data:
        Expense.objects.create(
            shop=shop,
            title=title,
            category=cat,
            amount=amount,
            payment_method=method,
            date=timezone.now() - timedelta(days=days_ago),
        )

    print('Seeding 16 Credits...')
    credit_categories = {
        name: CreditCategory.objects.create(shop=shop, name=name, display_order=order)
        for order, name in enumerate(DEFAULT_CREDIT_CATEGORIES)
    }
    credits_data = [
        ('Hotel Royal Orchid - Monthly Linen Advance', 'Customer Advance', 25000.0, 'BANK_TRANSFER', 3, 'Monthly contract advance'),
        ('Bulk Doorstep Delivery Collections', 'Delivery Charges', 2450.0, 'UPI', 6, 'App-based courier delivery top-ups'),
        ('Owner Capital Infusion for Speed Queen Dryer', 'Owner Investment', 50000.0, 'BANK_TRANSFER', 9, 'Capital towards new commercial tumble dryer'),
        ('Wedding Sherwani & Bridal Lehenga Premium Batch', 'Dry Cleaning Income', 4800.0, 'CASH', 12, 'Walk-in cash for heavy bridal care'),
        ('The Paul Hotel Uniforms Contract Retainer', 'Customer Advance', 18000.0, 'BANK_TRANSFER', 15, 'Bi-weekly billing settlement'),
        ('Corporate Guest House Curtains Wash Batch', 'Laundry Income', 8500.0, 'UPI', 18, '45 window drape sets completed'),
        ('Spa & Wellness Center Towels Weekly Advance', 'Customer Advance', 12000.0, 'BANK_TRANSFER', 21, 'Weekly automated contract advance'),
        ('Express Same-Day Priority Fee Collections', 'Laundry Income', 3150.0, 'UPI', 24, 'Customer express rush premiums'),
        ('Counter Cash Retail Surplus', 'Other', 1400.0, 'CASH', 28, 'Weekly cash counter reconciliation'),
        ('Owner Working Capital Support', 'Owner Investment', 20000.0, 'BANK_TRANSFER', 32, 'Interim liquidity top-up'),
        ('Gym & Fitness Studio Microfiber Towels Contract', 'Laundry Income', 6500.0, 'UPI', 35, 'Monthly gym laundry retainer'),
        ('Boutique Designer Dresses Finishing Surcharge', 'Dry Cleaning Income', 3900.0, 'CARD', 38, 'Special fabric finishing charge'),
        ('Apartment Society Bulk Ironing Weekend Camp', 'Laundry Income', 9200.0, 'UPI', 42, 'HBR Layout apartment camp'),
        ('Old Scrap Metal Drum & Copper Pipe Recycling', 'Other', 2100.0, 'CASH', 46, 'Salvage sale from replaced equipment'),
        ('Service Apartment Bed Linen Initial Deposit', 'Customer Advance', 15000.0, 'BANK_TRANSFER', 50, 'New contract security deposit'),
        ('Shoe Spa Master Restoration Package Inflows', 'Dry Cleaning Income', 4200.0, 'UPI', 54, 'Leather boots and sneaker restorations'),
    ]
    for title, cat, amount, method, days_ago, notes in credits_data:
        Credit.objects.create(
            shop=shop,
            title=title,
            category=credit_categories[cat],
            amount=amount,
            payment_method=method,
            date=timezone.now() - timedelta(days=days_ago),
            notes=notes,
        )

    print('\n[SUCCESS] Database seeded successfully with rich demo values!')
    print(f'   - {Customer.objects.count()} customers')
    print(f'   - {Order.objects.count()} orders ({Order.objects.filter(placed_at__date=today).count()} placed today)')
    print(f'   - {Staff.objects.count()} staff ({Staff.objects.filter(status="ACTIVE").count()} active, {Staff.objects.filter(status="INACTIVE").count()} inactive)')
    print(f'   - {Expense.objects.count()} expenses (including operational & salary)')
    print(f'   - {Credit.objects.count()} credits across {len(credit_categories)} credit categories')
    print(f'   - {Attendance.objects.count()} attendance records over {attendance_days} days')
    print(f'   - {SalaryPayment.objects.count()} salary payments, {SalaryAdvance.objects.count()} advances')
    print(f'   - {GarmentItem.objects.count()} items across {GarmentCategory.objects.count()} categories')


if __name__ == '__main__':
    seed()
