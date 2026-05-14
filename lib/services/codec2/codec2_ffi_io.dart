// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import 'codec2_bindings_io.dart';

/// Codec2 mode constant for 1200 bps encoding.
///
/// In the Codec2 v1.2.0 C API (codec2.h), `CODEC2_MODE_1200 = 5`.
/// Wire-format header byte for 1200 bps in `.c2` files is `0x04` (our
/// SocialMesh custom wire format identifier — see VoiceConstants).
const int codec2Mode1200 = 5;

/// Number of encoded bytes produced per frame at 1200 bps.
const int codec2BytesPerFrame1200 = 6;

/// Number of PCM samples consumed/produced per frame at 1200 bps.
const int codec2SamplesPerFrame1200 = 320;

/// Queries the native library for the number of bytes per encoded frame.
int codec2BytesPerFrame(int cApiMode) {
  final c2 = Codec2Bindings.codec2Create(cApiMode);
  if (c2 == nullptr) return 0;
  final bpf = Codec2Bindings.codec2BytesPerFrame(c2);
  Codec2Bindings.codec2Destroy(c2);
  return bpf;
}

/// Encodes raw PCM audio to Codec2 1200 bps frames using the native C library.
///
/// Usage:
/// ```dart
/// final encoder = Codec2Encoder(mode: codec2Mode1200);
/// final compressedFrame = encoder.encode(pcmFrame);
/// encoder.dispose();
/// ```
///
/// Thread safety: Not thread-safe. Create one instance per encoding session.
class Codec2Encoder {
  Codec2Encoder({required int mode}) : _mode = mode {
    _c2 = Codec2Bindings.codec2Create(mode);
    if (_c2 == nullptr) {
      throw StateError('codec2_create($mode) returned null');
    }
    _samplesPerFrame = Codec2Bindings.codec2SamplesPerFrame(_c2);
    _bytesPerFrame = Codec2Bindings.codec2BytesPerFrame(_c2);
    AppLogging.codec2(
      'encoder created (mode=$mode, samplesPerFrame=$_samplesPerFrame, '
      'bytesPerFrame=$_bytesPerFrame)',
    );
  }

  final int _mode;
  late final Pointer<Void> _c2;
  late final int _samplesPerFrame;
  bool _disposed = false;

  int get mode => _mode;
  int get samplesPerFrame => _samplesPerFrame;

  /// Number of encoded bytes per frame for this mode.
  int get bytesPerFrame => _bytesPerFrame;
  late final int _bytesPerFrame;

  /// Encodes a single PCM frame (must be exactly [samplesPerFrame] samples).
  ///
  /// Returns [bytesPerFrame] bytes for the configured mode.
  Uint8List encode(Int16List pcmFrame) {
    assert(!_disposed, 'Codec2Encoder used after dispose()');
    assert(
      pcmFrame.length == _samplesPerFrame,
      'PCM frame must be $_samplesPerFrame samples, got ${pcmFrame.length}',
    );

    final speechPtr = calloc<Int16>(_samplesPerFrame);
    final bitsPtr = calloc<Uint8>(_bytesPerFrame);
    try {
      for (var i = 0; i < _samplesPerFrame; i++) {
        speechPtr[i] = pcmFrame[i];
      }
      Codec2Bindings.codec2Encode(_c2, bitsPtr, speechPtr);
      final result = Uint8List(_bytesPerFrame);
      for (var i = 0; i < _bytesPerFrame; i++) {
        result[i] = bitsPtr[i];
      }
      AppLogging.codec2('encode frame -> $_bytesPerFrame bytes');
      return result;
    } finally {
      calloc.free(speechPtr);
      calloc.free(bitsPtr);
    }
  }

  /// Releases native resources. Safe to call multiple times.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    Codec2Bindings.codec2Destroy(_c2);
    AppLogging.codec2('encoder destroyed');
  }
}

/// Decodes Codec2 1200 bps frames back to raw PCM audio.
///
/// Usage:
/// ```dart
/// final decoder = Codec2Decoder(mode: codec2Mode1200);
/// final pcmFrame = decoder.decode(encodedFrame);
/// decoder.dispose();
/// ```
class Codec2Decoder {
  Codec2Decoder({required int mode}) : _mode = mode {
    _c2 = Codec2Bindings.codec2Create(mode);
    if (_c2 == nullptr) {
      throw StateError('codec2_create($mode) returned null');
    }
    _samplesPerFrame = Codec2Bindings.codec2SamplesPerFrame(_c2);
    _bytesPerFrame = Codec2Bindings.codec2BytesPerFrame(_c2);
    AppLogging.codec2(
      'decoder created (mode=$mode, samplesPerFrame=$_samplesPerFrame, '
      'bytesPerFrame=$_bytesPerFrame)',
    );
  }

  final int _mode;
  late final Pointer<Void> _c2;
  late final int _samplesPerFrame;
  bool _disposed = false;

