// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../core/logging.dart';
import '../codec2/codec2_bindings.dart';
import '../codec2/codec2_ffi.dart';
import 'voice_constants.dart';

/// Decodes a Socialmesh `.c2` wire-format payload to a WAV byte buffer.
///
/// The returned WAV bytes can be fed to [VoicePlayer] (just_audio) for
/// in-memory playback without writing to disk.
abstract final class VoiceDecoder {
  /// Decodes a `.c2` payload to PCM WAV bytes.
  ///
  /// Returns null when [c2Data] is malformed, too short, has the wrong
  /// magic byte, or uses an unknown mode byte.
  ///
  /// The decoder auto-detects the Codec2 mode from the wire header, so it
  /// plays back messages encoded at any supported bitrate.
  static Future<Uint8List?> decode(Uint8List c2Data) async {
    if (!Codec2Bindings.isAvailable) {
      AppLogging.voice('Codec2 native library not available — cannot decode');
      return null;
    }
    if (c2Data.length < VoiceConstants.headerSize) {
      AppLogging.voice('decode: payload too short (${c2Data.length} bytes)');
      return null;
    }
    if (c2Data[0] != VoiceConstants.magicByte) {
      AppLogging.voice(
        'decode: bad magic byte 0x${c2Data[0].toRadixString(16).padLeft(2, '0')}',
      );
      return null;
    }

    final quality = VoiceQuality.fromWireModeByte(c2Data[1]);
    if (quality == null) {
      AppLogging.voice(
        'decode: unsupported mode byte 0x${c2Data[1].toRadixString(16).padLeft(2, '0')}',
      );
      return null;
    }

    final declaredFrames = c2Data[2] | (c2Data[3] << 8);
    final payloadBytes = c2Data.length - VoiceConstants.headerSize;
    final actualFrames = payloadBytes ~/ quality.bytesPerFrame;

    if (actualFrames == 0) {
      AppLogging.voice('decode: no frames in payload');
      return null;
    }

    final frames = actualFrames < declaredFrames
        ? actualFrames
        : declaredFrames;
    AppLogging.voice(
      'decode: $frames frames at ${quality.bitRate} bps, '
      'declared=$declaredFrames',
    );

    final frameBytes = c2Data.sublist(
      VoiceConstants.headerSize,
      VoiceConstants.headerSize + frames * quality.bytesPerFrame,
    );

    final pcm = await decodeCodec2Frames(
      frameBytes,
      cApiMode: quality.cApiMode,
      bytesPerFrame: quality.bytesPerFrame,
    );
    if (pcm == null || pcm.isEmpty) {
      AppLogging.voice('decode: Codec2 decoding returned empty PCM');
      return null;
    }

    final wav = _buildWav(pcm);
    AppLogging.voice(
      'decode: ${pcm.length} samples -> ${wav.length} WAV bytes',
    );
    return wav;
  }

  /// Builds a minimal 44-byte WAV header followed by raw PCM data.
  static Uint8List _buildWav(Int16List pcm) {
    const int headerLen = 44;
    const int bitsPerSample = VoiceConstants.bitsPerSample;
    const int sampleRate = VoiceConstants.sampleRate;
    const int channels = VoiceConstants.channels;
    const int blockAlign = channels * (bitsPerSample ~/ 8);
    const int byteRate = sampleRate * blockAlign;
    final int dataSize = pcm.length * 2;
    final int chunkSize = 36 + dataSize;

    final buf = ByteData(headerLen + dataSize);
    var pos = 0;

    void writeStr(String s) {
      for (final c in s.codeUnits) {
        buf.setUint8(pos++, c);
      }
    }

    void writeU32(int v) {
      buf.setUint32(pos, v, Endian.little);
      pos += 4;
    }

    void writeU16(int v) {
      buf.setUint16(pos, v, Endian.little);
      pos += 2;
    }

    writeStr('RIFF');
    writeU32(chunkSize);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16); // PCM chunk size
    writeU16(1); // PCM format
    writeU16(channels);
    writeU32(sampleRate);
    writeU32(byteRate);
    writeU16(blockAlign);
    writeU16(bitsPerSample);
    writeStr('data');
    writeU32(dataSize);

    for (var i = 0; i < pcm.length; i++) {
      buf.setInt16(pos, pcm[i], Endian.little);
      pos += 2;
    }

    return buf.buffer.asUint8List();
  }
}
