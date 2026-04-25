// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/nodedex/providers/nodedex_providers.dart';
import '../services/protocol/reticulum/reticulum_capture_writer.dart';
import '../services/protocol/reticulum/reticulum_flags.dart';
import '../services/protocol/reticulum/reticulum_fragment_event.dart';
import '../services/protocol/reticulum/reticulum_nodedex_bridge.dart';
import '../services/protocol/reticulum/reticulum_safe_log.dart';
import '../services/protocol/reticulum/reticulum_stats.dart';
import '../services/protocol/reticulum/reticulum_stats_recorder.dart';
import 'app_providers.dart';

/// SharedPreferences key prefix for Reticulum-tunnel feature flags.
const String _kReticulumPrefsPrefix = 'reticulum.';

const String _kPrefDiagnostics = '${_kReticulumPrefsPrefix}diagnosticsEnabled';
const String _kPrefCapture = '${_kReticulumPrefsPrefix}captureEnabled';
const String _kPrefReassembly = '${_kReticulumPrefsPrefix}reassemblyEnabled';
const String _kPrefBridge = '${_kReticulumPrefsPrefix}bridgeEnabled';

/// Four independently toggleable feature flags for the Reticulum
/// subsystem, persisted to [SharedPreferences].
class ReticulumFlagsNotifier extends Notifier<ReticulumFlags> {
  @override
  ReticulumFlags build() {
    Future.microtask(_loadFromPrefs);
    return ReticulumFlags.empty;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = ReticulumFlags(
        diagnosticsEnabled: prefs.getBool(_kPrefDiagnostics) ?? false,
        captureEnabled: prefs.getBool(_kPrefCapture) ?? false,
        reassemblyEnabled: prefs.getBool(_kPrefReassembly) ?? false,
        bridgeEnabled: prefs.getBool(_kPrefBridge) ?? false,
      );
    } catch (e) {
      ReticulumSafeLog.event('flags_load_error error=$e');
    }
  }

  Future<void> setDiagnosticsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefDiagnostics, value);
    state = state.copyWith(diagnosticsEnabled: value);
  }

  Future<void> setCaptureEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefCapture, value);
    state = state.copyWith(captureEnabled: value);
  }

  Future<void> setReassemblyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefReassembly, value);
    state = state.copyWith(reassemblyEnabled: value);
  }

  Future<void> setBridgeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefBridge, value);
    state = state.copyWith(bridgeEnabled: value);
  }
}

final reticulumFlagsProvider =
    NotifierProvider<ReticulumFlagsNotifier, ReticulumFlags>(
      ReticulumFlagsNotifier.new,
    );

/// Broadcast stream of inbound port-76 fragment events. Wraps the
/// [ProtocolService.reticulumFragmentStream] for downstream consumers.
final reticulumFragmentStreamProvider = StreamProvider<ReticulumFragmentEvent>((
  ref,
) {
  final protocol = ref.watch(protocolServiceProvider);
  return protocol.reticulumFragmentStream;
});

/// Singleton append-only capture writer. Reacts to flag changes by
/// enabling/disabling itself; the writer is responsible for closing
/// any active file when capture is turned off.
final reticulumCaptureWriterProvider = Provider<ReticulumCaptureWriter>((ref) {
  final writer = ReticulumCaptureWriter();
  ref.listen<ReticulumFlags>(reticulumFlagsProvider, (prev, next) {
    if (prev?.captureEnabled != next.captureEnabled) {
      unawaited(writer.setEnabled(next.captureEnabled));
    }
  }, fireImmediately: true);
  ref.onDispose(() {
    unawaited(writer.dispose());
  });
  return writer;
});

/// NodeDex idempotency-guarded bridge: routes fragment-from-source
/// events into NodeDex encounters with a 5-minute dedup window.
final reticulumNodeDexBridgeProvider = Provider<ReticulumNodeDexBridge>((ref) {
  return ReticulumNodeDexBridge(
    recordEncounter: (nodeId, timestamp) {
      try {
        ref
            .read(nodeDexProvider.notifier)
            .recordEncounter(nodeId, timestamp: timestamp);
      } catch (e) {
        ReticulumSafeLog.event('nodedex_bridge_error error=$e');
      }
    },
  );
});

/// Stats notifier — pure state container around [ReticulumStatsRecorder].
///
/// Fragment events are pushed in via [recordFragment] from the dispatch
/// loop in `protocolServiceProvider`, NOT pulled from the stream by the
/// notifier itself. That inversion is deliberate: if the notifier
/// subscribed to `protocolServiceProvider.reticulumFragmentStream`
/// directly, eagerly initializing the notifier from inside
/// `protocolServiceProvider`'s factory would create a circular
/// dependency between the two providers.
class ReticulumStatsNotifier extends Notifier<ReticulumStats> {
  ReticulumStatsRecorder? _recorder;
  StreamSubscription<ReticulumStats>? _statsSub;
  Timer? _refreshTimer;

  @override
  ReticulumStats build() {
    final recorder = ReticulumStatsRecorder();
    _recorder = recorder;
    _statsSub = recorder.stats.listen((snapshot) {
      state = snapshot;
    });
    // Tick once a second so fragments/sec decays toward zero in the UI
    // when traffic stops, without waiting for the next fragment.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => recorder.tick(),
    );
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _statsSub?.cancel();
      _recorder = null;
      unawaited(recorder.dispose());
    });
    return ReticulumStats.empty;
  }

  /// Push a fragment into the recorder. Wired by the dispatch loop in
  /// `protocolServiceProvider`. No-ops after dispose.
  void recordFragment(ReticulumFragmentEvent event) {
    _recorder?.recordFragment(event);
  }
}

final reticulumStatsProvider =
    NotifierProvider<ReticulumStatsNotifier, ReticulumStats>(
      ReticulumStatsNotifier.new,
    );
