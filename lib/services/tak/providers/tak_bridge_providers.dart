// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../certificate_manager.dart';
import '../geochat_bridge.dart';
import '../identity_registry.dart';
import '../tak_mesh_bridge.dart';
import '../tak_server.dart';

/// Whether the TAK Mesh Bridge feature flag is enabled.
final isTakMeshBridgeEnabledProvider = Provider<bool>((ref) {
  return AppFeatureFlags.isTakMeshBridgeEnabled;
});

/// TAK certificate manager (singleton).
final takCertManagerProvider = Provider<TakCertificateManager>((ref) {
  AppLogging.tak('Creating TakCertificateManager provider');
  final manager = TakCertificateManager();
  return manager;
});

/// TAK identity registry (singleton).
final takIdentityRegistryProvider = Provider<TakIdentityRegistry>((ref) {
  AppLogging.tak('Creating TakIdentityRegistry provider');
  return TakIdentityRegistry();
});

/// TAK server instance.
final takServerProvider = Provider<TakServer>((ref) {
  final certManager = ref.watch(takCertManagerProvider);
  AppLogging.tak('Creating TakServer provider');
  final server = TakServer(certManager);
  ref.onDispose(() {
    AppLogging.tak('Disposing TakServer provider');
    server.dispose();
  });
  return server;
});

/// TAK mesh bridge instance.
final takMeshBridgeProvider = Provider<TakMeshBridge>((ref) {
  final server = ref.watch(takServerProvider);
  AppLogging.tak('Creating TakMeshBridge provider');
  final bridge = TakMeshBridge(
    server: server,
    meshSend: (payload, {required int portnum, int? destination}) async {
      // Placeholder — will be wired to ProtocolService in integration.
      AppLogging.tak(
        'Bridge meshSend: ${payload.length} bytes on portnum $portnum',
      );
    },
  );
  ref.onDispose(() {
    AppLogging.tak('Disposing TakMeshBridge provider');
    bridge.dispose();
  });
  return bridge;
});

/// TAK GeoChat bridge instance.
final takGeoChatBridgeProvider = Provider<GeoChatBridge>((ref) {
  final registry = ref.watch(takIdentityRegistryProvider);
  AppLogging.tak('Creating GeoChatBridge provider');
  return GeoChatBridge(
    meshSend: (text, {int channelIndex = 0, int? destination}) async {
      // Placeholder — will be wired to ProtocolService in integration.
      AppLogging.tak('GeoChat meshSend: "$text" on channel $channelIndex');
      return 0;
    },
    callsignResolver: (callsign) {
      final identity = registry.lookupByCallsign(callsign);
      return identity?.nodeNum;
    },
  );
});

/// Snapshot of bridge operational status.
class TakBridgeStatus {
  final bool isRunning;
  final int connectedClientCount;
  final int packetsInbound;
  final int packetsOutbound;
  final DateTime? lastActivity;

  const TakBridgeStatus({
    this.isRunning = false,
    this.connectedClientCount = 0,
    this.packetsInbound = 0,
    this.packetsOutbound = 0,
    this.lastActivity,
  });
}

/// Bridge status notifier — refreshes on a timer stream.
class TakBridgeStatusNotifier extends Notifier<TakBridgeStatus> {
  Timer? _timer;

  @override
  TakBridgeStatus build() {
    ref.onDispose(() => _timer?.cancel());

    // Poll status every 5 seconds.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());

    return _snapshot();
  }

  /// Force an immediate status refresh (e.g. after start/stop).
  void refresh() => state = _snapshot();

  TakBridgeStatus _snapshot() {
    final bridge = ref.read(takMeshBridgeProvider);
    final server = ref.read(takServerProvider);
    return TakBridgeStatus(
      isRunning: bridge.isRunning,
      connectedClientCount: server.clientCount,
      packetsInbound: bridge.packetsInbound,
      packetsOutbound: bridge.packetsOutbound,
    );
  }
}

final takBridgeStatusProvider =
    NotifierProvider<TakBridgeStatusNotifier, TakBridgeStatus>(
      TakBridgeStatusNotifier.new,
    );
