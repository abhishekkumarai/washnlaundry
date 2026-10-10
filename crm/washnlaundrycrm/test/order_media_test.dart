import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/models/order_media_model.dart';
import 'package:washnlaundrycrm/models/order_model.dart';
import 'package:washnlaundrycrm/services/api_service.dart';
import 'package:washnlaundrycrm/services/order_media_uploader.dart';
import 'package:washnlaundrycrm/widgets/order_media_gallery.dart';
import 'package:washnlaundrycrm/widgets/order_media_picker.dart';

class _FakeBackend implements OrderMediaBackend {
  final List<String> uploaded = [];
  final List<String> deleted = [];
  bool failNext = false;
  int _n = 0;

  @override
  Future<OrderMediaModel> upload({
    required String filename,
    required String contentType,
    required Uint8List bytes,
  }) async {
    if (failNext) {
      failNext = false;
      throw ApiException('Upload failed (500).', statusCode: 500);
    }
    uploaded.add(filename);
    _n++;
    return OrderMediaModel(
      id: 'm$_n',
      kind: contentType.startsWith('video/') ? 'VIDEO' : 'IMAGE',
      name: filename,
      size: bytes.length,
      url: 'https://example.test/$filename',
    );
  }

  @override
  Future<void> delete(String mediaId) async => deleted.add(mediaId);
}

PickedMedia _file(String name, {int size = 1000}) =>
    PickedMedia(name, Uint8List(size)..fillRange(0, size, 1));

