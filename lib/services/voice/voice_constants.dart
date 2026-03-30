// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// User-selectable voice quality modes for Codec2 encoding.
///
/// Each mode trades encoding quality against maximum recording duration
/// within the 8192-byte SIP file transfer limit.
enum VoiceQuality {
  /// 1200 bps — longest recording (≈55 s), HF radio quality.
  extended(
    wireModeByte: 0x04,
    cApiMode: 5,
    bytesPerFrame: 6,
    samplesPerFrame: 320,
    bitRate: 1200,
  ),

  /// 2400 bps — balanced quality and duration (≈27 s).
  standard(
    wireModeByte: 0x05,
    cApiMode: 1,
    bytesPerFrame: 6,
    samplesPerFrame: 160,
    bitRate: 2400,
  ),

  /// 3200 bps — best quality, shortest recording (≈20 s).
  high(
    wireModeByte: 0x06,
    cApiMode: 0,
    bytesPerFrame: 8,
    samplesPerFrame: 160,
    bitRate: 3200,
  );

  const VoiceQuality({
    required this.wireModeByte,
    required this.cApiMode,
    required this.bytesPerFrame,
    required this.samplesPerFrame,
    required this.bitRate,
  });

  /// Byte written to position 1 in the `.c2` wire header.
  final int wireModeByte;

  /// C API constant passed to `codec2_create()` (codec2.h v1.2.0).
  final int cApiMode;

  /// Number of encoded bytes per Codec2 frame.
  final int bytesPerFrame;

  /// Number of PCM samples consumed/produced per frame.
  final int samplesPerFrame;

  /// Nominal bit rate in bits per second.
  final int bitRate;

  /// Maximum number of frames that fit in [VoiceConstants.maxTransferSize].
  int get maxFrames =>
      (VoiceConstants.maxTransferSize - VoiceConstants.headerSize) ~/
      bytesPerFrame;

  /// Maximum recording duration for this quality mode.
  Duration get maxRecordingDuration => Duration(
    milliseconds:
        samplesPerFrame * 1000 ~/ VoiceConstants.sampleRate * maxFrames,
  );

  /// Maximum payload size including the 4-byte header.
  int get maxPayloadBytes =>
      VoiceConstants.headerSize + maxFrames * bytesPerFrame;

  /// Resolves a wire-format mode byte to a [VoiceQuality].
  ///
  /// Returns null for unknown mode bytes, allowing the decoder to reject
  /// unsupported future modes gracefully.
  static VoiceQuality? fromWireModeByte(int byte) {
    for (final q in values) {
      if (q.wireModeByte == byte) return q;
    }
    return null;
  }

  /// SharedPreferences storage key value.
  String get prefsValue => name;

  /// Restores a [VoiceQuality] from its [prefsValue]. Defaults to
  /// [VoiceConstants.defaultQuality].
  static VoiceQuality fromPrefsValue(String? value) {
    if (value == null) return VoiceConstants.defaultQuality;
    for (final q in values) {
      if (q.name == value) return q;
    }
    return VoiceConstants.defaultQuality;
  }
}

/// Constants for the Codec2 voice message subsystem.
///
/// Wire format (Socialmesh `.c2` container):
/// ```
/// [0xC2, modeByte, frameCountLow, frameCountHigh, frame0..frameN]
/// ```
/// The mode byte identifies the Codec2 bitrate — see [VoiceQuality].
abstract final class VoiceConstants {
  /// Magic byte that starts every `.c2` container frame stream.
  static const int magicByte = 0xC2;

  // ── Legacy constants (kept for backward compatibility and tests). ──────

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

  /// Maximum file transfer engine payload in bytes.
  static const int maxTransferSize = 8192;

  /// Maximum number of frames allowed per voice message at 1200 bps.
  ///
  /// 8192 bytes total payload limit → 8192 - 4 header = 8188 bytes → 1364 frames.
  static const int maxFrames = 1364;

  /// Maximum voice message payload in bytes (including 4-byte header).
  static const int maxPayloadBytes = headerSize + maxFrames * bytesPerFrame;

  /// Maximum recording duration at 40 ms/frame × 1364 frames.
  static const Duration maxRecordingDuration = Duration(
    milliseconds: samplesPerFrame * 1000 ~/ sampleRate * maxFrames,
  );

  /// Default voice quality for new installations.
  static const VoiceQuality defaultQuality = VoiceQuality.high;

  /// SharedPreferences key for the user's selected voice quality.
  static const String qualityPrefsKey = 'voice_quality';

  /// MIME type used to identify voice messages in the file transfer engine.
  static const String mimeType = 'audio/x-codec2';

  /// File extension for voice message containers.
  static const String fileExtension = '.c2';

  /// Prefix used when generating voice message filenames.
  static const String filenamePrefix = 'voice_';
}
