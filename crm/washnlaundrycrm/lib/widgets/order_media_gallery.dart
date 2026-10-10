import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/order_media_model.dart';
import '../services/api_service.dart';

/// Thumbnails of an order's photos and videos; tapping one opens it full size.
/// Images load straight from their (signed) URL; videos stream in a dialog.
class OrderMediaGallery extends StatelessWidget {
  final List<OrderMediaModel> media;
  const OrderMediaGallery({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final m in media) _thumb(context, m)],
    );
  }

  Widget _thumb(BuildContext context, OrderMediaModel m) {
    final url = m.url;
    return InkWell(
      key: ValueKey('media-thumb-${m.id}'),
      onTap: url == null ? null : () => _open(context, m),
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 104,
          height: 104,
          child: m.isVideo || url == null
              ? Container(
                  color: const Color(0xFF1E293B),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          m.isVideo
                              ? Icons.play_circle_outline_rounded
                              : Icons.image_not_supported_outlined,
                          size: 32,
                          color: Colors.white),
                      const SizedBox(height: 4),
                      Text(OrderMediaModel.formatSize(m.size),
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFFCBD5E1))),
                    ],
                  ),
                )
              : Image.network(
                  ApiService.absoluteUrl(url),
                  fit: BoxFit.cover,
                  cacheWidth: 208,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Color(0xFF94A3B8))),
                  ),
                ),
        ),
      ),
    );
  }

  void _open(BuildContext context, OrderMediaModel m) {
    showDialog<void>(
      context: context,
      builder: (_) => m.isVideo
          ? _VideoDialog(url: ApiService.absoluteUrl(m.url!), title: m.name)
          : Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  InteractiveViewer(
                    child: Image.network(ApiService.absoluteUrl(m.url!), fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('This photo could not be loaded.',
                                  style: TextStyle(color: Colors.white)),
                            )),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _VideoDialog extends StatefulWidget {
  final String url;
  final String title;
  const _VideoDialog({required this.url, required this.title});

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final VideoPlayerController _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((Object e) {
        if (mounted) setState(() => _error = e);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.value.isInitialized;
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (_error != null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                    'This video could not be played. Try a different browser, '
                    'or download it from the order.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white)),
              )
            else if (!ready)
              const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              )
            else ...[
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              VideoProgressIndicator(_controller, allowScrubbing: true),
              IconButton(
                key: const ValueKey('video-play-pause'),
                icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32),
                onPressed: () => setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
