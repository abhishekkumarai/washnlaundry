"""Upload slots, verification and serving for order photos/videos."""
import re

from django.http import Http404, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from . import media_storage as ms
from .auth import IsStaff
from .models import OrderMedia
from .serializers import OrderMediaSerializer
from .tenancy import require_shop

MAX_UNATTACHED_PER_SHOP = 60  # outstanding uploads not yet on any order

# Image/video tags cannot send X-Tenant-ID or Authorization, so this path is
# authorised by a short-lived signed token instead (see media_file).
FILE_PATH_RE = re.compile(r'^/api/order-media/[0-9a-fA-F-]{36}/file/$')


def _get_media(media_id):
    try:
        return OrderMedia.objects.get(pk=media_id)  # tenant-scoped manager
    except OrderMedia.DoesNotExist:
        raise Http404


@api_view(['POST'])
@permission_classes([IsStaff])
def media_create(request):
    """POST /api/order-media/ {filename, content_type, size} -> upload slot."""
    content_type = str(request.data.get('content_type') or '').lower().strip()
    if content_type not in ms.ALLOWED_TYPES:
        return Response({'detail': 'Only JPEG, PNG, WebP photos and MP4, MOV, WebM videos are allowed.'},
                        status=400)
    kind = ms.ALLOWED_TYPES[content_type][0]
    try:
        size = int(request.data.get('size'))
    except (TypeError, ValueError):
        return Response({'detail': 'File size is required.'}, status=400)
    limit = ms.max_bytes_for(kind)
    if size <= 0 or size > limit:
        mb = limit // ms.MB
        return Response({'detail': f'{kind.title()}s can be at most {mb} MB.'}, status=400)

    shop = require_shop()
    if OrderMedia.objects.filter(order__isnull=True).count() >= MAX_UNATTACHED_PER_SHOP:
        return Response({'detail': 'Too many pending uploads. Place or clear the current order first.'},
                        status=429)

    media = OrderMedia.objects.create(
        shop=shop,
        kind=kind,
        content_type=content_type,
        original_name=str(request.data.get('filename') or '')[:255],
        size=size,
        storage_key=ms.new_storage_key(shop.id, content_type),
        created_by=getattr(request.user, 'email', '') or '',
    )
    storage = ms.get_storage()
    data = OrderMediaSerializer(media, context={'request': request}).data
    return Response({**data, 'upload': storage.upload_target(media, request)}, status=201)


@csrf_exempt
@api_view(['PUT'])
@permission_classes([IsStaff])
def media_content(request, media_id):
    """PUT /api/order-media/<id>/content/ - raw bytes into the database. Not used
    with R2, where the browser uploads straight to the presigned URL instead."""
    storage = ms.get_storage()
    if storage.name != 'database':
        raise Http404
    media = _get_media(media_id)
    if media.status != OrderMedia.PENDING:
        return Response({'detail': 'This upload is already complete.'}, status=409)
    limit = ms.max_bytes_for(media.kind)

    def chunks():
        total = 0
        raw = request._request
        while True:
            chunk = raw.read(64 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > limit:
                raise ValueError('too large')
            yield chunk

    try:
        storage.write(media, chunks())
    except ValueError:
        storage.delete(media)
        return Response({'detail': 'File is too large.'}, status=413)
    return HttpResponse(status=204)


@api_view(['POST'])
@permission_classes([IsStaff])
def media_complete(request, media_id):
    """POST /api/order-media/<id>/complete/ - verify the stored object, mark READY."""
    media = _get_media(media_id)
    storage = ms.get_storage()
    size = storage.stored_size(media)
    if not size:
        return Response({'detail': 'Upload not found. Try again.'}, status=400)
    if size > ms.max_bytes_for(media.kind):
        storage.delete(media)
        media.delete()
        return Response({'detail': 'File is too large.'}, status=400)
    media.size = size
    media.status = OrderMedia.READY
    media.save(update_fields=['size', 'status'])
    return Response(OrderMediaSerializer(media, context={'request': request}).data)


@api_view(['DELETE'])
@permission_classes([IsStaff])
def media_delete(request, media_id):
    media = _get_media(media_id)
    ms.get_storage().delete(media)
    media.delete()
    return Response(status=204)


_RANGE_RE = re.compile(r'^bytes=(\d*)-(\d*)$')


def media_file(request, media_id):
    """GET /api/order-media/<id>/file/?t=<token> - database storage only (R2 uses presigned URLs).

    Honours HTTP Range: Safari will not play a <video> unless the server answers
    byte-range requests, and it lets every browser seek without a full download.
    """
    storage = ms.get_storage()
    if storage.name != 'database' or not storage.check_token(media_id, request.GET.get('t')):
        raise Http404
    try:
        media = OrderMedia.all_objects.get(pk=media_id, status=OrderMedia.READY)
    except OrderMedia.DoesNotExist:
        raise Http404
    total = storage.stored_size(media)
    if not total:
        raise Http404

    start, end, status = 0, total - 1, 200
    header = request.headers.get('Range')
    if header:
        m = _RANGE_RE.match(header.strip())
        if not m or (m.group(1) == '' and m.group(2) == ''):
            return HttpResponse(status=416, headers={'Content-Range': f'bytes */{total}'})
        if m.group(1) == '':  # suffix range: the last N bytes
            start = max(total - int(m.group(2)), 0)
        else:
            start = int(m.group(1))
            if m.group(2):
                end = min(int(m.group(2)), total - 1)
        if start >= total or start > end:
            return HttpResponse(status=416, headers={'Content-Range': f'bytes */{total}'})
        status = 206

    body = storage.read_range(media, start, end)
    response = HttpResponse(body, status=status, content_type=media.content_type)
    response['Accept-Ranges'] = 'bytes'
    response['Cache-Control'] = 'private, max-age=3600'
    if status == 206:
        response['Content-Range'] = f'bytes {start}-{end}/{total}'
    return response
