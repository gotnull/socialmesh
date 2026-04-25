// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// TCP bridge service that forwards reassembled Reticulum frames from
// the local Phase 2 RX stream to a host-side rnsd. Pure service —
// owns no providers, no UI, no real-network coupling. Tests inject a
// fake socket factory; production injects one that wraps dart:io
// `Socket.connect`.
//
// Wire format is HDLC byte-stuffing per
// `lib/services/reticulum/reticulum_tcp_framing.dart`. Framing is
// proven against `test/fixtures/reticulum/tcp_capture_v1.bin`.

import 'dart:async';
import 'dart:collection';
import 'dart:io' show Socket;
import 'dart:math' as math;
import 'dart:typed_data';

import 'reticulum_tcp_framing.dart';

/// Bounded outbound queue depth. The 33rd frame waiting to flush is
/// dropped (drop-newest policy) — preserves in-flight order to the
/// downstream rnsd. Documented invariant; do not bump without
/// updating the bridge UI's queue gauge in Phase 3.4.
const int kReticulumBridgeQueueDepth = 32;

const Duration kReticulumBridgeBackoffStart = Duration(seconds: 1);
const Duration kReticulumBridgeBackoffCap = Duration(seconds: 60);

/// Coarse connection state surfaced to the UI / provider.
enum ReticulumBridgeStatusKind { disconnected, connecting, connected, error }

class ReticulumBridgeStatus {
  const ReticulumBridgeStatus({required this.kind, this.lastError});
  final ReticulumBridgeStatusKind kind;
  final String? lastError;

  static const disconnected = ReticulumBridgeStatus(
    kind: ReticulumBridgeStatusKind.disconnected,
  );

  @override
  String toString() =>
      'ReticulumBridgeStatus($kind${lastError != null ? ', $lastError' : ''})';
}

class ReticulumBridgeCounters {
  const ReticulumBridgeCounters({
    this.forwarded = 0,
    this.droppedNoConnection = 0,
    this.droppedBackpressure = 0,
    this.droppedFramingError = 0,
    this.connectAttempts = 0,
    this.connectErrors = 0,
  });

  static const empty = ReticulumBridgeCounters();

  final int forwarded;
  final int droppedNoConnection;
  final int droppedBackpressure;
  final int droppedFramingError;
  final int connectAttempts;
  final int connectErrors;

  ReticulumBridgeCounters _add({
    int forwarded = 0,
    int droppedNoConnection = 0,
    int droppedBackpressure = 0,
    int droppedFramingError = 0,
    int connectAttempts = 0,
    int connectErrors = 0,
  }) {
    return ReticulumBridgeCounters(
      forwarded: this.forwarded + forwarded,
      droppedNoConnection: this.droppedNoConnection + droppedNoConnection,
      droppedBackpressure: this.droppedBackpressure + droppedBackpressure,
      droppedFramingError: this.droppedFramingError + droppedFramingError,
      connectAttempts: this.connectAttempts + connectAttempts,
      connectErrors: this.connectErrors + connectErrors,
    );
  }
}

/// Minimal socket interface the bridge needs from the underlying
/// transport. The default factory wraps `dart:io` `Socket`. Tests
/// supply fakes that record writes and can simulate remote close /
/// write errors.
abstract class BridgeSocket {
  Future<void> write(List<int> bytes);
  Future<void> close();

  /// Completes when the socket closes for any reason (peer close,
  /// local close, error). Used to drive auto-reconnect.
  Future<void> get done;
}

typedef BridgeSocketFactory =
    Future<BridgeSocket> Function(String host, int port);

/// Production socket factory backed by `dart:io` `Socket.connect`.
/// The provider layer wires this in by default; tests inject fakes.
Future<BridgeSocket> defaultBridgeSocketFactory(String host, int port) async {
  final socket = await Socket.connect(host, port);
  return _RealBridgeSocket(socket);
}

class _RealBridgeSocket implements BridgeSocket {
  _RealBridgeSocket(this._socket) {
    _sub = _socket.listen(
      _ignoreInbound,
      onError: (_) => _markDone(),
      onDone: _markDone,
      cancelOnError: true,
    );
  }

  final Socket _socket;
  final Completer<void> _doneCompleter = Completer<void>();
  StreamSubscription<List<int>>? _sub;

  static void _ignoreInbound(List<int> _) {
    // We are write-only for v1 (forward Reticulum frames into rnsd).
    // Discarding inbound bytes here is intentional. Future bidirectional
    // support would surface this stream to the caller.
  }

  void _markDone() {
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
  }

  @override
  Future<void> write(List<int> bytes) async {
    _socket.add(bytes);
    await _socket.flush();
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket.close();
    } finally {
      _markDone();
    }
  }

  @override
  Future<void> get done => _doneCompleter.future;
}

