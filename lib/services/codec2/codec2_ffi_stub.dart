// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

/// Web-build stub for the Codec2 FFI public surface used outside the
/// `codec2/` package (`voice_encoder.dart`, `voice_decoder.dart`).
///
/// The real implementation (`codec2_ffi_io.dart`) requires dart:ffi.
/// Voice encoding/decoding is mobile-only behaviour; consumers gate on
/// `Codec2Bindings.isAvailable` (false in this stub) and the helpers
/// below return null without throwing so web code paths degrade
/// gracefully.

/// Codec2 mode constant for 1200 bps encoding. Mirrors the IO variant
/// so consumer code referencing the constant compiles on both targets.
const int codec2Mode1200 = 5;

/// Number of encoded bytes produced per frame at 1200 bps.
const int codec2BytesPerFrame1200 = 6;

/// Number of PCM samples consumed/produced per frame at 1200 bps.
const int codec2SamplesPerFrame1200 = 320;

/// Stub: native library is unavailable on web.
int codec2BytesPerFrame(int cApiMode) => 0;

/// Stub: returns null because no native encoder is available on web.
/// The encode path is fully gated upstream by `Codec2Bindings.isAvailable`.
Future<Uint8List?> encodeCodec2Frames(
  Int16List pcm, {
  int cApiMode = codec2Mode1200,
}) async {
  return null;
}

/// Stub: returns null because no native decoder is available on web.
Future<Int16List?> decodeCodec2Frames(
  Uint8List encodedFrames, {
  int cApiMode = codec2Mode1200,
  int bytesPerFrame = codec2BytesPerFrame1200,
}) async {
  return null;
}
