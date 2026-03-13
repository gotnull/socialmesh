// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../core/logging.dart';
import '../codec2/codec2_ffi.dart';
import 'voice_constants.dart';

/// Encodes raw PCM audio to the Socialmesh Codec2 `.c2` wire format.
///
/// Wire format:
/// ```
/// [0xC2, 0x04, frameCountLow, frameCountHigh, frame0..frameN]
/// ```
/// Each frame is [VoiceConstants.bytesPerFrame] bytes (6 bytes at 1200 bps).
abstract final class VoiceEncoder {
  /// Encodes [pcm] (16-bit mono at 8000 Hz) to the `.c2` wire format.
  ///
  /// Returns null if [pcm] is empty or encoding fails.
  ///
  /// The returned payload includes the 4-byte header and is ready to be
  /// passed to the file transfer engine as the content bytes.
  static Future<Uint8List?> encode(Int16List pcm) async {
    if (pcm.isEmpty) return null;
    AppLogging.voice('encoding ${pcm.length} samples');

    final encodedFrames = await encodeCodec2Frames(pcm);
    if (encodedFrames == null || encodedFrames.isEmpty) {
      AppLogging.voice('encoding returned empty result');
      return null;
    }

    final frameCount = encodedFrames.length ~/ VoiceConstants.bytesPerFrame;
    if (frameCount == 0) return null;

    // Build the `.c2` container with 4-byte header.
    final payload = Uint8List(VoiceConstants.headerSize + encodedFrames.length);
    payload[0] = VoiceConstants.magicByte;
    payload[1] = VoiceConstants.wireMode1200;
    payload[2] = frameCount & 0xFF;
    payload[3] = (frameCount >> 8) & 0xFF;
    payload.setRange(VoiceConstants.headerSize, payload.length, encodedFrames);

    AppLogging.voice(
      'encode complete: $frameCount frames, ${payload.length} bytes',
    );
    return payload;
  }
}