class ReticulumBridgeService {
  ReticulumBridgeService({
    required BridgeSocketFactory socketFactory,
    Duration backoffStart = kReticulumBridgeBackoffStart,
    Duration backoffCap = kReticulumBridgeBackoffCap,
    int outboundQueueDepth = kReticulumBridgeQueueDepth,
    math.Random? random,
    DateTime Function()? clock,
  }) : _socketFactory = socketFactory,
       _backoffStart = backoffStart,
       _backoffCap = backoffCap,
       _outboundQueueDepth = outboundQueueDepth,
       _random = random ?? math.Random(),
       _clock = clock ?? DateTime.now;

  final BridgeSocketFactory _socketFactory;
  final Duration _backoffStart;
  final Duration _backoffCap;
  final int _outboundQueueDepth;
  final math.Random _random;
  final DateTime Function() _clock;

  final Queue<Uint8List> _queue = Queue<Uint8List>();
  final StreamController<ReticulumBridgeStatus> _statusController =
      StreamController<ReticulumBridgeStatus>.broadcast();

  ReticulumBridgeStatus _status = ReticulumBridgeStatus.disconnected;
  ReticulumBridgeCounters _counters = ReticulumBridgeCounters.empty;
  BridgeSocket? _socket;
  Timer? _retryTimer;
  bool _draining = false;
  bool _disposed = false;
  bool _userDisconnected = false;

  String? _host;
  int? _port;

  int _backoffAttempt = 0;
  Duration? _lastBackoffDelay;

  DateTime? _sessionStart;
  Duration _accumulatedUptime = Duration.zero;

  Stream<ReticulumBridgeStatus> get statusStream => _statusController.stream;
  ReticulumBridgeStatus get status => _status;
  ReticulumBridgeCounters get counters => _counters;
  int get queueDepth => _queue.length;
  int get queueCapacity => _outboundQueueDepth;

  /// Last computed retry delay (with jitter applied). Useful for
  /// tests asserting the backoff schedule.
  Duration? get lastBackoffDelay => _lastBackoffDelay;

  /// Current backoff exponent. Resets to 0 on a successful connect.
  /// Exposed for tests asserting that `connect()` success clears the
  /// previous failure history.
  int get currentBackoffAttempt => _backoffAttempt;

  /// Time spent in `connected` state across the lifetime of this
  /// service, including the current session if connected. Increments
  /// monotonically across reconnects.
  Duration get totalUptime {
    if (_sessionStart == null) return _accumulatedUptime;
    return _accumulatedUptime + _clock().difference(_sessionStart!);
  }

  /// Time the current session has been connected. Zero when not
  /// connected.
  Duration get currentSessionUptime {
    if (_sessionStart == null) return Duration.zero;
    return _clock().difference(_sessionStart!);
  }

  /// Begin connecting to [host]:[port]. Idempotent — if already
  /// connecting / connected, returns without effect. To switch
  /// endpoints, call [disconnect] first.
  Future<void> connect(String host, int port) async {
    if (_disposed) return;
    if (_status.kind == ReticulumBridgeStatusKind.connecting ||
        _status.kind == ReticulumBridgeStatusKind.connected) {
      return;
    }
    _userDisconnected = false;
    _host = host;
    _port = port;
    _backoffAttempt = 0;
    await _attemptConnect();
  }

  /// User-initiated disconnect. Cancels pending retries and tears
  /// down the active socket. After this returns, [status] is
  /// `disconnected` and no auto-reconnect will fire.
  Future<void> disconnect() async {
    _userDisconnected = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _closeSocket();
    _setStatus(
      const ReticulumBridgeStatus(kind: ReticulumBridgeStatusKind.disconnected),
    );
  }

  /// Enqueue [body] to be HDLC-framed and sent to the peer. Returns
  /// `true` if accepted into the queue, `false` if dropped (no
  /// connection or queue full). Drop reasons increment counters.
  bool sendFrame(Uint8List body) {
    if (_disposed) return false;
    if (_status.kind != ReticulumBridgeStatusKind.connected) {
      _counters = _counters._add(droppedNoConnection: 1);
      _emitChange();
      return false;
    }
    // Capacity covers queue + the one frame currently being written
    // (when the drain loop is mid-await). With a stalled peer, this
    // gives the documented "33rd send drops" semantics: 32 fit
    // (1 in flight + 31 queued), the 33rd is rejected.
    final inFlight = _draining ? 1 : 0;
    if (_queue.length + inFlight >= _outboundQueueDepth) {
      // Drop-newest: preserve order of in-flight frames so the peer
      // sees a coherent prefix of the original stream.
      _counters = _counters._add(droppedBackpressure: 1);
      _emitChange();
      return false;
    }
    _queue.add(body);
    _scheduleDrain();
    return true;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _closeSocket();
    await _statusController.close();
  }

  // ── internals ──────────────────────────────────────────────────

