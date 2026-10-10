import 'dart:typed_data';

import '../models/order_media_model.dart';
import 'api_service.dart';

/// The three server calls an upload takes, behind an interface so the picker
/// can be tested without a network.
abstract class OrderMediaBackend {
  /// Asks for an upload slot and sends [bytes] to it; returns the verified media.
  Future<OrderMediaModel> upload({
    required String filename,
    required String contentType,
    required Uint8List bytes,
  });

  Future<void> delete(String mediaId);
}

/// Real implementation: slot -> direct PUT (to R2 in production) -> verify.
class ApiOrderMediaBackend implements OrderMediaBackend {
  const ApiOrderMediaBackend();

  @override
  Future<OrderMediaModel> upload({
    required String filename,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final slot = await ApiService.createMediaSlot(
        filename: filename, contentType: contentType, size: bytes.length);
    final id = slot['id'].toString();
    try {
      await ApiService.putMediaBytes(
          (slot['upload'] as Map).cast<String, dynamic>(), bytes, contentType);
      return await ApiService.completeMedia(id);
    } catch (_) {
      // Don't leave a dead slot behind; the server also sweeps these up later.
      try {
        await ApiService.deleteMedia(id);
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> delete(String mediaId) => ApiService.deleteMedia(mediaId);
}
