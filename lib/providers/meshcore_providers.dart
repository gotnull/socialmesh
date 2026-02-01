// SPDX-License-Identifier: GPL-3.0-or-later
// Providers for MeshCore integration and protocol-agnostic device info.
//
// These providers enable the UI to access protocol-agnostic device
// information without depending on Meshtastic or MeshCore specific code.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/transport.dart';
import '../models/mesh_device.dart';
import '../services/meshcore/connection_coordinator.dart';
import '../services/meshcore/meshcore_adapter.dart';
import '../services/meshcore/meshcore_detector.dart';
import '../services/meshcore/protocol/meshcore_capture.dart';
import '../services/meshcore/protocol/meshcore_session.dart';
import 'app_providers.dart';
import 'connection_providers.dart';

/// Provider for the connection coordinator singleton.
///
/// The coordinator handles protocol detection and routes connections
/// to the appropriate adapter (Meshtastic or MeshCore).
final connectionCoordinatorProvider = Provider<ConnectionCoordinator>((ref) {
  final coordinator = ConnectionCoordinator();

  ref.onDispose(() {
    coordinator.dispose();
  });

  return coordinator;
});

/// Provider for the current protocol-agnostic device info.
///
/// This provides a unified view of the connected device regardless of
/// whether it's Meshtastic or MeshCore. UI components should use this
/// instead of protocol-specific providers.
///
/// Returns null when not connected or not yet identified.
final meshDeviceInfoProvider = Provider<MeshDeviceInfo?>((ref) {
  // Check coordinator first for MeshCore devices
  final coordinator = ref.watch(connectionCoordinatorProvider);
  if (coordinator.deviceInfo != null) {
    return coordinator.deviceInfo;
  }

  // Fall back to Meshtastic protocol service for Meshtastic devices
  final connectionState = ref.watch(deviceConnectionProvider);
  if (!connectionState.isConnected) {
    return null;
  }

  // Get Meshtastic device info from protocol service
  final protocol = ref.watch(protocolServiceProvider);
  final myNodeNum = protocol.myNodeNum;
  if (myNodeNum == null) {
    return null;
  }

  // Get node info from the nodes map
  final myNode = protocol.nodes[myNodeNum];
  final displayName =
      myNode?.longName ?? myNode?.shortName ?? 'Meshtastic Device';
  final firmwareVersion = myNode?.firmwareVersion;
  final hardwareModel = myNode?.hardwareModel;

  // Build MeshDeviceInfo from Meshtastic protocol service
  return MeshDeviceInfo(
    protocolType: MeshProtocolType.meshtastic,
    displayName: displayName,
    nodeId: myNodeNum.toRadixString(16).toUpperCase(),
    firmwareVersion: firmwareVersion,
    hardwareModel: hardwareModel,
  );
});

/// Provider for the detected protocol type of the connected device.
///
/// Returns unknown when not connected.
final meshProtocolTypeProvider = Provider<MeshProtocolType>((ref) {
  final deviceInfo = ref.watch(meshDeviceInfoProvider);
  return deviceInfo?.protocolType ?? MeshProtocolType.unknown;
});

/// Provider for the MeshCore adapter (null if not connected or not MeshCore).
///
/// Use this to access MeshCore-specific functionality like the session.
final meshCoreAdapterProvider = Provider<MeshCoreAdapter?>((ref) {
  final coordinator = ref.watch(connectionCoordinatorProvider);
  return coordinator.meshCoreAdapter;
});

/// Provider for the MeshCore session (null if not connected or not MeshCore).
///
/// Use this for direct protocol operations on MeshCore devices.
final meshCoreSessionProvider = Provider<MeshCoreSession?>((ref) {
  final adapter = ref.watch(meshCoreAdapterProvider);
  return adapter?.session;
});

/// Provider for the MeshCore debug capture (null if not MeshCore or release build).
///
/// Only available in debug builds for dev-only protocol inspection.
final meshCoreCaptureProvider = Provider<MeshCoreFrameCapture?>((ref) {
  if (!kDebugMode) return null;
  final coordinator = ref.watch(connectionCoordinatorProvider);
  return coordinator.meshCoreCapture;
});

