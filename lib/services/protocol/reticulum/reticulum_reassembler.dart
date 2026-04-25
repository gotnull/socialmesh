// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'reticulum_fragment.dart';
import 'reticulum_fragment_event.dart';
import 'reticulum_frame.dart';
import 'reticulum_safe_log.dart';

/// Memory-bounded port-76 fragment reassembler per
/// `RETICULUM_TUNNEL_V0_1.md` §11.6.2 + §12.1.
///
/// Reassembly key is `(fromNode, index)`. Out-of-order delivery is
/// supported — fragments are stored by `abs(position)` (1-indexed).
/// A frame emits the moment the last fragment (`position < 0`) is
/// received AND every position `1..N` is present, where `N = abs(position)`
/// of that last fragment.
///
/// Hard limits — values from the original Phase 2 sprint spec:
///   * `kMaxConcurrentBuffers   = 64`
///   * `kMaxFragmentsPerBuffer  = 64`
///   * `kMaxFrameSizeBytes      = 16 * 1024`
///   * `kGlobalMemoryCapBytes   = 256 * 1024`
///   * `kInactivityTimeout      = 10 s` (resets on each fragment for that key)
///   * `kAbsoluteTtl            = 45 s` (since first fragment of frame)
///
/// All limits are configurable for tests; the constructor defaults
/// match the spec.
class ReticulumReassembler {
  ReticulumReassembler({
    DateTime Function()? clock,
    Duration inactivityTimeout = const Duration(seconds: 10),
    Duration absoluteTtl = const Duration(seconds: 45),
    int maxConcurrentBuffers = 64,
    int maxFragmentsPerBuffer = 64,
    int maxFrameSizeBytes = 16 * 1024,
    int globalMemoryCapBytes = 256 * 1024,
    ReticulumFragmentParser? parser,
  }) : _clock = clock ?? DateTime.now,
       _inactivityTimeout = inactivityTimeout,
       _absoluteTtl = absoluteTtl,
       _maxConcurrentBuffers = maxConcurrentBuffers,
       _maxFragmentsPerBuffer = maxFragmentsPerBuffer,
       _maxFrameSizeBytes = maxFrameSizeBytes,
       _globalMemoryCapBytes = globalMemoryCapBytes,
       _parser = parser ?? const ReticulumFragmentParser();

  final DateTime Function() _clock;
  final Duration _inactivityTimeout;
  final Duration _absoluteTtl;
  final int _maxConcurrentBuffers;
  final int _maxFragmentsPerBuffer;
  final int _maxFrameSizeBytes;
  final int _globalMemoryCapBytes;
  final ReticulumFragmentParser _parser;

  /// Insertion-ordered map keyed by `(fromNode << 8) | index`.
  /// Insertion order = age. Oldest at the head.
  final LinkedHashMap<int, _Buffer> _buffers = LinkedHashMap<int, _Buffer>();

  int _globalBytes = 0;

  final StreamController<ReticulumFrame> _framesController =
      StreamController<ReticulumFrame>.broadcast();
  final StreamController<ReticulumReassemblerStats> _statsController =
      StreamController<ReticulumReassemblerStats>.broadcast();

  ReticulumReassemblerStats _stats = ReticulumReassemblerStats.empty;
  bool _disposed = false;

  Stream<ReticulumFrame> get frames => _framesController.stream;
  Stream<ReticulumReassemblerStats> get statsStream => _statsController.stream;
  ReticulumReassemblerStats get stats => _stats;

  /// Number of partial buffers currently held in memory. Exposed for
  /// tests + diagnostics UI.
  int get activeBuffers => _buffers.length;

  /// Sum of body bytes across all partial buffers. Exposed for tests.
  int get globalBytes => _globalBytes;

