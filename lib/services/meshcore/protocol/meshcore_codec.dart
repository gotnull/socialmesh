// SPDX-License-Identifier: GPL-3.0-or-later

// MeshCore protocol codec for encoding/decoding frames.
//
// BLE Framing (from meshcore-open reference):
// - Each BLE notification IS a complete frame - no length prefix, no delimiter
// - Frame = [code: 1 byte][payload: 0-171 bytes]
// - Max 172 bytes per frame
// - NO in-band boundary rule exists, so decoder cannot split concatenated data
//
// The decoder operates in two modes:
// - BLE mode (default): Each addData() call = one complete frame
// - Buffered mode: For USB where outer framing provides length, or testing

import 'dart:typed_data';

import 'meshcore_frame.dart';

/// Encoder for MeshCore protocol frames.
///
/// Converts [MeshCoreFrame] objects to wire-format bytes.
/// For BLE: just returns frame.toBytes() (no extra framing)
/// For USB: would add length prefix (not implemented here)
class MeshCoreEncoder {
  /// Encode a frame for BLE transport.
  ///
  /// BLE requires no extra framing - just the raw frame bytes.
  Uint8List encode(MeshCoreFrame frame) {
    if (!frame.isValidSize) {
      throw ArgumentError(
        'Frame exceeds max size (${frame.size} > $meshCoreMaxFrameSize)',
      );
    }
    return frame.toBytes();
  }

  /// Encode a simple command with no payload.
  Uint8List encodeCommand(int command) {
    return Uint8List.fromList([command]);
  }

  /// Encode a command with single byte argument.
  Uint8List encodeCommandWithByte(int command, int arg) {
    return Uint8List.fromList([command, arg]);
  }

  /// Encode a command with a Uint8List payload.
  Uint8List encodeCommandWithPayload(int command, Uint8List payload) {
    final frame = MeshCoreFrame(command: command, payload: payload);
    return encode(frame);
  }
}

/// Streaming decoder for MeshCore protocol frames.
///
/// BLE Mode (default): Each addData() call is treated as exactly one complete
/// frame. This matches BLE notification atomicity - one notification = one frame.
/// The decoder does NOT attempt to split concatenated data because MeshCore
/// has no in-band boundary rule.
///
/// Buffered Mode: For USB transport (after outer framing is stripped) or for
/// testing. Uses expectFrameSize() to know when a frame is complete.
///
/// Important: Since MeshCore frames have no length prefix or delimiter,
/// the decoder CANNOT automatically split concatenated frames without
/// external help (like USB length prefix).
///
/// Resilience Features:
/// - Empty data is silently ignored
/// - Oversized frames are reported as errors (not thrown)
/// - Never crashes on malformed input
class MeshCoreDecoder {
  /// Callback for decoded frames.
  void Function(MeshCoreFrame frame)? onFrame;

  /// Callback for decode errors.
  void Function(String error)? onError;

  /// Whether to use buffered mode (for USB/testing).
  final bool bufferedMode;

  /// Internal buffer for accumulated partial data (buffered mode only).
  final BytesBuilder _buffer = BytesBuilder();

  /// Pending frame size we're waiting to complete (buffered mode only).
  int? _pendingFrameSize;

  MeshCoreDecoder({this.onFrame, this.onError, this.bufferedMode = false});

  /// Add received data to the decoder.
  ///
  /// In BLE mode (default): Each call should be one complete notification,
  /// which maps 1:1 to a frame. The frame is decoded and emitted immediately.
  ///
  /// In buffered mode: Data is accumulated and frames are extracted as
  /// they become complete.
  void addData(Uint8List data) {
    if (data.isEmpty) return;

    if (bufferedMode) {
      _addDataBuffered(data);
    } else {
      _addDataDirect(data);
    }
  }

  /// Direct decode mode (BLE) - each notification is one frame.
  void _addDataDirect(Uint8List data) {
    // Validate size
    if (data.length > meshCoreMaxFrameSize) {
      onError?.call(
        'Frame exceeds max size (${data.length} > $meshCoreMaxFrameSize)',
      );
      return;
    }

    try {
      final frame = MeshCoreFrame.fromBytes(data);
      onFrame?.call(frame);
    } catch (e) {
      onError?.call('Failed to decode frame: $e');
    }
  }

