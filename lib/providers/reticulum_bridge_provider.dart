// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Riverpod 3.x AsyncNotifier wiring for the Reticulum TCP bridge.
//
// Owns:
//   - SharedPreferences-persisted host + port
//   - One ReticulumBridgeService instance
//   - Subscriptions to: bridge status, fragment->frame stream, flag changes
//
// Connect rule: the service connects only when BOTH
//   reticulumBridgeEnabled == true AND reticulumReassemblyEnabled == true
// Without reassembly there is nothing to forward, and we don't want to
// open a socket that would just sit idle.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/protocol/reticulum/reticulum_flags.dart';
import '../services/protocol/reticulum/reticulum_frame.dart';
import '../services/protocol/reticulum/reticulum_safe_log.dart';
import '../services/reticulum/reticulum_bridge_service.dart';
import 'reticulum_providers.dart';

/// Stream of reassembled frames the bridge subscribes to. Wraps
/// `reticulumReassemblerProvider.frames` so tests can override the
/// frame source without faking the full reassembler. Functionally
/// equivalent to `reticulumFrameStreamProvider`, exposed as a raw
/// `Stream<ReticulumFrame>` instead of `AsyncValue` so the bridge
/// can `.listen()` directly.
final reticulumBridgeFrameSourceProvider = Provider<Stream<ReticulumFrame>>((
  ref,
) {
  return ref.watch(reticulumReassemblerProvider).frames;
});

const String _kPrefBridgeHost = 'reticulum.bridgeHost';
const String _kPrefBridgePort = 'reticulum.bridgePort';

const String kReticulumBridgeDefaultHost = '127.0.0.1';
const int kReticulumBridgeDefaultPort = 4242;

/// Read-only snapshot the UI consumes. Mirrors the underlying
/// [ReticulumBridgeService] state plus the persisted host/port and
/// the user-facing enabled flag.
class ReticulumBridgeUiState {
  const ReticulumBridgeUiState({
    required this.host,
    required this.port,
    required this.enabled,
    required this.status,
    required this.counters,
    required this.totalUptime,
    required this.currentSessionUptime,
    required this.queueDepth,
    required this.queueCapacity,
  });

  final String host;
  final int port;
  final bool enabled;
  final ReticulumBridgeStatus status;
  final ReticulumBridgeCounters counters;
  final Duration totalUptime;
  final Duration currentSessionUptime;
  final int queueDepth;
  final int queueCapacity;

  ReticulumBridgeUiState copyWith({
    String? host,
    int? port,
    bool? enabled,
    ReticulumBridgeStatus? status,
    ReticulumBridgeCounters? counters,
    Duration? totalUptime,
    Duration? currentSessionUptime,
    int? queueDepth,
    int? queueCapacity,
  }) {
    return ReticulumBridgeUiState(
      host: host ?? this.host,
      port: port ?? this.port,
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      counters: counters ?? this.counters,
      totalUptime: totalUptime ?? this.totalUptime,
      currentSessionUptime: currentSessionUptime ?? this.currentSessionUptime,
      queueDepth: queueDepth ?? this.queueDepth,
      queueCapacity: queueCapacity ?? this.queueCapacity,
    );
  }
}

/// Socket factory the provider uses to open new connections. Defaults
/// to the real `Socket.connect`-based factory; tests override this
/// with a fake.
final reticulumBridgeSocketFactoryProvider = Provider<BridgeSocketFactory>((
  ref,
) {
  return defaultBridgeSocketFactory;
});

class ReticulumBridgeNotifier extends AsyncNotifier<ReticulumBridgeUiState> {
  ReticulumBridgeService? _service;
  StreamSubscription<ReticulumBridgeStatus>? _statusSub;
  StreamSubscription<ReticulumFrame>? _frameSub;
  Timer? _refreshTimer;

  @override
  Future<ReticulumBridgeUiState> build() async {
    final factory = ref.read(reticulumBridgeSocketFactoryProvider);
    final svc = ReticulumBridgeService(socketFactory: factory);
    _service = svc;

    _statusSub = svc.statusStream.listen(_onStatus);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshFromService(),
    );

    // React to flag changes — but defer the first reaction until after
    // build() has produced the initial state, so _emit has somewhere
    // to write into.
    ref.listen<ReticulumFlags>(reticulumFlagsProvider, (_, next) {
      _onFlagsChanged(next);
    });