  /// Push a fragment event into the reassembler. Decode errors,
  /// duplicates, and oversize/overflow drops update counters and may
  /// log via [ReticulumSafeLog]; never throws.
  void onFragment(ReticulumFragmentEvent event) {
    if (_disposed) return;
    final ReticulumFragmentHeader header;
    try {
      header = _parser.parse(event.payload);
    } on ReticulumFragmentDecodeError catch (e) {
      _bumpStats(droppedDecodeError: 1);
      ReticulumSafeLog.decodeError(reason: e.reason);
      return;
    } catch (e) {
      _bumpStats(droppedDecodeError: 1);
      ReticulumSafeLog.decodeError(reason: 'parser_exception: $e');
      return;
    }

    final key = _bufferKey(event.fromNode, header.index);
    final nowMs = _clock().millisecondsSinceEpoch;
    final fragNum = header.fragmentNumber;
    final bodyLen = header.body.length;

    var buffer = _buffers[key];
    if (buffer == null) {
      // Drop oldest if we'd exceed concurrent-buffer cap.
      while (_buffers.length >= _maxConcurrentBuffers) {
        _evictOldest('overflow_buffers');
      }
      // Drop oldest while the new fragment wouldn't fit in the global
      // memory budget. We only drop other buffers — never the new
      // arrival itself; if even an empty buffer can't accept this
      // fragment, the global cap is set too small.
      while (_globalBytes + bodyLen > _globalMemoryCapBytes &&
          _buffers.isNotEmpty) {
        _evictOldest('overflow_global_bytes');
      }
      if (bodyLen > _maxFrameSizeBytes) {
        // Single fragment alone exceeds frame-size cap. Drop without
        // ever creating a buffer.
        _bumpStats(droppedOversize: 1);
        ReticulumSafeLog.event(
          'reasm_oversize_first_fragment from=0x${event.fromNode.toRadixString(16)} '
          'index=${header.index} body_len=$bodyLen',
        );
        return;
      }
      buffer = _Buffer(firstSeenMs: nowMs, lastActivityMs: nowMs);
      _buffers[key] = buffer;
    }

    // Per-buffer fragment-count cap: drop the WHOLE buffer rather
    // than silently growing it past the limit. Adversarial input
    // shouldn't pin memory.
    if (!buffer.fragments.containsKey(fragNum) &&
        buffer.fragments.length >= _maxFragmentsPerBuffer) {
      _dropBuffer(key, buffer, 'overflow_fragments');
      _bumpStats(droppedOverflow: 1);
      return;
    }

    // Per-frame size cap: if this fragment would push total bytes
    // past the cap, drop the whole buffer.
    final priorSize = buffer.fragments[fragNum]?.length ?? 0;
    final delta = bodyLen - priorSize;
    if (buffer.totalBytes + delta > _maxFrameSizeBytes) {
      _dropBuffer(key, buffer, 'oversize');
      _bumpStats(droppedOversize: 1);
      return;
    }

    // Duplicate check. Per spec, silently overwrite + count.
    var isDuplicate = false;
    if (buffer.fragments.containsKey(fragNum)) {
      isDuplicate = true;
      _globalBytes -= priorSize;
      buffer.totalBytes -= priorSize;
    }
    buffer.fragments[fragNum] = header.body;
    buffer.totalBytes += bodyLen;
    _globalBytes += bodyLen;
    buffer.lastActivityMs = nowMs;

    if (header.isLast) {
      // Set N if not already known; the spec doesn't allow conflicting
      // declarations (two fragments both negative for the same key)
      // but if a duplicate-with-different-N arrives, prefer the latest.
      buffer.totalCount = fragNum;
    }

    _bumpStats(duplicate: isDuplicate ? 1 : 0);

    // Try to emit if complete.
    if (buffer.totalCount != null && _bufferComplete(buffer)) {
      final body = _assembleBuffer(buffer);
      final frame = ReticulumFrame(
        fromNode: event.fromNode,
        index: header.index,
        fragmentCount: buffer.totalCount!,
        body: body,
        firstSeenMs: buffer.firstSeenMs,
        lastSeenMs: nowMs,
      );
      // Remove from buffers + memory accounting.
      _globalBytes -= buffer.totalBytes;
      _buffers.remove(key);
      _bumpStats(emitted: 1);
      ReticulumSafeLog.event(
        'reasm_emit from=0x${event.fromNode.toRadixString(16)} '
        'index=${header.index} N=${frame.fragmentCount} '
        'body_len=${frame.bodyLen}',
      );
      _framesController.add(frame);
    }
  }