  /// Buffered decode mode (USB/testing) - accumulate and extract frames.
  ///
  /// For USB framing: frames have a 3-byte header: [marker][len_lo][len_hi]
  /// But this decoder is for the *inner* protocol after USB framing is stripped.
  ///
  /// Since inner MeshCore frames have no length field, in buffered mode
  /// we assume each call to addData is a logical chunk and process it.
  /// For true USB support, the USB framing layer would call this with
  /// already-extracted payloads.
  void _addDataBuffered(Uint8List data) {
    _buffer.add(data);

    // In buffered mode without USB framing, we need heuristics.
    // Best approach: assume caller has done outer framing and each
    // addData call is a complete inner frame.
    // This allows testing split/concat scenarios at the USB layer.
    _tryExtractFrame();
  }

  /// Try to extract a complete frame from the buffer.
  void _tryExtractFrame() {
    final accumulated = _buffer.toBytes();
    if (accumulated.isEmpty) return;

    // If we have at least 1 byte (command), and USB layer has already
    // stripped the framing, treat the entire buffer as one frame.
    // For testing partial scenarios, the test controls chunk size.

    // Determine expected frame size.
    // Without a length field in the inner protocol, we use contextual hints:
    // - If _pendingFrameSize is set, wait for that many bytes
    // - Otherwise, treat current buffer as complete frame

    if (_pendingFrameSize != null) {
      if (accumulated.length >= _pendingFrameSize!) {
        final frameData = Uint8List.sublistView(
          accumulated,
          0,
          _pendingFrameSize!,
        );
        _consumeBuffer(_pendingFrameSize!);
        _pendingFrameSize = null;
        _emitFrame(frameData);
      }
      // else: wait for more data
    } else {
      // No pending size - treat buffer as complete frame
      _emitFrame(accumulated);
      _buffer.clear();
    }
  }

  /// Consume [count] bytes from the front of the buffer.
  void _consumeBuffer(int count) {
    final accumulated = _buffer.toBytes();
    _buffer.clear();
    if (count < accumulated.length) {
      _buffer.add(Uint8List.sublistView(accumulated, count));
    }
  }

  void _emitFrame(Uint8List data) {
    if (data.length > meshCoreMaxFrameSize) {
      onError?.call(
        'Frame exceeds max size (${data.length} > $meshCoreMaxFrameSize)',
      );
      return;
    }

    try {
      final frame = MeshCoreFrame.fromBytes(data);
      onFrame?.call(frame);
    } catch (e) {
      onError?.call('Failed to decode frame: $e');
    }
  }

  /// Set expected frame size for buffered mode.
  ///
  /// Used when outer framing (USB) tells us how many bytes to expect.
  void expectFrameSize(int size) {
    _pendingFrameSize = size;
    _tryExtractFrame();
  }

  /// Clear any accumulated partial data.
  void reset() {
    _buffer.clear();
    _pendingFrameSize = null;
  }

  /// Check if there's pending data in the buffer.
  bool get hasPendingData => _buffer.length > 0;

  /// Get count of pending bytes.
  int get pendingBytes => _buffer.length;
}

/// Combined codec for encoding and decoding MeshCore frames.
class MeshCoreCodec {
  final MeshCoreEncoder encoder = MeshCoreEncoder();
  late final MeshCoreDecoder decoder;

  MeshCoreCodec({
    void Function(MeshCoreFrame frame)? onFrame,
    void Function(String error)? onError,
    bool bufferedMode = false,
  }) {
    decoder = MeshCoreDecoder(
      onFrame: onFrame,
      onError: onError,
      bufferedMode: bufferedMode,
    );
  }

  /// Encode a frame to bytes.
  Uint8List encode(MeshCoreFrame frame) => encoder.encode(frame);

  /// Add received data to decoder.
  void decode(Uint8List data) => decoder.addData(data);

  /// Reset decoder state.
  void reset() => decoder.reset();
}
