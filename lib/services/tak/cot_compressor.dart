// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';
import 'dart:typed_data';

import '../../core/logging.dart';

/// Compresses and decompresses CoT payloads using zlib (deflate).
///
/// Used by [TakMeshBridge] to reduce TAKPacket payload sizes for mesh
/// transport. Meshtastic has a 237-byte payload limit.
abstract final class CotCompressor {
  /// Minimum payload size (bytes) before compression is applied.
  static const int compressionThreshold = 100;

  /// Maximum allowed payload size for mesh transmission.
  static const int maxMeshPayload = 237;

  /// Compresses [data] with zlib.
  ///
  /// Returns `null` if:
  /// - [data] is shorter than [compressionThreshold]
  /// - compressed output is >= original size (negative ratio)
  /// - compressed output exceeds [maxMeshPayload]
  static Uint8List? compress(Uint8List data) {
    if (data.length < compressionThreshold) {
      AppLogging.tak(
        'Compression: skipped for ${data.length} byte payload (below $compressionThreshold byte threshold)',
      );
      return null;
    }

    final compressed = Uint8List.fromList(zlib.encode(data));

    if (compressed.length >= data.length) {
      AppLogging.tak(
        'Compression: skipped — compressed ${compressed.length} >= original ${data.length}',
      );
      return null;
    }

    if (compressed.length > maxMeshPayload) {
      AppLogging.tak(
        'Compression: ${data.length} bytes -> ${compressed.length} bytes, still exceeds $maxMeshPayload byte limit, packet rejected',
      );
      return null;
    }

    final ratio = compressed.length / data.length;
    final saved = data.length - compressed.length;
    AppLogging.tak(
      'Compression: ${data.length} bytes -> ${compressed.length} bytes (ratio ${ratio.toStringAsFixed(2)}, saved $saved bytes)',
    );
    return compressed;
  }

  /// Decompresses zlib-compressed [data].
  static Uint8List decompress(Uint8List data) {
    return Uint8List.fromList(zlib.decode(data));
  }
}
