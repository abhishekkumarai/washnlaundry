/// A photo or video attached to an order (garment condition at drop-off).
class OrderMediaModel {
  final String id;

  /// `IMAGE` or `VIDEO`.
  final String kind;
  final String contentType;
  final String name;
  final int size;

  /// Short-lived read URL (presigned R2 link, or a signed local link in dev).
  /// Null until the upload has been verified.
  final String? url;

  const OrderMediaModel({
    required this.id,
    required this.kind,
    this.contentType = '',
    this.name = '',
    this.size = 0,
    this.url,
  });

  bool get isVideo => kind == 'VIDEO';
  bool get isImage => kind == 'IMAGE';

  factory OrderMediaModel.fromJson(Map<String, dynamic> json) => OrderMediaModel(
        id: json['id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? 'IMAGE',
        contentType: json['content_type']?.toString() ?? '',
        name: json['original_name']?.toString() ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        url: json['url']?.toString(),
      );

  /// "1.2 MB" / "340 KB".
  static String formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }
}

/// What the server accepts, mirrored from `media_storage.py` so the picker can
/// refuse a bad file before spending an upload on it.
class MediaRules {
  const MediaRules._();

  static const maxImageBytes = 8 * 1024 * 1024;
  static const maxVideoBytes = 25 * 1024 * 1024;
  static const maxFilesPerOrder = 12;
  static const maxVideosPerOrder = 3;

  /// File extension (lower case, no dot) -> MIME type.
  static const mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
  };

  static List<String> get extensions => mimeByExtension.keys.toList();

  static String? mimeFor(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0) return null;
    return mimeByExtension[filename.substring(dot + 1).toLowerCase()];
  }

  static bool isVideoMime(String mime) => mime.startsWith('video/');
}
