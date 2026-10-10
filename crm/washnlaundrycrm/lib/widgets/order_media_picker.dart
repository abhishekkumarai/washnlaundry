import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/order_media_model.dart';
import '../services/api_service.dart';
import '../services/order_media_uploader.dart';

/// A file chosen by the user, before it is validated or uploaded.
class PickedMedia {
  final String name;
  final Uint8List bytes;
  const PickedMedia(this.name, this.bytes);
}

enum MediaDraftStatus { uploading, ready, failed }

/// One file in the review step's list.
class MediaDraft {
  final int localId;
  final String name;
  final String mime;
  final Uint8List bytes;
  MediaDraftStatus status = MediaDraftStatus.uploading;
  OrderMediaModel? media;
  String? error;

  MediaDraft(this.localId, this.name, this.mime, this.bytes);

  bool get isVideo => MediaRules.isVideoMime(mime);
}

/// State of the photos/videos being attached to the order that is being built.
///
/// Files upload as soon as they are picked, so "Place order" only has to send
/// their ids. The order screen blocks on [isUploading] / [hasFailed].
class OrderMediaController extends ChangeNotifier {
  OrderMediaController({OrderMediaBackend backend = const ApiOrderMediaBackend()})
      : _backend = backend;

  final OrderMediaBackend _backend;
  final List<MediaDraft> drafts = [];
  int _nextId = 1;
  bool _disposed = false;

  bool get isUploading =>
      drafts.any((d) => d.status == MediaDraftStatus.uploading);
  bool get hasFailed => drafts.any((d) => d.status == MediaDraftStatus.failed);
  List<String> get readyIds => [
        for (final d in drafts)
          if (d.status == MediaDraftStatus.ready && d.media != null) d.media!.id,
      ];
  int get count => drafts.length;
  bool get isFull => drafts.length >= MediaRules.maxFilesPerOrder;

  /// Why [file] can't be added, or null if it can. Checked before uploading so a
  /// bad file never costs a round trip.
  String? rejectionFor(PickedMedia file) {
    final mime = MediaRules.mimeFor(file.name);
    if (mime == null) {
      return '${file.name}: use a JPEG, PNG or WebP photo, or an MP4, MOV or WebM video.';
    }
    final isVideo = MediaRules.isVideoMime(mime);
    final limit = isVideo ? MediaRules.maxVideoBytes : MediaRules.maxImageBytes;
    if (file.bytes.isEmpty) return '${file.name}: the file is empty.';
    if (file.bytes.length > limit) {
      return '${file.name}: too large (${OrderMediaModel.formatSize(file.bytes.length)}). '
          '${isVideo ? 'Videos' : 'Photos'} can be at most ${OrderMediaModel.formatSize(limit)}.';
    }
    if (drafts.length >= MediaRules.maxFilesPerOrder) {
      return '${file.name}: an order can have at most ${MediaRules.maxFilesPerOrder} photos/videos.';
    }
    if (isVideo &&
        drafts.where((d) => d.isVideo).length >= MediaRules.maxVideosPerOrder) {
      return '${file.name}: an order can have at most ${MediaRules.maxVideosPerOrder} videos.';
    }
    return null;
  }

  /// Validates and uploads [files]. Returns one message per rejected file.
  Future<List<String>> addFiles(List<PickedMedia> files) async {
    final rejected = <String>[];
    final accepted = <MediaDraft>[];
    for (final file in files) {
      final problem = rejectionFor(file);
      if (problem != null) {
        rejected.add(problem);
        continue;
      }
      final draft = MediaDraft(
          _nextId++, file.name, MediaRules.mimeFor(file.name)!, file.bytes);
      drafts.add(draft);
      accepted.add(draft);
    }
    _notify();
    for (final draft in accepted) {
      await _upload(draft);
    }
    return rejected;
  }

  Future<void> retry(MediaDraft draft) async {
    draft
      ..status = MediaDraftStatus.uploading
      ..error = null;
    _notify();
    await _upload(draft);
  }

