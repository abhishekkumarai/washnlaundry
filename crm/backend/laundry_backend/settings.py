import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

try:
    from dotenv import load_dotenv
    for p in [BASE_DIR.parent / '.env', BASE_DIR.parent.parent / '.env', BASE_DIR / '.env']:
        if p.exists():
            load_dotenv(p)
except ImportError:
    pass

_INSECURE_SECRET_KEY = 'django-insecure-laundrybill-crm-secret-key-super-secure'
SECRET_KEY = os.environ.get('SECRET_KEY', _INSECURE_SECRET_KEY)

DEBUG = os.environ.get('DEBUG', 'True') == 'True'

ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '*').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'api',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'api.middleware.TenantMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'laundry_backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'laundry_backend.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# Production (Render) points this at the Neon Postgres `washnlaundry-db`; unset
# keeps local dev on SQLite. Deliberately NOT the generic
# DATABASE_URL: this machine has a machine-wide DATABASE_URL belonging to
# another project, which would silently hijack a local `runserver`.
if os.environ.get('DJANGO_DATABASE_URL'):
    import dj_database_url

    DATABASES['default'] = dj_database_url.parse(
        os.environ['DJANGO_DATABASE_URL'],
        conn_max_age=600,
        conn_health_checks=True,
        ssl_require=os.environ.get('DJANGO_DATABASE_SSL', 'True') != 'False',
    )

AUTH_PASSWORD_VALIDATORS = []

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Kolkata'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STORAGES = {
    'staticfiles': {
        'BACKEND': 'whitenoise.storage.CompressedManifestStaticFilesStorage',
    },
}
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

from corsheaders.defaults import default_headers

CORS_ALLOW_ALL_ORIGINS = os.environ.get('CORS_ALLOW_ALL_ORIGINS', 'True') == 'True'
CORS_ALLOWED_ORIGINS = [
    origin for origin in os.environ.get('CORS_ALLOWED_ORIGINS', '').split(',') if origin
]
CORS_ALLOW_HEADERS = list(default_headers) + [
    'x-tenant-id',
]
CORS_EXPOSE_HEADERS = [
    'x-tenant-id',
]

# ── RAG Chat (Cloudflare Workers AI + Vectorize, KAN-112) ─────────────────────
# The worker's RAG_API_KEY is a secret and must never reach the public Flutter
# web bundle, so the backend proxies /api/rag/chat/ and attaches it here.
RAG_WORKER_URL = os.environ.get(
    'RAG_WORKER_URL', 'https://washnlaundry-crm-rag.abhishekkumarai.workers.dev'
)
RAG_API_KEY = os.environ.get('RAG_API_KEY', '')

# Website-chat booking leads are emailed through Resend's HTTPS API (Render's
# free tier blocks outbound SMTP). Without RESEND_API_KEY leads are still saved
# and stay PENDING; the 15-minute cron retries them once a key is set.
RESEND_API_KEY = os.environ.get('RESEND_API_KEY', '')
LEAD_EMAIL_TO = [
    e.strip() for e in os.environ.get(
        'LEAD_EMAIL_TO', 'washnlaundry01@gmail.com,emailabhishek2@gmail.com'
    ).split(',') if e.strip()
]
def _clean_from_email(val, default='WashNLaundry <noreply@washnlaundry.com>'):
    v = (val or '').strip()
    if not v:
        return default
    lower = v.lower()
    if any(d in lower for d in ['@gmail.com', '@yahoo.com', '@hotmail.com', '@outlook.com']):
        return default
    return v


LEAD_EMAIL_FROM = _clean_from_email(os.environ.get('LEAD_EMAIL_FROM'))

