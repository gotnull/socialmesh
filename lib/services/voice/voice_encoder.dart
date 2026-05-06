// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../core/logging.dart';
import '../codec2/codec2_bindings.dart';
import '../codec2/codec2_ffi.dart';
import 'voice_constants.dart';

/// Encodes raw PCM audio to the SocialMesh Codec2 `.c2` wire format.
///
/// Wire format:
/// ```
/// [0xC2, modeByte, frameCountLow, frameCountHigh, frame0..frameN]
/// ```
/// The mode byte identifies the bitrate — see [VoiceQuality].
abstract final class VoiceEncoder {
  /// Encodes [pcm] (16-bit mono at 8000 Hz) to the `.c2` wire format.
  ///
  /// [quality] selects the Codec2 bitrate. Defaults to
  /// [VoiceConstants.defaultQuality] (1200 bps).
  ///
  /// Returns null if [pcm] is empty or encoding fails.
  ///
  /// The returned payload includes the 4-byte header and is ready to be
  /// passed to the file transfer engine as the content bytes.
  static Future<Uint8List?> encode(
    Int16List pcm, {
    VoiceQuality quality = VoiceQuality.extended,
  }) async {
    if (pcm.isEmpty) return null;
    if (!Codec2Bindings.isAvailable) {
      AppLogging.voice('Codec2 native library not available — cannot encode');
      return null;
    }
    AppLogging.voice(
      'encoding ${pcm.length} samples at ${quality.bitRate} bps',
    );

    final encodedFrames = await encodeCodec2Frames(
      pcm,
      cApiMode: quality.cApiMode,
    );
    if (encodedFrames == null || encodedFrames.isEmpty) {
      AppLogging.voice('encoding returned empty result');
      return null;
    }

    final frameCount = encodedFrames.length ~/ quality.bytesPerFrame;
    if (frameCount == 0) return null;

    // Build the `.c2` container with 4-byte header.
    final payload = Uint8List(VoiceConstants.headerSize + encodedFrames.length);
    payload[0] = VoiceConstants.magicByte;
    payload[1] = quality.wireModeByte;
    payload[2] = frameCount & 0xFF;
    payload[3] = (frameCount >> 8) & 0xFF;
    payload.setRange(VoiceConstants.headerSize, payload.length, encodedFrames);

    AppLogging.voice(
      'encode complete: $frameCount frames, ${payload.length} bytes '
      '(${quality.bitRate} bps)',
    );
    return payload;
  }
}
