"""Seed a throwaway dev DB for the rider-tracking demo. Run: manage.py shell < this file.
Prints the task id, order number and a customer Bearer token as JSON on the last line."""
import json
from django.contrib.auth import get_user_model
from django.test import Client
from api.auth import mint_session_token
from api.models import Customer, Order, Shop, Staff

User = get_user_model()
DEV_PASSWORD = 'Dispatch-dev-pass-1'  # throwaway local DB only
shop, _ = Shop.objects.get_or_create(slug='dispatch-dev', defaults=dict(
    name='Dispatch Dev', latitude=25.5941, longitude=85.1376))
rider = Staff.all_objects.get_or_create(shop=shop, email='rider@demo.test', defaults=dict(
    name='Ravi', phone='8888888888', has_app_login=True))[0]
cust = Customer.all_objects.get_or_create(shop=shop, email='asha@demo.test', defaults=dict(
    name='Asha', phone='9999999999'))[0]
user, _ = User.objects.get_or_create(username='asha@demo.test', defaults=dict(email='asha@demo.test', is_active=True))
user.set_password(DEV_PASSWORD); user.is_active = True; user.save()
Order.all_objects.filter(shop=shop, order_number='WA-DEMO').delete()
order = Order.all_objects.create(shop=shop, order_number='WA-DEMO', customer=cust, customer_name='Asha',
    customer_phone='9999999999', delivery_type='HOME_DELIVERY', address='Near Boring Road, Patna',
    due_amount=250, drop_lat=25.6100, drop_lng=85.1600)
r = Client().post(f'/api/orders/{order.id}/dispatch/', {'rider': rider.id}, content_type='application/json',
                  HTTP_X_TENANT_ID='dispatch-dev', HTTP_HOST='localhost')
print(json.dumps({'status': r.status_code, 'task_id': r.json().get('task_id'), 'order': 'WA-DEMO',
                  'token': mint_session_token(user)}))