  Future<void> _attemptConnect() async {
    if (_disposed || _userDisconnected) return;
    _setStatus(
      const ReticulumBridgeStatus(kind: ReticulumBridgeStatusKind.connecting),
    );
    _counters = _counters._add(connectAttempts: 1);
    try {
      final socket = await _socketFactory(_host!, _port!);
      if (_disposed || _userDisconnected) {
        try {
          await socket.close();
        } catch (_) {}
        return;
      }
      _socket = socket;
      _backoffAttempt = 0;
      _lastBackoffDelay = null;
      _sessionStart = _clock();
      _setStatus(
        const ReticulumBridgeStatus(kind: ReticulumBridgeStatusKind.connected),
      );
      // Auto-reconnect when the socket closes for any reason.
      unawaited(socket.done.then((_) => _onSocketClosed('peer_closed')));
      _scheduleDrain();
    } catch (e) {
      _counters = _counters._add(connectErrors: 1);
      _setStatus(
        ReticulumBridgeStatus(
          kind: ReticulumBridgeStatusKind.error,
          lastError: e.toString(),
        ),
      );
      _scheduleRetry();
    }
  }

  void _onSocketClosed(String reason) {
    if (_disposed) return;
    _socket = null;
    _accumulateUptime();
    if (_userDisconnected) {
      _setStatus(
        const ReticulumBridgeStatus(
          kind: ReticulumBridgeStatusKind.disconnected,
        ),
      );
      return;
    }
    _setStatus(
      ReticulumBridgeStatus(
        kind: ReticulumBridgeStatusKind.error,
        lastError: reason,
      ),
    );
    _scheduleRetry();
  }

  Future<void> _closeSocket() async {
    final s = _socket;
    _socket = null;
    _accumulateUptime();
    if (s != null) {
      try {
        await s.close();
      } catch (_) {}
    }
  }

  void _accumulateUptime() {
    if (_sessionStart != null) {
      _accumulatedUptime += _clock().difference(_sessionStart!);
      _sessionStart = null;
    }
  }

  void _scheduleRetry() {
    if (_disposed || _userDisconnected) return;
    final delay = _nextBackoff();
    _lastBackoffDelay = delay;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _attemptConnect);
  }

  /// Full-jitter exponential backoff:
  /// `delay ∈ [0, min(cap, start * 2^attempt)]`.
  Duration _nextBackoff() {
    // Cap the exponent so 1 << n stays in safe int range and ceiling
    // can never exceed the configured cap.
    final clampedAttempt = _backoffAttempt.clamp(0, 30);
    final ceilingMs = math.min(
      _backoffCap.inMilliseconds,
      _backoffStart.inMilliseconds * (1 << clampedAttempt),
    );
    final ms = _random.nextInt(ceilingMs + 1);
    _backoffAttempt++;
    return Duration(milliseconds: ms);
  }

  void _scheduleDrain() {
    if (_draining || _disposed) return;
    if (_socket == null) return;
    if (_status.kind != ReticulumBridgeStatusKind.connected) return;
    _draining = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    try {
      while (!_disposed &&
          _queue.isNotEmpty &&
          _socket != null &&
          _status.kind == ReticulumBridgeStatusKind.connected) {
        final body = _queue.removeFirst();
        Uint8List wire;
        try {
          wire = ReticulumTcpFraming.encodeFrame(body);
        } catch (e) {
          // Encoder is pure and shouldn't fail on Uint8List input,
          // but if it ever does we mark it as a framing error rather
          // than silently dropping.
          _counters = _counters._add(droppedFramingError: 1);
          _emitChange();
          continue;
        }
        try {
          await _socket!.write(wire);
          _counters = _counters._add(forwarded: 1);
          _emitChange();
        } catch (e) {
          _counters = _counters._add(droppedFramingError: 1);
          _emitChange();
          // Write errors mean the socket is dead; tear down and let
          // auto-reconnect take over.
          await _teardownAfterWriteError(e.toString());
          return;
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _teardownAfterWriteError(String reason) async {
    final s = _socket;
    _socket = null;
    _accumulateUptime();
    if (s != null) {
      try {
        await s.close();
      } catch (_) {}
    }
    if (_userDisconnected || _disposed) {
      _setStatus(
        const ReticulumBridgeStatus(
          kind: ReticulumBridgeStatusKind.disconnected,
        ),
      );
      return;
    }
    _setStatus(
      ReticulumBridgeStatus(
        kind: ReticulumBridgeStatusKind.error,
        lastError: reason,
      ),
    );
    _scheduleRetry();
  }

  void _setStatus(ReticulumBridgeStatus next) {
    if (_disposed) return;
    _status = next;
    _statusController.add(next);
  }

  /// Re-emits the current status so any listener that mirrors live
  /// service state (counters, queue depth, uptime) gets a refresh
  /// without needing to wait for a status transition or a periodic
  /// poll. Called after every counter mutation.
  void _emitChange() {
    if (_disposed) return;
    _statusController.add(_status);
  }
}
