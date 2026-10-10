"""Order photos/videos: upload slot -> upload -> verify -> attach to the order."""
from datetime import timedelta
from io import StringIO
from unittest import mock

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from api import media_storage as ms
from api.models import Order, OrderMedia, OrderMediaBlob, Shop
from api.tenancy import tenant_context

JPEG = b'\xff\xd8\xff\xe0' + b'0' * 2048


class OrderMediaApiTests(TestCase):
    def setUp(self):
        self.shop = Shop.objects.create(name='Media Shop', slug='media-shop')
        self.other = Shop.objects.create(name='Other Shop', slug='other-shop')
        self.client = APIClient()
        self.hdr = {'HTTP_X_TENANT_ID': 'media-shop'}

    def upload(self, content=JPEG, content_type='image/jpeg', name='a.jpg', hdr=None):
        hdr = hdr or self.hdr
        res = self.client.post('/api/order-media/', {
            'filename': name, 'content_type': content_type, 'size': len(content)},
            format='json', **hdr)
        self.assertEqual(res.status_code, 201, res.content)
        slot = res.json()
        put = self.client.generic('PUT', slot['upload']['url'], content,
                                  content_type=content_type, **hdr)
        self.assertEqual(put.status_code, 204, put.content)
        done = self.client.post(f"/api/order-media/{slot['id']}/complete/", **hdr)
        self.assertEqual(done.status_code, 200, done.content)
        return done.json()

    def order_payload(self, **extra):
        return {'customer_name': 'Walk-in', 'items': [], **extra}

    # ── happy path ───────────────────────────────────────────────────────────
    def test_upload_verify_and_attach_to_a_new_order(self):
        photo = self.upload()
        video = self.upload(b'\x00\x00\x00\x18ftypmp42' + b'0' * 4096, 'video/mp4', 'v.mp4')
        self.assertEqual((photo['kind'], photo['status']), ('IMAGE', 'READY'))
        self.assertEqual(video['kind'], 'VIDEO')
        self.assertTrue(photo['url'].startswith('/api/order-media/'))  # relative: the client resolves it

        res = self.client.post('/api/orders/', self.order_payload(media_ids=[photo['id'], video['id']]),
                               format='json', **self.hdr)
        self.assertEqual(res.status_code, 201, res.content)
        media = res.json()['media']
        self.assertEqual({m['kind'] for m in media}, {'IMAGE', 'VIDEO'})
        # and they come back when the order is read again
        again = self.client.get(f"/api/orders/{res.json()['id']}/", **self.hdr).json()
        self.assertEqual(len(again['media']), 2)

    def test_signed_url_serves_the_bytes_without_headers(self):
        photo = self.upload()
        res = APIClient().get(photo['url'])  # no auth, no tenant header: like an <img> tag
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.content, JPEG)
        self.assertEqual(res['Content-Type'], 'image/jpeg')
        self.assertEqual(res['Accept-Ranges'], 'bytes')

    def test_range_requests_for_video_seeking(self):
        data = bytes(range(256)) * 40  # 10,240 bytes
        video = self.upload(data, 'video/mp4', 'v.mp4')
        c = APIClient()
        first = c.get(video['url'], HTTP_RANGE='bytes=0-99')
        self.assertEqual(first.status_code, 206)
        self.assertEqual(first.content, data[:100])
        self.assertEqual(first['Content-Range'], f'bytes 0-99/{len(data)}')
        open_ended = c.get(video['url'], HTTP_RANGE='bytes=10000-')
        self.assertEqual((open_ended.status_code, open_ended.content), (206, data[10000:]))
        suffix = c.get(video['url'], HTTP_RANGE='bytes=-16')
        self.assertEqual((suffix.status_code, suffix.content), (206, data[-16:]))
        clamped = c.get(video['url'], HTTP_RANGE='bytes=10200-99999')
        self.assertEqual((clamped.status_code, clamped.content), (206, data[10200:]))
        past_end = c.get(video['url'], HTTP_RANGE='bytes=20000-')
        self.assertEqual(past_end.status_code, 416)
        self.assertEqual(c.get(video['url'], HTTP_RANGE='bytes=abc').status_code, 416)

    def test_file_url_needs_a_valid_token(self):
        photo = self.upload()
        bare = photo['url'].split('?')[0]
        self.assertEqual(APIClient().get(bare).status_code, 404)
        self.assertEqual(APIClient().get(bare + '?t=forged').status_code, 404)

    # ── validation ───────────────────────────────────────────────────────────
    def test_rejects_disallowed_types_and_oversize(self):
        for ctype in ('image/heic', 'application/pdf', 'text/html', ''):
            res = self.client.post('/api/order-media/', {'filename': 'x', 'content_type': ctype, 'size': 10},
                                   format='json', **self.hdr)
            self.assertEqual(res.status_code, 400, ctype)
        too_big = ms.max_bytes_for('IMAGE') + 1
        res = self.client.post('/api/order-media/', {'filename': 'x.jpg', 'content_type': 'image/jpeg',
                                                     'size': too_big}, format='json', **self.hdr)
        self.assertEqual(res.status_code, 400)
        res = self.client.post('/api/order-media/', {'filename': 'x.jpg', 'content_type': 'image/jpeg',
                                                     'size': 0}, format='json', **self.hdr)
        self.assertEqual(res.status_code, 400)

    def test_upload_larger_than_declared_cap_is_refused(self):
        with mock.patch.object(ms, 'max_bytes_for', return_value=1000):
            res = self.client.post('/api/order-media/', {'filename': 'x.jpg', 'content_type': 'image/jpeg',
                                                         'size': 500}, format='json', **self.hdr)
            slot = res.json()
            big = self.client.generic('PUT', slot['upload']['url'], b'0' * 5000,
                                      content_type='image/jpeg', **self.hdr)
            self.assertEqual(big.status_code, 413)

    def test_complete_without_an_upload_fails(self):
        res = self.client.post('/api/order-media/', {'filename': 'x.jpg', 'content_type': 'image/jpeg',
                                                     'size': 100}, format='json', **self.hdr)
        done = self.client.post(f"/api/order-media/{res.json()['id']}/complete/", **self.hdr)
        self.assertEqual(done.status_code, 400)

    def test_per_order_limits(self):
        ids = [self.upload(name=f'{i}.jpg')['id'] for i in range(ms.MAX_FILES_PER_ORDER + 1)]
        res = self.client.post('/api/orders/', self.order_payload(media_ids=ids), format='json', **self.hdr)
        self.assertEqual(res.status_code, 400)
        vids = [self.upload(b'ftyp' + b'0' * 100, 'video/mp4', f'{i}.mp4')['id']
                for i in range(ms.MAX_VIDEOS_PER_ORDER + 1)]
        res = self.client.post('/api/orders/', self.order_payload(media_ids=vids), format='json', **self.hdr)
        self.assertEqual(res.status_code, 400)

    def test_media_cannot_be_attached_twice(self):
        photo = self.upload()
        first = self.client.post('/api/orders/', self.order_payload(media_ids=[photo['id']]),
                                 format='json', **self.hdr)
        self.assertEqual(first.status_code, 201)
        second = self.client.post('/api/orders/', self.order_payload(media_ids=[photo['id']]),
                                  format='json', **self.hdr)
        self.assertEqual(second.status_code, 400)

    def test_unfinished_upload_cannot_be_attached(self):
        res = self.client.post('/api/order-media/', {'filename': 'x.jpg', 'content_type': 'image/jpeg',
                                                     'size': 100}, format='json', **self.hdr)
        order = self.client.post('/api/orders/', self.order_payload(media_ids=[res.json()['id']]),
                                 format='json', **self.hdr)
        self.assertEqual(order.status_code, 400)

    # ── tenant isolation ─────────────────────────────────────────────────────
    def test_another_shop_cannot_see_attach_or_delete_it(self):
        photo = self.upload()
        other = {'HTTP_X_TENANT_ID': 'other-shop'}
        self.assertEqual(self.client.delete(f"/api/order-media/{photo['id']}/", **other).status_code, 404)
        self.assertEqual(self.client.post(f"/api/order-media/{photo['id']}/complete/", **other).status_code, 404)
        order = self.client.post('/api/orders/', self.order_payload(media_ids=[photo['id']]),
                                 format='json', **other)
        self.assertEqual(order.status_code, 400)
        self.assertTrue(OrderMedia.all_objects.filter(pk=photo['id']).exists())

    def test_storage_keys_are_prefixed_by_shop(self):
        photo = self.upload()
        key = OrderMedia.all_objects.get(pk=photo['id']).storage_key
        self.assertTrue(key.startswith(f'orders/{self.shop.id}/'), key)

    # ── delete & cleanup ─────────────────────────────────────────────────────
    def test_delete_removes_row_and_bytes(self):
        photo = self.upload()
        self.assertTrue(OrderMediaBlob.objects.filter(pk=photo['id']).exists())
        self.assertEqual(self.client.delete(f"/api/order-media/{photo['id']}/", **self.hdr).status_code, 204)
        self.assertFalse(OrderMediaBlob.objects.filter(pk=photo['id']).exists())
        self.assertFalse(OrderMedia.all_objects.filter(pk=photo['id']).exists())

    def test_purge_orphan_media_only_removes_old_unattached(self):
        orphan = self.upload()
        kept = self.upload(name='kept.jpg')
        self.client.post('/api/orders/', self.order_payload(media_ids=[kept['id']]), format='json', **self.hdr)
        OrderMedia.all_objects.update(created_at=timezone.now() - timedelta(hours=48))
        call_command('purge_orphan_media', stdout=StringIO())
        self.assertFalse(OrderMedia.all_objects.filter(pk=orphan['id']).exists())
        self.assertTrue(OrderMedia.all_objects.filter(pk=kept['id']).exists())

    def test_purge_old_media_removes_files_of_long_closed_orders(self):
        from api.models import OrderStatus
        old = self.upload(name='old.jpg')
        fresh = self.upload(name='fresh.jpg')
        o1 = self.client.post('/api/orders/', self.order_payload(media_ids=[old['id']]), format='json', **self.hdr).json()
        o2 = self.client.post('/api/orders/', self.order_payload(media_ids=[fresh['id']]), format='json', **self.hdr).json()
        Order.all_objects.filter(pk=o1['id']).update(
            status=OrderStatus.DELIVERED, delivered_at=timezone.now() - timedelta(days=45))
        Order.all_objects.filter(pk=o2['id']).update(
            status=OrderStatus.DELIVERED, delivered_at=timezone.now() - timedelta(days=2))
        call_command('purge_old_media', stdout=StringIO())
        self.assertFalse(OrderMedia.all_objects.filter(pk=old['id']).exists())
        self.assertFalse(OrderMediaBlob.objects.filter(pk=old['id']).exists())
        self.assertTrue(OrderMedia.all_objects.filter(pk=fresh['id']).exists())

    def test_listing_orders_does_not_load_file_bytes(self):
        photo = self.upload()
        self.client.post('/api/orders/', self.order_payload(media_ids=[photo['id']]), format='json', **self.hdr)
        from django.db import connection
        from django.test.utils import CaptureQueriesContext
        with CaptureQueriesContext(connection) as ctx:
            self.client.get('/api/orders/', **self.hdr)
        self.assertFalse(any('api_ordermediablob' in q['sql'] for q in ctx.captured_queries))

    def test_media_is_deleted_with_its_order(self):
        photo = self.upload()
        res = self.client.post('/api/orders/', self.order_payload(media_ids=[photo['id']]),
                               format='json', **self.hdr)
        with tenant_context(self.shop):
            Order.objects.get(pk=res.json()['id']).delete()
        self.assertFalse(OrderMedia.all_objects.filter(pk=photo['id']).exists())