/// Provider for protocol detection on a scanned device.
///
/// This is a family provider that takes scan parameters and returns
/// the detection result for a specific device.
final protocolDetectionProvider =
    Provider.family<ProtocolDetectionResult, ProtocolDetectionParams>((
      ref,
      params,
    ) {
      return MeshProtocolDetector.detect(
        device: params.device,
        advertisedServiceUuids: params.advertisedServiceUuids,
        manufacturerData: params.manufacturerData,
      );
    });

/// Parameters for protocol detection.
///
/// Contains information from a BLE scan needed to detect the device protocol.
class ProtocolDetectionParams {
  /// Device identifier and name.
  final DeviceInfo device;

  /// Service UUIDs advertised by the device.
  final List<String> advertisedServiceUuids;

  /// Manufacturer-specific data from the advertisement.
  final Map<int, List<int>>? manufacturerData;

  const ProtocolDetectionParams({
    required this.device,
    this.advertisedServiceUuids = const [],
    this.manufacturerData,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProtocolDetectionParams &&
          runtimeType == other.runtimeType &&
          device.id == other.device.id;

  @override
  int get hashCode => device.id.hashCode;
}

/// Notifier for ping test state.
///
/// Tracks the state of ping tests for the debug action in the device sheet.
class PingTestNotifier extends Notifier<PingTestState> {
  @override
  PingTestState build() => const PingTestState.idle();

  Future<void> ping() async {
    state = const PingTestState.inProgress();

    try {
      final coordinator = ref.read(connectionCoordinatorProvider);
      final latency = await coordinator.ping();

      if (latency != null) {
        state = PingTestState.success(latency);
      } else {
        // For Meshtastic without explicit ping, check if connected
        final connectionState = ref.read(deviceConnectionProvider);
        if (connectionState.isConnected) {
          // Meshtastic doesn't have explicit ping, but connection proves comms
          state = const PingTestState.success(Duration(milliseconds: 50));
        } else {
          state = const PingTestState.failure('Not connected');
        }
      }
    } catch (e) {
      state = PingTestState.failure(e.toString());
    }
  }

  void reset() {
    state = const PingTestState.idle();
  }
}

/// State of a ping test.
class PingTestState {
  /// The current status.
  final PingTestStatus status;

  /// Latency on success.
  final Duration? latency;

  /// Error message on failure.
  final String? errorMessage;

  const PingTestState.idle()
    : status = PingTestStatus.idle,
      latency = null,
      errorMessage = null;

  const PingTestState.inProgress()
    : status = PingTestStatus.inProgress,
      latency = null,
      errorMessage = null;

  const PingTestState.success(this.latency)
    : status = PingTestStatus.success,
      errorMessage = null;

  const PingTestState.failure(this.errorMessage)
    : status = PingTestStatus.failure,
      latency = null;

  /// Whether the test is idle.
  bool get isIdle => status == PingTestStatus.idle;

  /// Whether the test is in progress.
  bool get isInProgress => status == PingTestStatus.inProgress;

  /// Whether the test succeeded.
  bool get isSuccess => status == PingTestStatus.success;

  /// Whether the test failed.
  bool get isFailure => status == PingTestStatus.failure;
}

enum PingTestStatus { idle, inProgress, success, failure }

final pingTestProvider = NotifierProvider<PingTestNotifier, PingTestState>(
  PingTestNotifier.new,
);

/// State of a GATT dump operation.
class GattDumpState {
  /// The current status.
  final GattDumpStatus status;

  /// Discovered services on success.
  final List<GattServiceInfo>? services;

  /// Error message on failure.
  final String? errorMessage;

  const GattDumpState.idle()
    : status = GattDumpStatus.idle,
      services = null,
      errorMessage = null;

  const GattDumpState.inProgress()
    : status = GattDumpStatus.inProgress,
      services = null,
      errorMessage = null;

  const GattDumpState.success(this.services)
    : status = GattDumpStatus.success,
      errorMessage = null;

  const GattDumpState.failure(this.errorMessage)
    : status = GattDumpStatus.failure,
      services = null;

  bool get isIdle => status == GattDumpStatus.idle;
  bool get isInProgress => status == GattDumpStatus.inProgress;
  bool get isSuccess => status == GattDumpStatus.success;
  bool get isFailure => status == GattDumpStatus.failure;
}

enum GattDumpStatus { idle, inProgress, success, failure }

/// Info about a discovered GATT service.
class GattServiceInfo {
  final String uuid;
  final List<GattCharacteristicInfo> characteristics;

  const GattServiceInfo({required this.uuid, required this.characteristics});
}

/// Info about a discovered GATT characteristic.
class GattCharacteristicInfo {
  final String uuid;
  final List<String> properties;

  const GattCharacteristicInfo({required this.uuid, required this.properties});
}

final gattDumpProvider = NotifierProvider<GattDumpNotifier, GattDumpState>(
  GattDumpNotifier.new,
);

/// Notifier for GATT dump state.
///
/// Dumps all discovered GATT services and characteristics for debugging.
class GattDumpNotifier extends Notifier<GattDumpState> {
  @override
  GattDumpState build() => const GattDumpState.idle();

  Future<void> dump() async {
    state = const GattDumpState.inProgress();

    try {
      final coordinator = ref.read(connectionCoordinatorProvider);
      final services = await coordinator.discoverGattServices();

      if (services != null) {
        state = GattDumpState.success(services);
      } else {
        state = const GattDumpState.failure('GATT discovery not available');
      }
    } catch (e) {
      state = GattDumpState.failure(e.toString());
    }
  }

  void reset() {
    state = const GattDumpState.idle();
  }
}

// ---------------------------------------------------------------------------
// MeshCore Capture State (Dev-only)
// ---------------------------------------------------------------------------

/// Snapshot of MeshCore capture state for UI display.
///
/// Contains a copy of captured frames at a point in time.
class MeshCoreCaptureSnapshot {
  /// List of captured frames.
  final List<CapturedFrame> frames;

  /// Total frame count (may differ from frames.length if truncated).
  final int totalCount;

  /// Whether capture is active.
  final bool isActive;

  const MeshCoreCaptureSnapshot({
    required this.frames,
    required this.totalCount,
    required this.isActive,
  });

  /// Empty snapshot.
  const MeshCoreCaptureSnapshot.empty()
    : frames = const [],
      totalCount = 0,
      isActive = false;

  /// Whether there are any frames.
  bool get hasFrames => frames.isNotEmpty;
}

/// Notifier for MeshCore capture snapshot.
///
/// Provides a way for UI to observe capture changes without heavy rebuilds.
/// Call refresh() to poll the latest snapshot from the capture instance.
class MeshCoreCaptureNotifier extends Notifier<MeshCoreCaptureSnapshot> {
  @override
  MeshCoreCaptureSnapshot build() {
    // Initial state: check if we have an active capture
    final capture = ref.read(meshCoreCaptureProvider);
    if (capture == null) {
      return const MeshCoreCaptureSnapshot.empty();
    }
    return _snapshotFromCapture(capture);
  }

  /// Refresh the snapshot from the current capture.
  void refresh() {
    final capture = ref.read(meshCoreCaptureProvider);
    if (capture == null) {
      state = const MeshCoreCaptureSnapshot.empty();
      return;
    }
    state = _snapshotFromCapture(capture);
  }

  /// Clear the capture and refresh state.
  void clear() {
    final capture = ref.read(meshCoreCaptureProvider);
    capture?.clear();
    refresh();
  }

  /// Get the compact hex log for clipboard.
  String getHexLog() {
    final capture = ref.read(meshCoreCaptureProvider);
    return capture?.toCompactHexLog() ?? '(no capture active)';
  }

  MeshCoreCaptureSnapshot _snapshotFromCapture(MeshCoreFrameCapture capture) {
    final frames = capture.snapshot();
    return MeshCoreCaptureSnapshot(
      frames: frames,
      totalCount: frames.length,
      isActive: capture.isActive,
    );
  }
}

final meshCoreCaptureSnapshotProvider =
    NotifierProvider<MeshCoreCaptureNotifier, MeshCoreCaptureSnapshot>(
      MeshCoreCaptureNotifier.new,
    );
