// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:socialmesh/services/protocol/socialmesh/sm_constants.dart';

/// Mirrors the production [_CompressArgs] class from file_transfer_providers.dart.
class _CompressArgs {
  final Uint8List imageBytes;
  final int maxDim;
  final int quality;

  const _CompressArgs({
    required this.imageBytes,
    required this.maxDim,
    required this.quality,
  });
}

/// Mirrors the production [_resizeAndEncodeJpeg] from file_transfer_providers.dart.
/// Must be kept in sync with the real implementation.
Uint8List? _resizeAndEncodeJpeg(_CompressArgs args) {
  try {
    final decoded = img.decodeImage(args.imageBytes);
    if (decoded == null) return null;

    final resized = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? args.maxDim : null,
      height: decoded.height >= decoded.width ? args.maxDim : null,
      interpolation: img.Interpolation.average,
    );

    return Uint8List.fromList(
      img.encodeJpg(
        resized,
        quality: args.quality,
        chroma: img.JpegChroma.yuv420,
      ),
    );
  } catch (_) {
    // Mirror production: the image package can throw RangeError,
    // FormatException, etc. on malformed input.
    return null;
  }
}

/// Mirrors the production pure-Dart JPEG fallback from
/// [FileTransferStateNotifier._compressImagePureDart].
///
/// The primary compression path uses [FlutterImageCompress] for native
/// WebP encoding (tested on-device), but the pure-Dart fallback is what
/// we can unit-test without platform channels. Must be kept in sync.
Uint8List? compressImagePureDart(Uint8List sourceBytes) {
  const dimensions = [160, 128, 96, 80, 64, 48, 32];
  const maxQuality = 85;
  const minQuality = 20;

  for (final dim in dimensions) {
    final smallest = _resizeAndEncodeJpeg(
      _CompressArgs(imageBytes: sourceBytes, maxDim: dim, quality: minQuality),
    );

    if (smallest == null) return null;
    if (smallest.length > SmFileTransferLimits.maxFileSize) continue;

    var lo = minQuality;
    var hi = maxQuality;
    Uint8List best = smallest;

    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final candidate = _resizeAndEncodeJpeg(
        _CompressArgs(imageBytes: sourceBytes, maxDim: dim, quality: mid),
      );

      if (candidate != null &&
          candidate.length <= SmFileTransferLimits.maxFileSize) {
        best = candidate;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    return best;
  }

  return null;
}

/// Creates a synthetic test image encoded as PNG bytes.
Uint8List _createTestImage(int width, int height, {bool noisy = false}) {
  final image = img.Image(width: width, height: height);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (noisy) {
        // Noisy pattern — harder to compress (simulates textured content
        // like the knitted fabric photo that motivated this rework).
        final r = ((x * 37 + y * 53) % 256);
        final g = ((x * 71 + y * 29) % 256);
        final b = ((x * 13 + y * 97) % 256);
        image.setPixelRgb(x, y, r, g, b);
      } else {
        // Smooth gradient — easy to compress.
        final r = (x * 255 ~/ width);
        final g = (y * 255 ~/ height);
        image.setPixelRgb(x, y, r, g, 128);
      }
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('Image compression - pure-Dart JPEG fallback', () {
    test('compresses a small gradient image within 8 KB', () {
      final source = _createTestImage(320, 240);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      expect(
        result!.length,
        lessThanOrEqualTo(SmFileTransferLimits.maxFileSize),
      );
      expect(result.length, greaterThan(0));
    });

    test('compresses a large gradient image within 8 KB', () {
      final source = _createTestImage(1920, 1080);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      expect(
        result!.length,
        lessThanOrEqualTo(SmFileTransferLimits.maxFileSize),
      );
    });

    test('compresses a noisy image within 8 KB', () {
      // Noisy images are harder to compress — this exercises the dimension
      // step-down path where 160px may be too large even at Q20.
      final source = _createTestImage(640, 480, noisy: true);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      expect(
        result!.length,
        lessThanOrEqualTo(SmFileTransferLimits.maxFileSize),
      );
    });

    test('maximizes quality — result is close to the 8 KB ceiling', () {
      // Noisy images are harder to compress and better exercise the binary
      // search — smooth gradients compress so efficiently they may not use
      // much of the budget even at max quality.
      final source = _createTestImage(800, 600, noisy: true);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      // We expect the optimizer to use at least 25% of the budget for a
      // noisy image (i.e. it shouldn't stop at 1 KB when it could push
      // quality higher and still fit in 8 KB).
      expect(
        result!.length,
        greaterThan(SmFileTransferLimits.maxFileSize ~/ 4),
        reason:
            'Binary search should maximize quality, using a meaningful '
            'portion of the budget',
      );
    });

    test('produces valid JPEG output', () {
      final source = _createTestImage(400, 300);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      // JPEG magic bytes: 0xFF 0xD8
      expect(result![0], equals(0xFF));
      expect(result[1], equals(0xD8));

      // Verify the image package can decode the result.
      final decoded = img.decodeJpg(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(160));
      expect(decoded.height, lessThanOrEqualTo(160));
    });

    test('respects dimension constraints', () {
      final source = _createTestImage(2000, 1000);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      final decoded = img.decodeJpg(result!);
      expect(decoded, isNotNull);
      // The largest dimension step is 160, so output should never exceed it.
      expect(decoded!.width, lessThanOrEqualTo(160));
      expect(decoded.height, lessThanOrEqualTo(160));
    });

    test('preserves aspect ratio', () {
      // 2:1 aspect ratio input
      final source = _createTestImage(800, 400);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      final decoded = img.decodeJpg(result!);
      expect(decoded, isNotNull);

      // Width is the longer dimension, so it should be constrained to maxDim.
      // Height should be roughly half of width (2:1 ratio).
      final ratio = decoded!.width / decoded.height;
      expect(ratio, closeTo(2.0, 0.15));
    });

    test('handles square images', () {
      final source = _createTestImage(500, 500);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      final decoded = img.decodeJpg(result!);
      expect(decoded, isNotNull);
      // Square image should remain roughly square.
      expect(decoded!.width, equals(decoded.height));
    });

    test('handles portrait orientation', () {
      // Tall image: 300x600 (1:2 ratio)
      final source = _createTestImage(300, 600);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      final decoded = img.decodeJpg(result!);
      expect(decoded, isNotNull);
      expect(decoded!.height, greaterThan(decoded.width));
      final ratio = decoded.height / decoded.width;
      expect(ratio, closeTo(2.0, 0.15));
    });

    test('returns null for invalid input', () {
      final garbage = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final result = compressImagePureDart(garbage);

      expect(result, isNull);
    });

    test('handles already-tiny images', () {
      // 32x32 image — already at the smallest dimension step.
      final source = _createTestImage(32, 32);
      final result = compressImagePureDart(source);

      expect(result, isNotNull);
      expect(
        result!.length,
        lessThanOrEqualTo(SmFileTransferLimits.maxFileSize),
      );
    });
  });

  group('Image compression - yuv420 chroma subsampling', () {
    test('yuv420 produces smaller output than yuv444', () {
      final source = _createTestImage(400, 300, noisy: true);
      final decoded = img.decodeImage(source);
      expect(decoded, isNotNull);

      final resized = img.copyResize(
        decoded!,
        width: 96,
        interpolation: img.Interpolation.average,
      );

      final yuv444 = img.encodeJpg(
        resized,
        quality: 60,
        chroma: img.JpegChroma.yuv444,
      );
      final yuv420 = img.encodeJpg(
        resized,
        quality: 60,
        chroma: img.JpegChroma.yuv420,
      );

      expect(
        yuv420.length,
        lessThan(yuv444.length),
        reason: 'yuv420 should produce smaller files than yuv444',
      );
    });
  });

  group('Image compression - _resizeAndEncodeJpeg', () {
    test('encodes gradient image at various quality levels', () {
      final source = _createTestImage(200, 200);

      final q20 = _resizeAndEncodeJpeg(
        _CompressArgs(imageBytes: source, maxDim: 96, quality: 20),
      );
      final q50 = _resizeAndEncodeJpeg(
        _CompressArgs(imageBytes: source, maxDim: 96, quality: 50),
      );
      final q85 = _resizeAndEncodeJpeg(
        _CompressArgs(imageBytes: source, maxDim: 96, quality: 85),
      );

      expect(q20, isNotNull);
      expect(q50, isNotNull);
      expect(q85, isNotNull);

      // Higher quality should produce larger files.
      expect(q50!.length, greaterThan(q20!.length));
      expect(q85!.length, greaterThan(q50.length));
    });

    test('smaller maxDim produces smaller output at same quality', () {
      final source = _createTestImage(400, 400, noisy: true);

      final large = _resizeAndEncodeJpeg(
        _CompressArgs(imageBytes: source, maxDim: 128, quality: 50),
      );
      final small = _resizeAndEncodeJpeg(
        _CompressArgs(imageBytes: source, maxDim: 64, quality: 50),
      );

      expect(large, isNotNull);
      expect(small, isNotNull);
      expect(small!.length, lessThan(large!.length));
    });

    test('returns null for invalid image bytes', () {
      final result = _resizeAndEncodeJpeg(
        _CompressArgs(
          imageBytes: Uint8List.fromList([0xFF, 0x00, 0x42]),
          maxDim: 96,
          quality: 50,
        ),
      );

      expect(result, isNull);
    });
  });
}
