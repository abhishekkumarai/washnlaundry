import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get(
    'SECRET_KEY', 'django-insecure-laundrybill-crm-secret-key-super-secure'
)

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
# keeps local dev and Docker on SQLite. Deliberately NOT the generic
# DATABASE_URL: this machine has a machine-wide DATABASE_URL belonging to
# another project, which would silently hijack a local `runserver`.
if os.environ.get('DJANGO_DATABASE_URL'):
    import dj_database_url

    DATABASES['default'] = dj_database_url.parse(
        os.environ['DJANGO_DATABASE_URL'],
        conn_max_age=600,
        conn_health_checks=True,
        ssl_require=True,
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

CORS_ALLOW_ALL_ORIGINS = os.environ.get('CORS_ALLOW_ALL_ORIGINS', 'True') == 'True'
CORS_ALLOWED_ORIGINS = [
    origin for origin in os.environ.get('CORS_ALLOWED_ORIGINS', '').split(',') if origin
]

# ── WhatsApp Bridge Configuration (Hermes Stack) ──────────────────────────────
WHATSAPP_BRIDGE_URL = os.environ.get('WHATSAPP_BRIDGE_URL', 'http://127.0.0.1:3000')
WHATSAPP_BRIDGE_TOKEN = os.environ.get('WHATSAPP_BRIDGE_TOKEN', '')
WHATSAPP_DRY_RUN = os.environ.get('WHATSAPP_DRY_RUN', 'True').lower() in ('true', '1', 'yes', 'on')
WHATSAPP_DEFAULT_COUNTRY_CODE = os.environ.get('WHATSAPP_DEFAULT_COUNTRY_CODE', '91')

# ── RAG Chat (Cloudflare Workers AI + Vectorize, KAN-112) ─────────────────────
# The worker's RAG_API_KEY is a secret and must never reach the public Flutter
# web bundle, so the backend proxies /api/rag/chat/ and attaches it here.
RAG_WORKER_URL = os.environ.get(
    'RAG_WORKER_URL', 'https://washnlaundry-rag.abhishekkumarai.workers.dev'
)
RAG_API_KEY = os.environ.get('RAG_API_KEY', '')