  Future<void> remove(MediaDraft draft) async {
    drafts.remove(draft);
    _notify();
    final id = draft.media?.id;
    if (id != null) {
      try {
        await _backend.delete(id);
      } catch (_) {
        // Already off the order; the server sweeps unattached uploads anyway.
      }
    }
  }

  /// Forgets the list after the order is placed. The files now belong to the
  /// order, so nothing is deleted server-side.
  void clear() {
    drafts.clear();
    _notify();
  }

  Future<void> _upload(MediaDraft draft) async {
    try {
      draft.media = await _backend.upload(
          filename: draft.name, contentType: draft.mime, bytes: draft.bytes);
      draft.status = MediaDraftStatus.ready;
    } on ApiException catch (e) {
      draft
        ..status = MediaDraftStatus.failed
        ..error = e.message;
    } catch (e) {
      draft
        ..status = MediaDraftStatus.failed
        ..error = 'Upload failed: $e';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

typedef MediaFilePicker = Future<List<PickedMedia>> Function();

Future<List<PickedMedia>> _pickWithFilePicker() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: MediaRules.extensions,
    allowMultiple: true,
    withData: true,
  );
  if (result == null) return const [];
  return [
    for (final f in result.files)
      if (f.bytes != null) PickedMedia(f.name, f.bytes!),
  ];
}

/// "Photos & videos" block for the New Order review step: pick, preview,
/// retry and remove. Wrap it in the step's card.
class OrderMediaPicker extends StatefulWidget {
  final OrderMediaController controller;

  /// Overridable so tests don't need a platform file dialog.
  final MediaFilePicker pickFiles;

  const OrderMediaPicker({
    super.key,
    required this.controller,
    this.pickFiles = _pickWithFilePicker,
  });

  @override
  State<OrderMediaPicker> createState() => _OrderMediaPickerState();
}

class _OrderMediaPickerState extends State<OrderMediaPicker> {
  List<String> _rejections = const [];

  Future<void> _add() async {
    final picked = await widget.pickFiles();
    if (picked.isEmpty || !mounted) return;
    final rejected = await widget.controller.addFiles(picked);
    if (mounted) setState(() => _rejections = rejected);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record the condition of the garments at drop-off. Photos up to '
              '8 MB, videos up to 25 MB.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final d in c.drafts) _tile(d),
                if (!c.isFull) _addTile(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${c.count} / ${MediaRules.maxFilesPerOrder} files'
              '${c.isUploading ? ' · uploading…' : ''}',
              key: const ValueKey('media-count'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            if (_rejections.isNotEmpty)
              Padding(
                key: const ValueKey('media-rejections'),
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in _rejections)
                      Text(r,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFB91C1C))),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _addTile() {
    return InkWell(
      key: const ValueKey('media-add'),
      onTap: _add,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 22, color: Color(0xFF475569)),
            SizedBox(height: 6),
            Text('Add',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  Widget _tile(MediaDraft d) {
    final failed = d.status == MediaDraftStatus.failed;
    return SizedBox(
      key: ValueKey('media-tile-${d.localId}'),
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: d.isVideo
                ? Container(
                    color: const Color(0xFF1E293B),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_outline_rounded,
                            size: 30, color: Colors.white),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFFCBD5E1))),
                        ),
                      ],
                    ),
                  )
                : Image.memory(d.bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 192,
                    errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Color(0xFF94A3B8)))),
          ),
          if (d.status == MediaDraftStatus.uploading)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (failed)
            InkWell(
              key: ValueKey('media-retry-${d.localId}'),
              onTap: () => widget.controller.retry(d),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                padding: const EdgeInsets.all(6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded,
                            size: 16, color: Color(0xFFB91C1C)),
                        Text(d.error ?? 'Failed',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 9, color: Color(0xFF991B1B))),
                        const Text('Tap to retry',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF991B1B))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              key: ValueKey('media-remove-${d.localId}'),
              onTap: () => widget.controller.remove(d),
              child: Container(
                decoration: const BoxDecoration(
                    color: Color(0xCC0F172A), shape: BoxShape.circle),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
