// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Protocol-neutral readiness facade. Public watch_companion files MUST NOT
// import this file directly outside the snapshot composer; the directory
// path enforces the protocol-isolation invariant. See the package's
// protocol-isolation test for the build-time tripwire.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/providers/app_providers.dart'
    show
        ActiveProtocol,
        activeProtocolProvider,
        connectedDeviceProvider,
        linkStatusProvider,
        meshtasticReadinessProvider;
import 'package:socialmesh/providers/meshcore_providers.dart'
    show meshCoreConnectionStateProvider;
import 'package:socialmesh/services/protocol/protocol_service.dart'
    show OperationalReadiness;
import 'package:socialmesh/models/mesh_device.dart' show MeshConnectionState;

import '../models/watch_companion_connection_state.dart';

/// Collapses both protocols' readiness signals into one
/// [WatchCompanionConnectionState] for the Watch surface.
///
/// Meshtastic path: `activeProtocolProvider == meshtastic` -> consume
/// `meshtasticReadinessProvider` (StreamProvider of OperationalReadiness)
/// and overlay link status + device info.
///
/// MeshCore path: `activeProtocolProvider == meshcore` -> consume
/// `meshCoreConnectionStateProvider` (StreamProvider of
/// MeshConnectionState) and overlay link status + device info. MeshCore
/// has no equivalent of OperationalReadiness today, so "connected" is
/// the highest readiness we can report.
///
/// None: protocol is unselected -> disconnected, no display name.
///
/// Errors and loading collapse to a degraded / connecting state so the
/// Watch always renders something safe.
final watchReadinessFacadeProvider = Provider<WatchCompanionConnectionState>((
  ref,
) {
  final activeProtocol = ref.watch(activeProtocolProvider);
  final link = ref.watch(linkStatusProvider);
  final device = ref.watch(connectedDeviceProvider);
  final deviceName = device?.name ?? link.deviceName;

  switch (activeProtocol) {
    case ActiveProtocol.none:
      return const WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.disconnected,
      );

    case ActiveProtocol.meshtastic:
      const displayName = 'Meshtastic';
      final readiness = ref.watch(meshtasticReadinessProvider);
      return readiness.when(
        data: (r) => _mapMeshtasticReadiness(r, deviceName, displayName),
        loading: () => WatchCompanionConnectionState(
          status: WatchCompanionConnectionStatus.connecting,
          activeProtocolDisplayName: displayName,
          activeDeviceName: deviceName,
          readinessReason: 'readiness_loading',
        ),
        error: (e, _) => WatchCompanionConnectionState(
          status: WatchCompanionConnectionStatus.degraded,
          activeProtocolDisplayName: displayName,
          activeDeviceName: deviceName,
          readinessReason: 'readiness_error',
        ),
      );

    case ActiveProtocol.meshcore:
      const displayName = 'MeshCore';
      final state = ref.watch(meshCoreConnectionStateProvider);
      return state.when(
        data: (s) => _mapMeshCoreState(s, deviceName, displayName),
        loading: () => WatchCompanionConnectionState(
          status: WatchCompanionConnectionStatus.connecting,
          activeProtocolDisplayName: displayName,
          activeDeviceName: deviceName,
          readinessReason: 'readiness_loading',
        ),
        error: (e, _) => WatchCompanionConnectionState(
          status: WatchCompanionConnectionStatus.degraded,
          activeProtocolDisplayName: displayName,
          activeDeviceName: deviceName,
          readinessReason: 'readiness_error',
        ),
      );
  }
});

WatchCompanionConnectionState _mapMeshtasticReadiness(
  OperationalReadiness readiness,
  String? deviceName,
  String displayName,
) {
  switch (readiness) {
    case OperationalReadiness.idle:
      return WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.disconnected,
        activeProtocolDisplayName: displayName,
        activeDeviceName: deviceName,
      );
    case OperationalReadiness.linkConnected:
    case OperationalReadiness.handshakePhase1:
    case OperationalReadiness.handshakePhase2:
      return WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.connecting,
        activeProtocolDisplayName: displayName,
        activeDeviceName: deviceName,
        readinessReason: readiness.name,
      );
    case OperationalReadiness.ready:
      return WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.ready,
        activeProtocolDisplayName: displayName,
        activeDeviceName: deviceName,
      );
    case OperationalReadiness.degraded:
      return WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.degraded,
        activeProtocolDisplayName: displayName,
        activeDeviceName: deviceName,
        readinessReason: 'degraded',
      );
  }
}

WatchCompanionConnectionState _mapMeshCoreState(
  MeshConnectionState state,
  String? deviceName,
  String displayName,
) {
  switch (state) {
    case MeshConnectionState.disconnected:
    case MeshConnectionState.disconnecting:
      return WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.disconnected,
        activeProtocolDisplayName: displayName,
        activeDeviceName: deviceName,
      );
    case MeshConnectionState.scanning:
    case MeshConnectionState.connecting:
    case MeshConnectionState.identifying:
      return WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.connecting,
        activeProtocolDisplayName: displayName,
        activeDeviceName: deviceName,
        readinessReason: state.name,
      );
    case MeshConnectionState.connected:
      return WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.ready,
        activeProtocolDisplayName: displayName,
        activeDeviceName: deviceName,
      );
    case MeshConnectionState.error:
      return WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.degraded,
        activeProtocolDisplayName: displayName,
        activeDeviceName: deviceName,
        readinessReason: 'error',
      );
  }
}