  /// Force a timeout sweep. Periodic invocation (e.g. once per second
  /// from a Timer in the owning provider) keeps the reassembler from
  /// holding zombie buffers.
  void tick() {
    if (_disposed) return;
    final nowMs = _clock().millisecondsSinceEpoch;
    final keysToInactivity = <int>[];
    final keysToAbsolute = <int>[];
    for (final entry in _buffers.entries) {
      final buf = entry.value;
      if (nowMs - buf.firstSeenMs >= _absoluteTtl.inMilliseconds) {
        keysToAbsolute.add(entry.key);
        continue;
      }
      if (nowMs - buf.lastActivityMs >= _inactivityTimeout.inMilliseconds) {
        keysToInactivity.add(entry.key);
      }
    }
    for (final k in keysToAbsolute) {
      final buf = _buffers[k]!;
      _dropBuffer(k, buf, 'timeout_absolute');
      _bumpStats(droppedTimeoutAbsolute: 1);
    }
    for (final k in keysToInactivity) {
      final buf = _buffers[k]!;
      _dropBuffer(k, buf, 'timeout_inactivity');
      _bumpStats(droppedTimeoutInactivity: 1);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _buffers.clear();
    _globalBytes = 0;
    await _framesController.close();
    await _statsController.close();
  }

  // ── internals ──────────────────────────────────────────────────────

  /// Pack `(fromNode, index)` into a single int key. fromNode is
  /// uint32, index is uint8 — fits comfortably in Dart's int.
  static int _bufferKey(int fromNode, int index) {
    return (fromNode << 8) | (index & 0xFF);
  }

  void _evictOldest(String reason) {
    if (_buffers.isEmpty) return;
    final firstKey = _buffers.keys.first;
    final buf = _buffers[firstKey]!;
    _dropBuffer(firstKey, buf, reason);
    _bumpStats(droppedOverflow: 1);
  }

  void _dropBuffer(int key, _Buffer buffer, String reason) {
    _buffers.remove(key);
    _globalBytes -= buffer.totalBytes;
    if (_globalBytes < 0) _globalBytes = 0;
    ReticulumSafeLog.event(
      'reasm_drop reason=$reason key=0x${key.toRadixString(16)} '
      'fragments=${buffer.fragments.length} bytes=${buffer.totalBytes}',
    );
  }

  bool _bufferComplete(_Buffer buffer) {
    final n = buffer.totalCount;
    if (n == null) return false;
    for (var i = 1; i <= n; i++) {
      if (!buffer.fragments.containsKey(i)) return false;
    }
    return true;
  }

  Uint8List _assembleBuffer(_Buffer buffer) {
    final builder = BytesBuilder(copy: false);
    for (var i = 1; i <= buffer.totalCount!; i++) {
      builder.add(buffer.fragments[i]!);
    }
    return builder.toBytes();
  }

  void _bumpStats({
    int emitted = 0,
    int duplicate = 0,
    int droppedOverflow = 0,
    int droppedOversize = 0,
    int droppedTimeoutInactivity = 0,
    int droppedTimeoutAbsolute = 0,
    int droppedDecodeError = 0,
  }) {
    final s = _stats;
    _stats = ReticulumReassemblerStats(
      framesEmitted: s.framesEmitted + emitted,
      duplicateFragments: s.duplicateFragments + duplicate,
      droppedOverflow: s.droppedOverflow + droppedOverflow,
      droppedOversize: s.droppedOversize + droppedOversize,
      droppedTimeoutInactivity:
          s.droppedTimeoutInactivity + droppedTimeoutInactivity,
      droppedTimeoutAbsolute: s.droppedTimeoutAbsolute + droppedTimeoutAbsolute,
      droppedDecodeError: s.droppedDecodeError + droppedDecodeError,
    );
    _statsController.add(_stats);
  }
}

class _Buffer {
  _Buffer({required this.firstSeenMs, required this.lastActivityMs});

  final int firstSeenMs;
  int lastActivityMs;

  /// Map keyed by `abs(position)` (1-indexed). Values are body bytes.
  final Map<int, Uint8List> fragments = <int, Uint8List>{};

  /// Total fragment count `N`, set when the last-fragment marker is
  /// received. `null` until then.
  int? totalCount;

  /// Sum of `body.length` across all fragments stored in this buffer.
  /// Maintained on every insert / overwrite / removal.
  int totalBytes = 0;
}

/// Aggregate, immutable counters for the reassembler. UI consumers
/// can render these directly.
class ReticulumReassemblerStats {
  const ReticulumReassemblerStats({
    this.framesEmitted = 0,
    this.duplicateFragments = 0,
    this.droppedOverflow = 0,
    this.droppedOversize = 0,
    this.droppedTimeoutInactivity = 0,
    this.droppedTimeoutAbsolute = 0,
    this.droppedDecodeError = 0,
  });

  static const empty = ReticulumReassemblerStats();

  final int framesEmitted;
  final int duplicateFragments;
  final int droppedOverflow;
  final int droppedOversize;
  final int droppedTimeoutInactivity;
  final int droppedTimeoutAbsolute;
  final int droppedDecodeError;

  /// Total number of frames the reassembler has *attempted* to
  /// reassemble, completed or otherwise. Useful for the success-rate
  /// %  display in the diagnostics UI.
  int get totalAttempted =>
      framesEmitted +
      droppedOverflow +
      droppedOversize +
      droppedTimeoutInactivity +
      droppedTimeoutAbsolute +
      droppedDecodeError;

  /// Reassembly success rate (0..1). Returns 0 when there have been
  /// no attempts yet.
  double get successRate =>
      totalAttempted == 0 ? 0.0 : framesEmitted / totalAttempted;
}
