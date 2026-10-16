import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/data/models/recipe_image_upload.dart';
import 'package:foodcircle/data/repositories/in_memory_recipe_repository.dart';

void main() {
  group('RecipeImageUpload', () {
    test('normalizes the MIME type and derives a safe extension', () {
      final upload = RecipeImageUpload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        contentType: ' IMAGE/JPEG ',
      );

      expect(upload.contentType, 'image/jpeg');
      expect(upload.extension, 'jpg');
      expect(upload.bytes, <int>[1, 2, 3]);
    });

    test('accepts only the provisional JPEG, PNG, and WebP allowlist', () {
      for (final (contentType, extension) in <(String, String)>[
        ('image/jpeg', 'jpg'),
        ('image/png', 'png'),
        ('image/webp', 'webp'),
      ]) {
        final upload = RecipeImageUpload(
          bytes: Uint8List.fromList(<int>[1]),
          contentType: contentType,
        );
        expect(upload.extension, extension);
      }

      expect(
        () => RecipeImageUpload(
          bytes: Uint8List.fromList(<int>[1]),
          contentType: 'image/svg+xml',
        ),
        throwsArgumentError,
      );
    });

    test('copies bytes so callers cannot mutate a validated upload', () {
      final sourceBytes = Uint8List.fromList(<int>[1, 2, 3]);
      final upload = RecipeImageUpload(
        bytes: sourceBytes,
        contentType: 'image/png',
      );
      sourceBytes[0] = 9;
      upload.bytes[1] = 9;

      expect(upload.bytes, <int>[1, 2, 3]);
    });

    test('rejects empty and over-limit payloads', () {
      expect(
        () => RecipeImageUpload(
          bytes: Uint8List(0),
          contentType: 'image/png',
        ),
        throwsArgumentError,
      );
      expect(
        () => RecipeImageUpload(
          bytes: Uint8List(RecipeImageUpload.maxBytes + 1),
          contentType: 'image/png',
        ),
        throwsArgumentError,
      );
    });

    test('allows a payload exactly at the inferred 10 MiB limit', () {
      final upload = RecipeImageUpload(
        bytes: Uint8List(RecipeImageUpload.maxBytes),
        contentType: 'image/webp',
      );

      expect(upload.byteLength, RecipeImageUpload.maxBytes);
    });
  });

  test('in-memory demo refuses to pretend it has persisted an image', () async {
    final repository = InMemoryRecipeRepository.seeded();
    final upload = RecipeImageUpload(
      bytes: Uint8List.fromList(<int>[1]),
      contentType: 'image/png',
    );

    await expectLater(repository.uploadImage(upload), throwsUnsupportedError);
  });
}
