import logging
import re
import time
import requests
from django.conf import settings
from .whatsapp_templates import (
    build_order_receipt_message,
    build_order_status_message,
    build_payroll_slip_message,
)

logger = logging.getLogger(__name__)


class WhatsAppService:
    """
    Client for the local Baileys WhatsApp Bridge microservice.
    Respects WHATSAPP_DRY_RUN to prevent unwanted outbound WhatsApp messages during testing.
    """

    @classmethod
    def get_bridge_url(cls):
        return getattr(settings, 'WHATSAPP_BRIDGE_URL', 'http://127.0.0.1:3000').rstrip('/')

    @classmethod
    def get_bridge_token(cls):
        return getattr(settings, 'WHATSAPP_BRIDGE_TOKEN', '')

    @classmethod
    def is_dry_run(cls):
        return getattr(settings, 'WHATSAPP_DRY_RUN', True)

    @classmethod
    def get_default_country_code(cls):
        return getattr(settings, 'WHATSAPP_DEFAULT_COUNTRY_CODE', '91')

    @classmethod
    def normalize_phone(cls, phone):
        """
        Normalize phone input to E.164 digits format (without '+').
        Defaults 10-digit Indian numbers to country code 91.
        """
        if not phone:
            return None
        raw = str(phone).strip()
        # Remove any WhatsApp JID suffix if passed
        if '@' in raw:
            raw = raw.split('@')[0]
        # Keep only digits
        digits = re.sub(r'\D', '', raw)
        if not digits:
            return None
        if len(digits) == 10:
            return f"{cls.get_default_country_code()}{digits}"
        return digits

    @classmethod
    def _headers(cls):
        headers = {'Content-Type': 'application/json'}
        token = cls.get_bridge_token()
        if token:
            headers['Authorization'] = f"Bearer {token}"
            headers['x-bridge-token'] = token
        return headers

    @classmethod
    def get_bridge_status(cls):
        """
        Check WhatsApp Bridge health and socket pairing status.
        """
        url = f"{cls.get_bridge_url()}/health"
        try:
            resp = requests.get(url, headers=cls._headers(), timeout=3)
            if resp.status_code == 200:
                data = resp.json()
                return {
                    'available': True,
                    'status': data.get('status', 'disconnected'),
                    'user': data.get('user'),
                    'uptime': data.get('uptime', 0),
                    'dry_run': cls.is_dry_run(),
                }
            return {
                'available': False,
                'status': 'http_error',
                'error': f"Status {resp.status_code}",
                'dry_run': cls.is_dry_run(),
            }
        except requests.exceptions.RequestException as e:
            return {
                'available': False,
                'status': 'offline',
                'error': str(e),
                'dry_run': cls.is_dry_run(),
            }

    @classmethod
    def get_qr_code(cls):
        """
        Fetch latest QR pairing data URL from bridge.
        """
        url = f"{cls.get_bridge_url()}/qr"
        try:
            resp = requests.get(url, headers=cls._headers(), timeout=3)
            if resp.status_code == 200:
                return resp.json()
            return {'ok': False, 'error': f"Bridge responded with {resp.status_code}"}
        except requests.exceptions.RequestException as e:
            return {'ok': False, 'error': f"Bridge connection failed: {e}"}

    @classmethod
    def send_message(cls, phone, message):
        """
        Send text message to normalized phone number.
        Returns dict with success status and message ID.
        """
        normalized = cls.normalize_phone(phone)
        if not normalized:
            return {'ok': False, 'error': 'Invalid recipient phone number'}

        if not message or not str(message).strip():
            return {'ok': False, 'error': 'Message content cannot be empty'}

        if cls.is_dry_run():
            logger.info(f"[WhatsApp DRY RUN] Would send to {normalized}:\n{message}")
            return {
                'ok': True,
                'dry_run': True,
                'phone': normalized,
                'messageId': f"dry_run_{int(time.time())}",
                'message': message,
            }

        url = f"{cls.get_bridge_url()}/send"
        payload = {'phone': normalized, 'message': message}

        try:
            resp = requests.post(url, json=payload, headers=cls._headers(), timeout=15)
            if resp.status_code == 200:
                data = resp.json()
                return {
                    'ok': True,
                    'dry_run': False,
                    'phone': normalized,
                    'messageId': data.get('messageId'),
                }
            error_msg = resp.json().get('error', resp.text) if resp.headers.get('content-type', '').startswith('application/json') else resp.text
            return {'ok': False, 'error': f"Bridge error ({resp.status_code}): {error_msg}"}
        except requests.exceptions.RequestException as e:
            logger.error(f"WhatsApp send failed: {e}")
            return {'ok': False, 'error': f"Bridge connection failed: {e}"}

    @classmethod
    def send_order_receipt(cls, order):
        """
        Format and send order receipt to order customer phone.
        Also records an audit log entry on the order.
        """
        phone = order.customer_phone or (order.customer.phone if order.customer else '')
        if not phone:
            return {'ok': False, 'error': 'Customer has no phone number on file'}

        message = build_order_receipt_message(order)
        result = cls.send_message(phone, message)

        if result.get('ok'):
            order.audit_log.create(
                status=order.status,
                title="WhatsApp Receipt Sent",
                detail=f"Automated receipt delivered to {cls.normalize_phone(phone)} (ID: {result.get('messageId')})",
            )
        return result

    @classmethod
    def send_order_status_update(cls, order, note=''):
        """
        Format and send status change notification to order customer.
        Also records an audit log entry on the order.
        """
        phone = order.customer_phone or (order.customer.phone if order.customer else '')
        if not phone:
            return {'ok': False, 'error': 'Customer has no phone number on file'}

        message = build_order_status_message(order, note=note)
        result = cls.send_message(phone, message)

        if result.get('ok'):
            order.audit_log.create(
                status=order.status,
                title=f"WhatsApp Status Update: {order.status}",
                detail=f"Notification delivered to {cls.normalize_phone(phone)}",
            )
        return result

    @classmethod
    def send_payroll_slip(cls, staff, month_str, days_worked=0, half_days=0, gross_wage=0.0, paid_amount=0.0, payment_method='Cash', note=''):
        """
        Format and send salary slip to staff member's phone.
        """
        phone = staff.phone
        if not phone:
            return {'ok': False, 'error': f"Staff member '{staff.name}' has no phone number on file"}

        message = build_payroll_slip_message(
            staff=staff,
            month_str=month_str,
            days_worked=days_worked,
            half_days=half_days,
            gross_wage=gross_wage,
            paid_amount=paid_amount,
            payment_method=payment_method,
            note=note,
        )
        return cls.send_message(phone, message)