void main() {
  urlTests();
  group('OrderMediaController', () {
    late _FakeBackend backend;
    late OrderMediaController c;

    setUp(() {
      backend = _FakeBackend();
      c = OrderMediaController(backend: backend);
    });
    tearDown(() => c.dispose());

    test('uploads accepted files and exposes their ids', () async {
      final rejected = await c.addFiles([_file('a.jpg'), _file('clip.MP4')]);
      expect(rejected, isEmpty);
      expect(backend.uploaded, ['a.jpg', 'clip.MP4']);
      expect(c.readyIds, ['m1', 'm2']);
      expect(c.isUploading, isFalse);
      expect(c.drafts[1].isVideo, isTrue);
    });

    test('rejects unsupported types (HEIC, PDF, no extension) without uploading',
        () async {
      final rejected = await c
          .addFiles([_file('iphone.heic'), _file('scan.pdf'), _file('noext')]);
      expect(rejected, hasLength(3));
      expect(rejected.first, contains('iphone.heic'));
      expect(backend.uploaded, isEmpty);
      expect(c.count, 0);
    });

    test('rejects oversized and empty files', () async {
      final rejected = await c.addFiles([
        _file('big.jpg', size: MediaRules.maxImageBytes + 1),
        _file('bigvid.mp4', size: MediaRules.maxVideoBytes + 1),
        PickedMedia('empty.jpg', Uint8List(0)),
      ]);
      expect(rejected, hasLength(3));
      expect(rejected[0], contains('too large'));
      expect(rejected[2], contains('empty'));
      expect(backend.uploaded, isEmpty);
    });

    test('enforces the per-order file and video limits', () async {
      for (var i = 0; i < MediaRules.maxVideosPerOrder; i++) {
        await c.addFiles([_file('v$i.mp4')]);
      }
      final extraVideo = await c.addFiles([_file('v9.mp4')]);
      expect(extraVideo.single, contains('at most ${MediaRules.maxVideosPerOrder} videos'));

      for (var i = 0; c.count < MediaRules.maxFilesPerOrder; i++) {
        await c.addFiles([_file('p$i.jpg')]);
      }
      expect(c.isFull, isTrue);
      final over = await c.addFiles([_file('one-more.jpg')]);
      expect(over.single, contains('at most ${MediaRules.maxFilesPerOrder}'));
    });

    test('a failed upload is kept, blocks submit, and can be retried', () async {
      backend.failNext = true;
      await c.addFiles([_file('a.jpg')]);
      expect(c.hasFailed, isTrue);
      expect(c.readyIds, isEmpty);
      expect(c.drafts.single.error, contains('Upload failed'));

      await c.retry(c.drafts.single);
      expect(c.hasFailed, isFalse);
      expect(c.readyIds, ['m1']);
    });

    test('remove deletes the uploaded file server-side', () async {
      await c.addFiles([_file('a.jpg')]);
      await c.remove(c.drafts.single);
      expect(c.count, 0);
      expect(backend.deleted, ['m1']);
    });

    test('clear (after the order is placed) forgets files without deleting them',
        () async {
      await c.addFiles([_file('a.jpg')]);
      c.clear();
      expect(c.count, 0);
      expect(backend.deleted, isEmpty);
    });
  });

  group('MediaRules', () {
    test('maps extensions to MIME types, case-insensitively', () {
      expect(MediaRules.mimeFor('x.JPG'), 'image/jpeg');
      expect(MediaRules.mimeFor('x.mov'), 'video/quicktime');
      expect(MediaRules.mimeFor('x.heic'), isNull);
      expect(MediaRules.mimeFor('noext'), isNull);
    });
  });

  group('OrderModel.media', () {
    test('parses the media list and defaults to empty', () {
      final base = {
        'id': 'o1',
        'order_number': 'WASH-00001',
        'customer_name': 'A',
        'items': [],
      };
      expect(OrderModel.fromJson(base).media, isEmpty);
      final withMedia = OrderModel.fromJson({
        ...base,
        'media': [
          {'id': 'm1', 'kind': 'IMAGE', 'original_name': 'a.jpg', 'size': 2048, 'url': 'https://x/a'},
          {'id': 'm2', 'kind': 'VIDEO', 'original_name': 'v.mp4', 'size': 5, 'url': null},
        ],
      });
      expect(withMedia.media.map((m) => m.isVideo), [false, true]);
      expect(withMedia.media.first.url, 'https://x/a');
      expect(withMedia.media.last.url, isNull);
    });
  });

  group('OrderMediaPicker widget', () {
    Widget host(OrderMediaController c, MediaFilePicker pick) => MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: OrderMediaPicker(controller: c, pickFiles: pick))),
        );

    testWidgets('Add picks files, shows a tile each and rejections as text',
        (tester) async {
      final c = OrderMediaController(backend: _FakeBackend());
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c, () async => [_file('a.jpg'), _file('b.heic')]));

      expect(find.byKey(const ValueKey('media-count')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('media-add')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('media-tile-1')), findsOneWidget);
      expect(find.textContaining('b.heic'), findsOneWidget);
      expect(find.text('1 / 12 files'), findsOneWidget);
    });

    testWidgets('a failed tile can be retried by tapping it', (tester) async {
      final backend = _FakeBackend()..failNext = true;
      final c = OrderMediaController(backend: backend);
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c, () async => [_file('a.jpg')]));
      await tester.tap(find.byKey(const ValueKey('media-add')));
      await tester.pumpAndSettle();
      expect(find.text('Tap to retry'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('media-retry-1')));
      await tester.pumpAndSettle();
      expect(find.text('Tap to retry'), findsNothing);
      expect(c.readyIds, ['m1']);
    });

    testWidgets('the remove button drops the tile and deletes the upload',
        (tester) async {
      final backend = _FakeBackend();
      final c = OrderMediaController(backend: backend);
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c, () async => [_file('a.jpg')]));
      await tester.tap(find.byKey(const ValueKey('media-add')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('media-remove-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('media-tile-1')), findsNothing);
      expect(backend.deleted, ['m1']);
    });
  });

  group('OrderMediaGallery', () {
    testWidgets('shows a thumbnail per file; videos get a play tile',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: OrderMediaGallery(media: [
            OrderMediaModel(id: 'i1', kind: 'IMAGE', size: 2048, url: 'https://x/i1.jpg'),
            OrderMediaModel(id: 'v1', kind: 'VIDEO', size: 5 * 1024 * 1024, url: 'https://x/v1.mp4'),
            OrderMediaModel(id: 'p1', kind: 'IMAGE', url: null),
          ]),
        ),
      ));
      expect(find.byKey(const ValueKey('media-thumb-i1')), findsOneWidget);
      expect(find.byKey(const ValueKey('media-thumb-v1')), findsOneWidget);
      expect(find.byKey(const ValueKey('media-thumb-p1')), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
      expect(find.text('5.0 MB'), findsOneWidget);
    });
  });
}

void urlTests() {
  group('ApiService.absoluteUrl', () {
    test('leaves absolute (presigned R2) URLs alone', () {
      expect(ApiService.absoluteUrl('https://acct.r2.cloudflarestorage.com/b/k?X-Amz-Signature=1'),
          'https://acct.r2.cloudflarestorage.com/b/k?X-Amz-Signature=1');
    });
    test('resolves server paths against the API base (or stays relative same-origin)', () {
      final out = ApiService.absoluteUrl('/api/order-media/1/file/?t=x');
      expect(out.endsWith('/api/order-media/1/file/?t=x'), isTrue);
      expect(out.contains('//api'), isFalse);
    });
  });
}
