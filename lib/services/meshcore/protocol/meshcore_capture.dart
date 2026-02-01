// SPDX-License-Identifier: GPL-3.0-or-later

// MeshCore protocol capture for debugging and replay.
//
// Provides in-memory capture of TX/RX frames without file I/O or UI.
// Used for debugging, protocol analysis, and test replay harnesses.

import 'dart:typed_data';

import 'meshcore_frame.dart';

/// Direction of a captured frame.
enum CaptureDirection {
  /// Frame received from device.
  rx,

  /// Frame sent to device.
  tx,
}

/// A captured MeshCore frame with metadata.
class CapturedFrame {
  /// Direction of the frame (rx/tx).
  final CaptureDirection direction;

  /// Timestamp in milliseconds since capture started.
  final int timestampMs;

  /// The frame command/response code.
  final int code;

  /// The frame payload bytes.
  final Uint8List payload;

  CapturedFrame({
    required this.direction,
    required this.timestampMs,
    required this.code,
    required this.payload,
  });

  /// Create from a MeshCoreFrame.
  factory CapturedFrame.fromFrame(
    MeshCoreFrame frame,
    CaptureDirection direction,
    int timestampMs,
  ) {
    return CapturedFrame(
      direction: direction,
      timestampMs: timestampMs,
      code: frame.command,
      payload: Uint8List.fromList(frame.payload),
    );
  }

  /// Convert back to a MeshCoreFrame.
  MeshCoreFrame toFrame() => MeshCoreFrame(command: code, payload: payload);

  /// Format as compact hex string.
  ///
  /// Format: `[RX|TX] @{ms}ms 0x{code}: {hex payload truncated}`
  String toCompactHex({int maxBytes = 64}) {
    final dirStr = direction == CaptureDirection.rx ? 'RX' : 'TX';
    final codeHex = code.toRadixString(16).padLeft(2, '0').toUpperCase();
    final truncated = payload.length > maxBytes;
    final bytes = truncated ? payload.sublist(0, maxBytes) : payload;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final suffix = truncated ? '... (${payload.length} bytes total)' : '';
    return '[$dirStr] @${timestampMs}ms 0x$codeHex: $hex$suffix';
  }

  @override
  String toString() => toCompactHex();
}

/// In-memory capture of MeshCore protocol frames.
///
/// Records TX and RX frames with timestamps for debugging and replay.
/// No file I/O, no UI - just pure Dart data structure.
///
/// Usage:
/// ```dart
/// final capture = MeshCoreFrameCapture();
/// session.setCapture(capture);
///
/// // ... perform operations ...
///
/// // Get all captured frames
/// final frames = capture.snapshot();
///
/// // Get compact log for copy/paste
/// print(capture.toCompactHexLog());
/// ```
class MeshCoreFrameCapture {
  final List<CapturedFrame> _frames = [];
  final Stopwatch _stopwatch = Stopwatch();

  /// Whether capture is currently active.
  bool _active = true;

  /// Creates a new capture and starts the timestamp clock.
  MeshCoreFrameCapture() {
    _stopwatch.start();
  }

  /// Whether capture is active (recording).
  bool get isActive => _active;

  /// Number of captured frames.
  int get frameCount => _frames.length;

  /// Record a received frame.
  void recordRx(MeshCoreFrame frame) {
    if (!_active) return;
    _frames.add(
      CapturedFrame.fromFrame(
        frame,
        CaptureDirection.rx,
        _stopwatch.elapsedMilliseconds,
      ),
    );
  }

  /// Record a transmitted frame.
  void recordTx(MeshCoreFrame frame) {
    if (!_active) return;
    _frames.add(
      CapturedFrame.fromFrame(
        frame,
        CaptureDirection.tx,
        _stopwatch.elapsedMilliseconds,
      ),
    );
  }

  /// Get a snapshot of all captured frames.
  ///
  /// Returns a copy of the internal list.
  List<CapturedFrame> snapshot() => List.unmodifiable(_frames);

  /// Get captured frames filtered by direction.
  List<CapturedFrame> rxFrames() =>
      _frames.where((f) => f.direction == CaptureDirection.rx).toList();

  /// Get captured TX frames.
  List<CapturedFrame> txFrames() =>
      _frames.where((f) => f.direction == CaptureDirection.tx).toList();

  /// Format all captured frames as a compact hex log.
  ///
  /// Each line is one frame. Good for copy/paste from console.
  String toCompactHexLog({int maxBytesPerFrame = 64}) {
    if (_frames.isEmpty) return '(no frames captured)';
    return _frames
        .map((f) => f.toCompactHex(maxBytes: maxBytesPerFrame))
        .join('\n');
  }

  /// Clear all captured frames and reset timestamp.
  void clear() {
    _frames.clear();
    _stopwatch.reset();
    _stopwatch.start();
  }

  /// Stop capturing (frames will be ignored).
  void stop() {
    _active = false;
    _stopwatch.stop();
  }

  /// Resume capturing.
  void resume() {
    _active = true;
    _stopwatch.start();
  }
}