    ref.onDispose(() async {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      await _statusSub?.cancel();
      _statusSub = null;
      await _frameSub?.cancel();
      _frameSub = null;
      await svc.dispose();
      _service = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final host =
        prefs.getString(_kPrefBridgeHost) ?? kReticulumBridgeDefaultHost;
    final port = prefs.getInt(_kPrefBridgePort) ?? kReticulumBridgeDefaultPort;
    final flags = ref.read(reticulumFlagsProvider);

    final initial = ReticulumBridgeUiState(
      host: host,
      port: port,
      enabled: flags.bridgeEnabled,
      status: svc.status,
      counters: svc.counters,
      totalUptime: svc.totalUptime,
      currentSessionUptime: svc.currentSessionUptime,
      queueDepth: svc.queueDepth,
      queueCapacity: svc.queueCapacity,
    );

    // Reconcile gate now that initial state exists. Important when
    // the user had bridgeEnabled persisted = true from a previous run.
    scheduleMicrotask(() => _onFlagsChanged(flags));

    return initial;
  }

  Future<void> setHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefBridgeHost, host);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(host: host));
    // Endpoint changed — if currently connected/connecting, drop and
    // let the next gate reconciliation reopen against the new host.
    await _restartIfRunning();
  }

  Future<void> setPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefBridgePort, port);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(port: port));
    await _restartIfRunning();
  }

  // ── internals ──────────────────────────────────────────────────

  void _onStatus(ReticulumBridgeStatus status) {
    final svc = _service;
    final current = state.value;
    if (svc == null || current == null) return;
    state = AsyncData(
      current.copyWith(
        status: status,
        counters: svc.counters,
        totalUptime: svc.totalUptime,
        currentSessionUptime: svc.currentSessionUptime,
        queueDepth: svc.queueDepth,
      ),
    );
  }

  void _refreshFromService() {
    final svc = _service;
    final current = state.value;
    if (svc == null || current == null) return;
    state = AsyncData(
      current.copyWith(
        counters: svc.counters,
        totalUptime: svc.totalUptime,
        currentSessionUptime: svc.currentSessionUptime,
        queueDepth: svc.queueDepth,
      ),
    );
  }

  void _onFlagsChanged(ReticulumFlags flags) {
    final svc = _service;
    if (svc == null) return;

    final shouldRun = flags.bridgeEnabled && flags.reassemblyEnabled;

    final current = state.value;
    if (current != null && current.enabled != flags.bridgeEnabled) {
      state = AsyncData(current.copyWith(enabled: flags.bridgeEnabled));
    }

    if (shouldRun) {
      _frameSub ??= ref
          .read(reticulumBridgeFrameSourceProvider)
          .listen(
            _onFrame,
            onError: (Object e, StackTrace _) {
              ReticulumSafeLog.event('bridge_frame_stream_error error=$e');
            },
          );
      _ensureConnected();
    } else {
      unawaited(_frameSub?.cancel());
      _frameSub = null;
      _ensureDisconnected();
    }
  }

  void _onFrame(ReticulumFrame frame) {
    _service?.sendFrame(frame.body);
  }

  Future<void> _ensureConnected() async {
    final svc = _service;
    final current = state.value;
    if (svc == null || current == null) return;
    if (svc.status.kind == ReticulumBridgeStatusKind.connected ||
        svc.status.kind == ReticulumBridgeStatusKind.connecting) {
      return;
    }
    try {
      await svc.connect(current.host, current.port);
    } catch (e) {
      // The service captures connect errors internally and surfaces
      // them via statusStream. Anything that escapes here should not
      // crash the provider — log + swallow.
      ReticulumSafeLog.event('bridge_connect_unhandled error=$e');
    }
  }

  Future<void> _ensureDisconnected() async {
    final svc = _service;
    if (svc == null) return;
    if (svc.status.kind == ReticulumBridgeStatusKind.disconnected) return;
    try {
      await svc.disconnect();
    } catch (e) {
      ReticulumSafeLog.event('bridge_disconnect_unhandled error=$e');
    }
  }

  Future<void> _restartIfRunning() async {
    final svc = _service;
    if (svc == null) return;
    final flags = ref.read(reticulumFlagsProvider);
    if (!(flags.bridgeEnabled && flags.reassemblyEnabled)) return;
    await _ensureDisconnected();
    await _ensureConnected();
  }
}

final reticulumBridgeProvider =
    AsyncNotifierProvider<ReticulumBridgeNotifier, ReticulumBridgeUiState>(
      ReticulumBridgeNotifier.new,
    );
