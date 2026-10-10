"""Storage for order photos/videos, behind one interface.

Default: the database (a `bytea` column in OrderMediaBlob). Render's own disk is
ephemeral, so the Postgres database is the only durable place the backend has
without extra services. Files go up through the API, so the caps below are kept
small to bound memory on a small Render instance and growth of the database.

Optional: Cloudflare R2 (S3-compatible), selected when all of R2_ACCOUNT_ID,
R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY and R2_MEDIA_BUCKET are set. The browser
then uploads straight to a presigned URL, bypassing Django and the Cloudflare
proxy Worker, and the larger caps apply. The bucket needs a CORS rule allowing
PUT/GET/HEAD from the app origins (see crm/CLAUDE.md).
"""
import os
import uuid

from django.conf import settings
from django.core import signing

# content type -> file extension. HEIC is deliberately absent: Flutter web cannot
# decode it, and iOS Safari converts photos to JPEG on pick.
ALLOWED_TYPES = {
    'image/jpeg': ('IMAGE', '.jpg'),
    'image/png': ('IMAGE', '.png'),
    'image/webp': ('IMAGE', '.webp'),
    'video/mp4': ('VIDEO', '.mp4'),
    'video/quicktime': ('VIDEO', '.mov'),
    'video/webm': ('VIDEO', '.webm'),
}

MB = 1024 * 1024
# Database storage keeps files small; R2 can take bigger ones.
_DB_IMAGE_MB, _DB_VIDEO_MB = 8, 25
_R2_IMAGE_MB, _R2_VIDEO_MB = 10, 50
MAX_FILES_PER_ORDER = 12
MAX_VIDEOS_PER_ORDER = 3

UPLOAD_TTL_SECONDS = 15 * 60
READ_TTL_SECONDS = 60 * 60
_READ_TOKEN_SALT = 'order-media-read'


def max_bytes_for(kind):
    on_r2 = r2_configured()
    default_mb = (_R2_VIDEO_MB if on_r2 else _DB_VIDEO_MB) if kind == 'VIDEO' else \
        (_R2_IMAGE_MB if on_r2 else _DB_IMAGE_MB)
    env = os.environ.get('MEDIA_MAX_VIDEO_MB' if kind == 'VIDEO' else 'MEDIA_MAX_IMAGE_MB')
    return int(env or default_mb) * MB


def new_storage_key(shop_id, content_type):
    ext = ALLOWED_TYPES[content_type][1]
    return f'orders/{shop_id}/{uuid.uuid4().hex}{ext}'


def r2_configured():
    return all(os.environ.get(k) for k in (
        'R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_MEDIA_BUCKET'))


class R2Storage:
    name = 'r2'

    def __init__(self):
        import boto3
        from botocore.config import Config
        self.bucket = os.environ['R2_MEDIA_BUCKET']
        self.client = boto3.client(
            's3',
            endpoint_url=f"https://{os.environ['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com",
            aws_access_key_id=os.environ['R2_ACCESS_KEY_ID'],
            aws_secret_access_key=os.environ['R2_SECRET_ACCESS_KEY'],
            config=Config(signature_version='s3v4'),
            region_name='auto',
        )

    def upload_target(self, media, request=None):
        url = self.client.generate_presigned_url(
            'put_object',
            Params={'Bucket': self.bucket, 'Key': media.storage_key, 'ContentType': media.content_type},
            ExpiresIn=UPLOAD_TTL_SECONDS,
        )
        return {'url': url, 'method': 'PUT', 'headers': {'Content-Type': media.content_type}}

    def read_url(self, media, request=None):
        return self.client.generate_presigned_url(
            'get_object',
            Params={'Bucket': self.bucket, 'Key': media.storage_key},
            ExpiresIn=READ_TTL_SECONDS,
        )

    def stored_size(self, media):
        from botocore.exceptions import ClientError
        try:
            return self.client.head_object(Bucket=self.bucket, Key=media.storage_key)['ContentLength']
        except ClientError:
            return None

    def delete(self, media):
        try:
            self.client.delete_object(Bucket=self.bucket, Key=media.storage_key)
        except Exception:
            pass


class DatabaseStorage:
    """Bytes in a Postgres `bytea` column (OrderMediaBlob) - no object store needed.

    Uploads go through the API (PUT .../content/) and are served by it with HTTP
    Range support. Fine for a modest shop; it makes the database grow with every
    photo, so use `purge_old_media` and switch to R2 when volume justifies it.
    """
    name = 'database'

    def upload_target(self, media, request=None):
        # Relative on purpose: behind the Cloudflare proxy Django sees the Render
        # hostname, and an absolute URL built from it would bypass the proxy.
        # The client resolves it against its own API base.
        url = f'/api/order-media/{media.id}/content/'
        return {'url': url, 'method': 'PUT', 'headers': {'Content-Type': media.content_type}}

    def read_url(self, media, request=None):
        token = signing.dumps({'m': str(media.id)}, salt=_READ_TOKEN_SALT)
        return f'/api/order-media/{media.id}/file/?t={token}'

    @staticmethod
    def check_token(media_id, token):
        try:
            data = signing.loads(token or '', salt=_READ_TOKEN_SALT, max_age=READ_TTL_SECONDS)
        except signing.BadSignature:
            return False
        return data.get('m') == str(media_id)

    def write(self, media, chunks):
        from .models import OrderMediaBlob
        data = b''.join(chunks)
        OrderMediaBlob.objects.update_or_create(media=media, defaults={'data': data})

    def stored_size(self, media):
        from django.db.models.functions import Length
        from .models import OrderMediaBlob
        row = OrderMediaBlob.objects.filter(pk=media.pk).values_list(Length('data'), flat=True).first()
        return row

    def read_range(self, media, start, end):
        """Bytes start..end inclusive, sliced in SQL so the whole file is not loaded."""
        from django.db.models import BinaryField
        from django.db.models.functions import Substr
        from .models import OrderMediaBlob
        chunk = OrderMediaBlob.objects.filter(pk=media.pk).annotate(
            part=Substr('data', start + 1, end - start + 1, output_field=BinaryField())
        ).values_list('part', flat=True).first()
        return bytes(chunk) if chunk is not None else b''

    def delete(self, media):
        from .models import OrderMediaBlob
        OrderMediaBlob.objects.filter(pk=media.pk).delete()


def get_storage():
    return R2Storage() if r2_configured() else DatabaseStorage()
