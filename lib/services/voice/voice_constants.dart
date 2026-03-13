// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Constants for the Codec2 voice message subsystem.
///
/// Wire format (Socialmesh `.c2` container):
/// ```
/// [0xC2, 0x04, frameCountLow, frameCountHigh, frame0_byte0..byte5, ...]
/// ```
/// Byte 0x04 is the Socialmesh wire identifier for Codec2 1200 bps.
/// The C API mode for 1200 bps is CODEC2_MODE_1200 = 5 (codec2.h v1.2.0).
abstract final class VoiceConstants {
  /// Magic byte that starts every `.c2` container frame stream.
  static const int magicByte = 0xC2;

  /// Wire-format mode byte identifying 1200 bps Codec2 in `.c2` containers.
  static const int wireMode1200 = 0x04;

  /// C API mode constant for 1200 bps (CODEC2_MODE_1200 in codec2.h v1.2.0).
  static const int cApiMode1200 = 5;

  /// Number of bytes per encoded Codec2 frame at 1200 bps.
  static const int bytesPerFrame = 6;

  /// Number of PCM samples per Codec2 frame at 1200 bps.
  static const int samplesPerFrame = 320;

  /// Codec2 audio sample rate (Hz).
  static const int sampleRate = 8000;

  /// Number of audio channels (mono).
  static const int channels = 1;

  /// Bit depth of PCM samples.
  static const int bitsPerSample = 16;

  /// Size of the `.c2` wire-format header in bytes.
  static const int headerSize = 4;

  /// Maximum number of frames allowed per voice message.
  ///
  /// 8192 bytes total payload limit → 8192 - 4 header = 8188 bytes → 1364 frames.
  static const int maxFrames = 1364;

  /// Maximum voice message payload in bytes (including 4-byte header).
  static const int maxPayloadBytes = headerSize + maxFrames * bytesPerFrame;

  /// Maximum recording duration at 40 ms/frame × 1364 frames.
  static const Duration maxRecordingDuration = Duration(
    milliseconds: samplesPerFrame * 1000 ~/ sampleRate * maxFrames,
  );

  /// MIME type used to identify voice messages in the file transfer engine.
  static const String mimeType = 'audio/x-codec2';

  /// File extension for voice message containers.
  static const String fileExtension = '.c2';

  /// Prefix used when generating voice message filenames.
  static const String filenamePrefix = 'voice_';
}
