import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// A validated image payload for the provisional `recipe-images` Storage contract.
///
/// The current inferred bucket accepts JPEG, PNG, and WebP up to 10 MiB. Those limits must be
/// reconciled with the authoritative handoff before any deployment. The byte buffer is copied on
/// input and output so it cannot be changed after validation while an upload is in flight.
@immutable
class RecipeImageUpload {
  RecipeImageUpload({
    required Uint8List bytes,
    required String contentType,
  })  : _bytes = _copyAndValidate(bytes),
        contentType = contentType.trim().toLowerCase() {
    if (!_extensionByContentType.containsKey(this.contentType)) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'must be image/jpeg, image/png, or image/webp',
      );
    }
  }

  /// Maximum payload size from the inferred Storage bucket configuration.
  static const int maxBytes = 10 * 1024 * 1024;

  static const Map<String, String> _extensionByContentType = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  static Uint8List _copyAndValidate(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('Recipe images cannot be empty.');
    }
    if (bytes.length > maxBytes) {
      throw ArgumentError('Recipe images must not exceed 10 MiB.');
    }
    return Uint8List.fromList(bytes);
  }

  final Uint8List _bytes;
  final String contentType;

  /// A defensive copy of the image bytes.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  int get byteLength => _bytes.length;

  /// File extension derived from the allowlisted MIME type, never from a user-supplied filename.
  String get extension => _extensionByContentType[contentType]!;
}
