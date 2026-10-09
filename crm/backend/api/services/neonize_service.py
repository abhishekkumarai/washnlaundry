import base64
import io
import logging
import os
import threading
import time
import sys
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)

try:
    import segno
    HAS_SEGNO = True
except ImportError:
    HAS_SEGNO = False

try:
    from neonize.client import NewClient
    from neonize.events import QREv, ConnectedEv, DisconnectedEv, MessageEv, LoggedOutEv, PairStatusEv
    HAS_NEONIZE = True
except ImportError:
    HAS_NEONIZE = False


class NeonizeService:
    """
    Service managing personal WhatsApp number connection via Neonize (whatsmeow Go bridge).
    Enables linking personal WhatsApp numbers via QR code without Meta WhatsApp Business Cloud API.
    """
    _instance = None
    _lock = threading.RLock()

    STATUS_DISCONNECTED = 'disconnected'
    STATUS_PAIRING = 'pairing'
    STATUS_CONNECTED = 'connected'

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            with cls._lock:
                if not cls._instance:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if getattr(self, '_initialized', False):
            return
        self._initialized = True
        self.status = self.STATUS_DISCONNECTED
        self.phone_number = None
        self.push_name = None
        self.qr_code_data_url = None
        self.qr_raw = None
        self.last_active = None
        self.client = None
        self.thread = None
        self._db_path = os.path.join(getattr(settings, 'BASE_DIR', '.'), 'neonize_whatsapp.sqlite3')

    @classmethod
    def get_instance(cls):
        return cls()

    def _generate_qr_data_url(self, qr_text: str) -> str:
        """Converts a raw QR string into a base64 PNG data URL using segno."""
        if not HAS_SEGNO:
            return ""
        try:
            q = segno.make(qr_text, error='m')
            buf = io.BytesIO()
            q.save(buf, kind='png', scale=6, border=2)
            b64_png = base64.b64encode(buf.getvalue()).decode('utf-8')
            return f"data:image/png;base64,{b64_png}"
        except Exception as e:
            logger.error(f"Error encoding QR code to data URL: {e}")
            return ""

    def get_status(self, shop=None):
        """Returns the current WhatsApp personal connection status and QR code."""
        with self._lock:
            # Check client status if active
            if self.client and hasattr(self.client, 'is_connected'):
                try:
                    if self.client.is_connected:
                        self.status = self.STATUS_CONNECTED
                        self.qr_code_data_url = None
                except Exception:
                    pass

            return {
                'success': True,
                'provider': 'neonize',
                'status': self.status,
                'connected': self.status == self.STATUS_CONNECTED,
                'phone': self.phone_number,
                'push_name': self.push_name,
                'qr_code': self.qr_code_data_url if self.status == self.STATUS_PAIRING else None,
                'has_qr': bool(self.qr_code_data_url and self.status == self.STATUS_PAIRING),
                'last_active': self.last_active.isoformat() if self.last_active else None,
                'engine': 'Neonize (Whatsmeow Multi-Device)',
                'neonize_available': HAS_NEONIZE
            }

    def start_pairing(self, shop=None, force_refresh=False):
        """
        Initiates WhatsApp Web multi-device pairing.
        Generates or refreshes the QR code for linking personal devices.
        """
        with self._lock:
            if self.status == self.STATUS_CONNECTED and not force_refresh:
                return self.get_status(shop)

            self.status = self.STATUS_PAIRING
            self.last_active = timezone.now()

            # If Neonize is available and not running under Django test runner, launch socket listener in background
            is_testing = 'test' in sys.argv or getattr(settings, 'TESTING', False)
            if HAS_NEONIZE and not is_testing:
                if not self.thread or not self.thread.is_alive():
                    self._start_neonize_thread()

            # Ensure a valid QR data URL is ready for the UI
            if not self.qr_code_data_url:
                # Initial pairing placeholder / handshake token
                timestamp = int(time.time())
                raw_token = f"2@washnlaundry_neonize_{timestamp},washnlaundry_key_{timestamp}"
                self.qr_raw = raw_token
                self.qr_code_data_url = self._generate_qr_data_url(raw_token)

            return self.get_status(shop)

    def _start_neonize_thread(self):
        """Spawns the background client daemon."""
        def run():
            try:
                self.client = NewClient(self._db_path)

                def on_qr_callback(client: NewClient, data_qr: bytes):
                    logger.info("Neonize QR callback received for personal WhatsApp linking")
                    try:
                        self.qr_code_data_url = self._generate_qr_data_url(data_qr)
                        self.status = self.STATUS_PAIRING
                        self.last_active = timezone.now()
                    except Exception as ex:
                        logger.error(f"Error processing QR data: {ex}")

                # Set custom QR handler to prevent Windows console Unicode printing crashes
                self.client.event.qr(on_qr_callback)

                @self.client.event(ConnectedEv)
                def on_connected(client: NewClient, event: ConnectedEv):
                    logger.info("Personal WhatsApp linked successfully via Neonize")
                    self.status = self.STATUS_CONNECTED
                    self.qr_code_data_url = None
                    self.last_active = timezone.now()
                    try:
                        me = client.get_me()
                        if me:
                            self.phone_number = getattr(me, 'User', None) or getattr(me, 'phone', None)
                            self.push_name = getattr(me, 'PushName', None) or "Personal WhatsApp"
                    except Exception as e:
                        logger.warning(f"Could not fetch device info: {e}")

                @self.client.event(DisconnectedEv)
                def on_disconnect(client: NewClient, event: DisconnectedEv):
                    logger.warning("Personal WhatsApp disconnected")
                    self.status = self.STATUS_DISCONNECTED

                @self.client.event(LoggedOutEv)
                def on_logged_out(client: NewClient, event: LoggedOutEv):
                    logger.warning("Personal WhatsApp logged out from phone")
                    self.status = self.STATUS_DISCONNECTED
                    self.phone_number = None
                    self.push_name = None

                logger.info("Connecting Neonize client to WhatsApp WebSocket servers...")
                self.client.connect()
            except Exception as e:
                logger.error(f"Neonize client thread encountered an exception: {e}")
                self.status = self.STATUS_DISCONNECTED

        self.thread = threading.Thread(target=run, daemon=True, name="NeonizeWhatsAppDaemon")
        self.thread.start()

    def disconnect(self, shop=None):
        """Disconnects or unlinks the personal WhatsApp number."""
        with self._lock:
            try:
                if self.client and hasattr(self.client, 'disconnect'):
                    self.client.disconnect()
            except Exception as e:
                logger.warning(f"Error during neonize disconnect: {e}")

            self.status = self.STATUS_DISCONNECTED
            self.phone_number = None
            self.push_name = None
            self.qr_code_data_url = None
            self.qr_raw = None
            self.last_active = timezone.now()

            return {
                'success': True,
                'message': 'Personal WhatsApp disconnected successfully.',
                'status': self.STATUS_DISCONNECTED
            }

    def send_message(self, to_number: str, text: str, shop=None, recipient_name=None):
        """Sends a message via personal WhatsApp if connected."""
        digits = "".join(ch for ch in str(to_number) if ch.isdigit())
        ten_digit_phone = digits[-10:] if len(digits) >= 10 else digits
        wa_destination = f"91{ten_digit_phone}" if len(ten_digit_phone) == 10 and not digits.startswith('91') else digits

        if self.status == self.STATUS_CONNECTED and self.client:
            try:
                jid = f"{wa_destination}@s.whatsapp.net"
                msg_id = self.client.send_message(jid, text)
                return {
                    'success': True,
                    'message_id': str(msg_id) if msg_id else f"neonize_{int(time.time()*1000)}",
                    'simulated': False,
                    'provider': 'neonize'
                }
            except Exception as e:
                logger.error(f"Failed to dispatch via Neonize: {e}")

        return {
            'success': False,
            'error': 'Personal WhatsApp is not connected via Neonize. Please scan QR first.'
        }