  int get mode => _mode;
  int get samplesPerFrame => _samplesPerFrame;

  /// Number of encoded bytes per frame for this mode.
  int get bytesPerFrame => _bytesPerFrame;
  late final int _bytesPerFrame;

  /// Decodes a single Codec2 frame back to [samplesPerFrame] PCM samples.
  ///
  /// [frame] must be exactly [bytesPerFrame] bytes for the configured mode.
  Int16List decode(Uint8List frame) {
    assert(!_disposed, 'Codec2Decoder used after dispose()');
    assert(
      frame.length == _bytesPerFrame,
      'Frame must be $_bytesPerFrame bytes, got ${frame.length}',
    );

    final bitsPtr = calloc<Uint8>(_bytesPerFrame);
    final speechPtr = calloc<Int16>(_samplesPerFrame);
    try {
      for (var i = 0; i < _bytesPerFrame; i++) {
        bitsPtr[i] = frame[i];
      }
      Codec2Bindings.codec2Decode(_c2, speechPtr, bitsPtr);
      final result = Int16List(_samplesPerFrame);
      for (var i = 0; i < _samplesPerFrame; i++) {
        result[i] = speechPtr[i];
      }
      AppLogging.codec2('decode frame -> $_samplesPerFrame samples');
      return result;
    } finally {
      calloc.free(bitsPtr);
      calloc.free(speechPtr);
    }
  }

  /// Releases native resources. Safe to call multiple times.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    Codec2Bindings.codec2Destroy(_c2);
    AppLogging.codec2('decoder destroyed');
  }
}

/// Message passed to the encode isolate: PCM + C API mode.
class _EncodeRequest {
  const _EncodeRequest(this.pcm, this.cApiMode);
  final Int16List pcm;
  final int cApiMode;
}

/// Isolate-safe encode function: encodes all PCM frames in one batch.
///
/// Runs in a background isolate so the UI thread is not blocked during
/// encoding of long voice messages.
Future<Uint8List?> encodeCodec2Frames(
  Int16List pcm, {
  int cApiMode = codec2Mode1200,
}) async {
  return compute(_encodeCodec2IsolateTask, _EncodeRequest(pcm, cApiMode));
}

Uint8List? _encodeCodec2IsolateTask(_EncodeRequest req) {
  if (req.pcm.isEmpty) return null;
  final encoder = Codec2Encoder(mode: req.cApiMode);
  try {
    final spf = encoder.samplesPerFrame;
    final bpf = encoder.bytesPerFrame;
    final frameCount = (req.pcm.length / spf).ceil();
    final output = Uint8List(frameCount * bpf);
    var offset = 0;
    for (var i = 0; i < frameCount; i++) {
      final start = i * spf;
      final end = ((start + spf) < req.pcm.length)
          ? (start + spf)
          : req.pcm.length;
      Int16List frame;
      if (end - start == spf) {
        frame = req.pcm.sublist(start, end);
      } else {
        // Pad final frame with silence.
        frame = Int16List(spf);
        for (var j = 0; j < (end - start); j++) {
          frame[j] = req.pcm[start + j];
        }
      }
      final encoded = encoder.encode(frame);
      output.setRange(offset, offset + bpf, encoded);
      offset += bpf;
    }
    return output;
  } finally {
    encoder.dispose();
  }
}

/// Message passed to the decode isolate: encoded frames + C API mode + bytes per frame.
class _DecodeRequest {
  const _DecodeRequest(this.encodedFrames, this.cApiMode, this.bytesPerFrame);
  final Uint8List encodedFrames;
  final int cApiMode;
  final int bytesPerFrame;
}

/// Isolate-safe decode function: decodes all Codec2 frames in one batch.
Future<Int16List?> decodeCodec2Frames(
  Uint8List encodedFrames, {
  int cApiMode = codec2Mode1200,
  int bytesPerFrame = codec2BytesPerFrame1200,
}) async {
  return compute(
    _decodeCodec2IsolateTask,
    _DecodeRequest(encodedFrames, cApiMode, bytesPerFrame),
  );
}

Int16List? _decodeCodec2IsolateTask(_DecodeRequest req) {
  if (req.encodedFrames.isEmpty) return null;
  if (req.encodedFrames.length % req.bytesPerFrame != 0) return null;
  final decoder = Codec2Decoder(mode: req.cApiMode);
  try {
    final spf = decoder.samplesPerFrame;
    final frameCount = req.encodedFrames.length ~/ req.bytesPerFrame;
    final output = Int16List(frameCount * spf);
    for (var i = 0; i < frameCount; i++) {
      final frameStart = i * req.bytesPerFrame;
      final frame = req.encodedFrames.sublist(
        frameStart,
        frameStart + req.bytesPerFrame,
      );
      final pcmFrame = decoder.decode(frame);
      for (var j = 0; j < spf; j++) {
        output[i * spf + j] = pcmFrame[j];
      }
    }
    return output;
  } finally {
    decoder.dispose();
  }
}