class R2StorageTests(TestCase):
    """The production path: presigned URLs, no bytes through Django."""

    ENV = {'R2_ACCOUNT_ID': 'acct', 'R2_ACCESS_KEY_ID': 'k', 'R2_SECRET_ACCESS_KEY': 's',
           'R2_MEDIA_BUCKET': 'wnl-media'}

    def test_r2_is_chosen_only_when_fully_configured(self):
        self.assertEqual(ms.get_storage().name, 'database')
        with mock.patch.dict('os.environ', self.ENV):
            self.assertEqual(ms.get_storage().name, 'r2')
        with mock.patch.dict('os.environ', {**self.ENV, 'R2_MEDIA_BUCKET': ''}):
            self.assertEqual(ms.get_storage().name, 'database')

    def test_presigned_urls_point_at_r2_not_django(self):
        shop = Shop.objects.create(name='R2 Shop', slug='r2-shop')
        media = OrderMedia(id='11111111-1111-1111-1111-111111111111', shop=shop, kind='IMAGE',
                           content_type='image/jpeg', storage_key=f'orders/{shop.id}/abc.jpg')
        with mock.patch.dict('os.environ', self.ENV):
            storage = ms.get_storage()
            target = storage.upload_target(media)
            read = storage.read_url(media)
        self.assertIn('acct.r2.cloudflarestorage.com/wnl-media/', target['url'])
        self.assertEqual(target['method'], 'PUT')
        self.assertEqual(target['headers'], {'Content-Type': 'image/jpeg'})
        self.assertIn('X-Amz-Signature', target['url'])
        self.assertIn('X-Amz-Expires=900', target['url'])
        self.assertIn('acct.r2.cloudflarestorage.com/wnl-media/', read)
        self.assertIn('X-Amz-Expires=3600', read)
