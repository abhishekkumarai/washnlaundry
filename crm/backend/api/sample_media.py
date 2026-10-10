"""Demo photos/videos for seeded orders.

The files in api/seed_media/ are small generated placeholders (garment-condition
shots and a short walk-around clip), committed so seeding needs no extra tools.
They are written through the same storage layer as real uploads, so the app,
gallery and cleanup commands treat them like any other media.
"""
import mimetypes
from pathlib import Path

from . import media_storage as ms
from .models import Order, OrderMedia

SEED_DIR = Path(__file__).resolve().parent / 'seed_media'

PHOTOS = ['shirt_stain.jpg', 'saree_hem.jpg', 'suit_front.jpg', 'shirt_clean.jpg']
VIDEO = 'garment_walkaround.mp4'


def _attach(order, filename):
    path = SEED_DIR / filename
    content_type = mimetypes.guess_type(filename)[0] or 'application/octet-stream'
    kind = ms.ALLOWED_TYPES[content_type][0]
    data = path.read_bytes()
    storage = ms.get_storage()
    media = OrderMedia.all_objects.create(
        shop=order.shop,
        order=order,
        kind=kind,
        content_type=content_type,
        original_name=filename,
        size=len(data),
        storage_key=ms.new_storage_key(order.shop_id, content_type),
        status=OrderMedia.READY,
        created_by='seed',
    )
    if storage.name == 'database':
        storage.write(media, [data])
    else:  # R2: upload for real so the demo orders show up in the bucket too
        storage.client.put_object(Bucket=storage.bucket, Key=media.storage_key,
                                  Body=data, ContentType=content_type)
    return media


def attach_sample_media(shop, limit=10):
    """Give the shop's most recent orders that have no media a few demo files.

    Pattern by position: every order gets 1-3 photos; every third also gets the
    walk-around video. Idempotent - orders that already have media are skipped.
    Returns (orders_touched, files_created).
    """
    orders = (Order.all_objects.filter(shop=shop, media__isnull=True)
              .order_by('-created_at').distinct()[:limit])
    touched = files = 0
    for i, order in enumerate(orders):
        names = [PHOTOS[(i + j) % len(PHOTOS)] for j in range(1 + i % 3)]
        if i % 3 == 0:
            names.append(VIDEO)
        for name in names:
            _attach(order, name)
            files += 1
        touched += 1
    return touched, files