# Browser origins allowed to call the public (no-secret) pickup-form endpoint
# /api/leads/public/, and how many submissions one IP may make per hour.
PUBLIC_LEAD_ORIGINS = [
    o.strip() for o in os.environ.get(
        'PUBLIC_LEAD_ORIGINS',
        'https://washnlaundry-web.abhishekkumarai.workers.dev,'
        'https://washnlaundry.com,https://www.washnlaundry.com,'
        'https://customer.washnlaundry.com',
    ).split(',') if o.strip()
]
# Google OAuth web client ID the customer portal's ID tokens are verified against.
GOOGLE_CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID', '')
PUBLIC_LEAD_RATE_PER_HOUR = int(os.environ.get('PUBLIC_LEAD_RATE_PER_HOUR', '5'))


# ── API auth (api/auth.py) ────────────────────────────────────────────────────
# When True every /api/ DRF endpoint requires a Google ID token belonging to
# staff; the customer portal's /api/customer/* views are scoped to the caller.
# Off by default so the Flutter app (which must send tokens first) can roll out
# before the API is locked down; turn on in Render once it has.
API_AUTH_ENFORCED = os.environ.get('API_AUTH_ENFORCED', 'False') == 'True'
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': ['api.auth.GoogleTokenAuthentication'],
    'DEFAULT_PERMISSION_CLASSES': ['api.auth.IsStaff'],
    'DEFAULT_THROTTLE_RATES': {'shop_provision': '20/hour'},
}

# ── Email + password sign-in (api/password_auth.py) ───────────────────────────
# Session and email-link tokens are signed with SECRET_KEY, so password sign-in
# refuses to run on the public default key: anyone could forge a token for the
# owner's email. Set SECRET_KEY in the environment to enable it.
PASSWORD_AUTH_ENABLED = SECRET_KEY != _INSECURE_SECRET_KEY
PASSWORD_RESET_TIMEOUT = 3600  # seconds a reset link stays valid
# Sender for verification / reset emails.
AUTH_EMAIL_FROM = _clean_from_email(os.environ.get('AUTH_EMAIL_FROM'), default=LEAD_EMAIL_FROM)
# Front-end origins the verify / reset links in emails may point at. A link goes
# back to the origin the request came from (so a customer who signs up on
# customer.washnlaundry.com gets a customer.washnlaundry.com link), provided it
# is listed here; http://localhost:<port> is also accepted when DEBUG is on.
APP_ORIGINS = [
    o.strip() for o in os.environ.get(
        'APP_ORIGINS',
        'https://app.washnlaundry.com,https://customer.washnlaundry.com',
    ).split(',') if o.strip()
]
# Used when the request carries no allowed origin (curl, a server-to-server
# call). Unset: localhost while DEBUG is on, otherwise the first APP_ORIGINS
# entry. Set it explicitly in each environment.
APP_BASE_URL = os.environ.get('APP_BASE_URL') or (
    'http://localhost:5055' if DEBUG else (APP_ORIGINS[0] if APP_ORIGINS else '')
)

# ── Meta / Instagram Graph API (KAN-142) ────────────────────────────────────
META_APP_ID = os.environ.get('META_APP_ID', '')
META_APP_SECRET = os.environ.get('META_APP_SECRET', '')
META_USER_ACCESS_TOKEN = os.environ.get('META_USER_ACCESS_TOKEN', '')
META_PAGE_ACCESS_TOKEN = os.environ.get('META_PAGE_ACCESS_TOKEN', '')
META_FACEBOOK_PAGE_ID = os.environ.get('META_FACEBOOK_PAGE_ID', '')
META_FACEBOOK_PAGE_NAME = os.environ.get('META_FACEBOOK_PAGE_NAME', 'Washnlaundry')
META_INSTAGRAM_ACCOUNT_ID = os.environ.get('META_INSTAGRAM_ACCOUNT_ID', '')
META_INSTAGRAM_USERNAME = os.environ.get('META_INSTAGRAM_USERNAME', 'washnlaundrydotcom')
META_BUSINESS_ID = os.environ.get('META_BUSINESS_ID', '')
META_GRAPH_ACCESS_TOKEN = META_PAGE_ACCESS_TOKEN or META_USER_ACCESS_TOKEN

# Most shops one account may own (self-service provisioning).
MAX_SHOPS_PER_USER = int(os.environ.get('MAX_SHOPS_PER_USER', '5'))

